# Use CockroachDB

CQL talks to CockroachDB through its PostgreSQL wire driver. This guide shows how to connect, when you need to opt in,
and what behaves differently from PostgreSQL.

CockroachDB support was verified against CockroachDB v24.3.5 (single node, insecure and secure with
`sslmode=verify-full` and a password).

## Connect with `CQL.configure`

`CQL.configure` is the entrypoint. A `cockroachdb://` URL selects `CQL::Adapter::CockroachDB`; `config.adapter` reports it:

```crystal
require "cql"

CQL.configure do |config|
  config.db = "cockroachdb://app:secret@crdb.internal:26257/app?sslmode=verify-full&max_protocol_version=3.0"
end

CQL.config.adapter   # => CQL::Adapter::CockroachDB

MyDB = CQL.build_schema(:my_db) do
end
```

`CQL.build_schema` opens the schema through `config.full_db_url`, so pool, SSL (`ssl.mode`, `ssl.ca_path` as `sslrootcert`) and `adapter_options` settings apply, and parameters already in the URL win. CockroachDB uses the PostgreSQL settings object (`config.postgres`). See [Configure Database Connection](database-connection.md), [Set Up Connection Pooling](connection-pooling.md) and [Enable SSL Connections](ssl.md).

Two things to watch with the defaults:

- `full_db_url` adds `sslmode` from `config.ssl.mode` (`prefer`, or `require` in production), which only matters when the URL has no `sslmode`.
- `config.postgres.auth_methods` is added as `auth_methods`; the native driver accepts and ignores it.

No registration is required for `Schema` or `CQL.build_schema`: `CQL::Adapter::CockroachDB` rewrites the scheme to `postgres://` before handing it to crystal-db, so the connection follows the same rules as a PostgreSQL schema. The URL needs a host. Without a `sslmode`, the driver default is `prefer`.

## Low-Level: `Schema.define`

`CQL::Schema.define` ignores `CQL.config` and uses the URI as given:

```crystal
MyDB = CQL::Schema.define(
  :my_db,
  adapter: CQL::Adapter::CockroachDB,
  uri: "cockroachdb://app:secret@crdb.internal:26257/app?sslmode=verify-full"
) do
end

MyDB.init
```

## Connect with AsyncEngine

`AsyncEngine.connect` picks the CockroachDB adapter from a `cockroachdb://` URL and needs no registration:

```crystal
require "cql/postgres"

engine = CQL::Postgres::AsyncEngine.connect("cockroachdb://app:secret@crdb.internal:26257/app?pool_size=10")
User.query.where(active: true).using(engine).to_a
```

See [AsyncEngine and pool options](../postgres-native/async-engine.md) for the pool settings.

## Open `cockroachdb://` with DB.open

Registration for plain crystal-db (`DB.open`) is opt-in, because only CockroachDB 24.3 was checked. Do it in code:

```crystal
CQL::Postgres::Driver.register_cockroachdb

DB.open("cockroachdb://app:secret@crdb.internal:26257/app") do |db|
  puts db.scalar("SELECT 1")
end
```

Or compile with the flag:

```bash
crystal build -Dcql_postgres_driver_cockroachdb src/app.cr
```

`-Dcql_no_postgres_driver` wins over `-Dcql_postgres_driver_cockroachdb`: with both, nothing is registered
automatically and you call the `register` methods yourself.

## Protocol Version

CockroachDB answers a protocol 3.2 startup with HTTP/2 bytes instead of an error. For that reason:

- `cockroachdb://` URLs given to `DB.open` or `AsyncEngine.connect` start at protocol 3.0 (the URL defaults
  `max_protocol_version` to `3.0`).
- A schema on `CQL::Adapter::CockroachDB` (`CQL.build_schema` or `Schema.define`) uses a `postgres://` URL, so it starts at 3.2 and pays one failed attempt
  per new connection. Avoid that by pinning the version:

```crystal
uri: "cockroachdb://app:secret@crdb.internal:26257/app?max_protocol_version=3.0"
```

The driver also falls back to 3.0 whenever the first reply is not a protocol message.

## Dialect Differences

`Expression::CockroachDialect` inherits everything from `Expression::PostgresDialect`: `$n` placeholders, `RETURNING`,
`ON CONFLICT`, `DISTINCT ON`, `ILIKE`, row locking, CTEs and window functions all render as on PostgreSQL. Two things
differ:

| Area | CockroachDB behavior |
| --- | --- |
| Column types | `Int32` columns are declared `INT4` (CockroachDB's `INTEGER` is 64-bit), and `UInt32` is `BIGINT`, so values read back as the Crystal type you declared. |
| Structure dump | Unsupported. `structure_dump` raises `CQL::DialectError` with the workaround `SHOW CREATE ALL TABLES`. |

See the [database support matrix](../../reference/database-support.md) for the full comparison.

## Differences You May Notice at Runtime

From the driver's live specs against CockroachDB 24.3:

- `SELECT 1` returns an `int8`, and `pg_sleep` returns a bool.
- The default isolation level is serializable. Expect to retry `CQL::Postgres::SerializationFailure` (SQLSTATE
  `40001`), which maps as on PostgreSQL.
- `deferrable: true` on `engine.transaction` raises `ArgumentError`.
- There is no `LISTEN`/`NOTIFY`.
- `COPY` mistakes come back as a generic `ServerError`.
- Binary parameters: float4 and numeric stay text, and multi-dimensional arrays are not available.
- Binary `COPY TO` answers `0A000 unimplemented`; binary `COPY FROM` works.
- Savepoints, `SET LOCAL synchronous_commit`, pipelining, text `COPY`, streaming and cancel work as on PostgreSQL.

## Troubleshooting

**`CQL::Schema::InvalidURIError: Missing host in CockroachDB URI`**: add the host to the URL.

**`DB.open("cockroachdb://...")` says no driver is registered**: call
`CQL::Postgres::Driver.register_cockroachdb` or compile with `-Dcql_postgres_driver_cockroachdb`.

**Schema connects slowly**: every new connection pays one failed protocol 3.2 attempt. Add `max_protocol_version=3.0`.

**`CQL::DialectError` from a schema dump**: use `SHOW CREATE ALL TABLES` in a SQL shell.

**A `+` in the password**: write it as `%2B`; crystal-db reads `+` as a space.

**TLS errors**: see [TLS, poolers and timeouts](../postgres-native/tls-and-poolers.md#tls) and
[Enable SSL Connections](ssl.md).
