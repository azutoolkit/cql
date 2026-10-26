# Use CockroachDB

Connect CQL to CockroachDB through its PostgreSQL wire driver, and know what behaves differently from PostgreSQL.

Support was verified against CockroachDB v24.3.5 (single node, insecure, and secure with `sslmode=verify-full` and a password).

## Connect with `CQL.configure`

```crystal
require "cql"

CQL.configure do |config|
  config.db = "cockroachdb://app:secret@crdb.internal:26257/app?sslmode=verify-full&max_protocol_version=3.0"
end

CQL.config.adapter # => CQL::Adapter::CockroachDB

AppDB = CQL.build_schema(:app) do
end
```

`CQL.build_schema` opens `config.full_db_url`, so pool, SSL (`ssl.mode`; `ssl.ca_path` as `sslrootcert`) and `adapter_options` apply, and parameters already in the URL win. CockroachDB uses the PostgreSQL settings object, so `auth_methods` is added too; the driver accepts and ignores it. Without `sslmode` in the URL, `ssl.mode` supplies it (`prefer`, or `require` in production).

No driver registration is needed for a schema: `CQL::Adapter::CockroachDB` rewrites the scheme to `postgres://` before crystal-db opens it. The URL needs a host.

## Connect with `Schema.define`

```crystal
# Ignores CQL.config and uses the URI as given
AppDB = CQL::Schema.define(
  :app,
  adapter: CQL::Adapter::CockroachDB,
  uri: "cockroachdb://app:secret@crdb.internal:26257/app?sslmode=verify-full&max_protocol_version=3.0"
) do
end
```

## Connect with `AsyncEngine`

```crystal
# Picks the CockroachDB adapter from the cockroachdb:// scheme; no registration needed
engine = CQL::Postgres::AsyncEngine.connect("cockroachdb://app:secret@crdb.internal:26257/app?pool_size=10")
engine.adapter # => CQL::Adapter::CockroachDB
User.query.where(active: true).using(engine).to_a
```

See [AsyncEngine and pool options](../postgres-native/async-engine.md).

## Open `cockroachdb://` with `DB.open`

Plain crystal-db registration is opt-in, because only CockroachDB 24.3 was checked:

```crystal
# ❌ ArgumentError: no driver was registered for the schema "cockroachdb", did you maybe forget to require the database driver?
DB.open("cockroachdb://app:secret@crdb.internal:26257/app")

# ✅ Register in code, or compile with -Dcql_postgres_driver_cockroachdb
CQL::Postgres::Driver.register_cockroachdb

DB.open("cockroachdb://app:secret@crdb.internal:26257/app") do |db|
  puts db.scalar("SELECT 1")
end
```

```bash
crystal build -Dcql_postgres_driver_cockroachdb src/app.cr
# -Dcql_no_postgres_driver wins: with both flags nothing is registered and you call register yourself
```

## Pin the protocol version

CockroachDB answers a protocol 3.2 startup with HTTP/2 bytes instead of an error. The driver then retries at 3.0, so each new connection pays one failed attempt unless the URL pins 3.0:

```crystal
# DB.open and AsyncEngine.connect default cockroachdb:// URLs to max_protocol_version=3.0.
# A schema (CQL.build_schema or Schema.define) opens a postgres:// URL, which starts at 3.2: pin it.
uri = "cockroachdb://app:secret@crdb.internal:26257/app?max_protocol_version=3.0"
```

## Expect these differences

`Expression::CockroachDialect` inherits `Expression::PostgresDialect`: `$n` placeholders, `RETURNING`, `ON CONFLICT`, `DISTINCT ON`, `ILIKE`, row locking, CTEs and window functions render as on PostgreSQL.

```crystal
AppDB = CQL::Schema.define(:app, adapter: CQL::Adapter::CockroachDB, uri: uri) do
  table :counters do
    primary :id, Int64
    integer :hits
    column :big, UInt32
  end
end

AppDB.counters.create_statements
# Int32 is INT4 (CockroachDB's INTEGER is 64-bit), UInt32 is BIGINT:
# CREATE TABLE IF NOT EXISTS counters (id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, hits INT4 NOT NULL, big BIGINT NOT NULL)

AppDB.transaction { AppDB.alter(:counters) { add_column :note, String, null: true } }
# CQL::DialectError: CockroachDB does not support schema changes inside a transaction
# Outside a transaction DDL is not atomic either: a failed migration run keeps the migrations it already applied.

CQL::Adapter::CockroachDB.dialect.structure_dump(URI.parse(uri))
# CQL::DialectError: CockroachDB does not support pg_dump-style structure dumps
# Workaround: Run `SHOW CREATE ALL TABLES` instead.
```

From the driver's live specs against CockroachDB 24.3:

- `SELECT 1` returns an `int8`, and `pg_sleep` returns a bool.
- The default isolation is serializable; retry `CQL::Postgres::SerializationFailure` (SQLSTATE `40001`).
- `deferrable: true` on `engine.transaction` raises `ArgumentError`.
- There is no `LISTEN`/`NOTIFY`, and `COPY` mistakes come back as a generic `ServerError`.
- Binary parameters keep float4 and numeric as text and have no multi-dimensional arrays; binary `COPY TO` answers `0A000 unimplemented`, binary `COPY FROM` works.
- Savepoints, `SET LOCAL synchronous_commit`, pipelining, text `COPY`, streaming and cancel work as on PostgreSQL.

## Troubleshooting

```text
CQL::Schema::InvalidURIError: Missing host in CockroachDB URI    -> add the host to the URL
ArgumentError: no driver was registered for the schema "cockroachdb"  -> register_cockroachdb (DB.open only)
New connections are slow                                          -> add max_protocol_version=3.0
A password with "+" fails to authenticate                         -> write it as %2B; crystal-db reads + as a space
```

For TLS errors see [TLS, poolers and timeouts](../postgres-native/tls-and-poolers.md#tls) and [Enable SSL Connections](ssl.md).

## See Also

- [Database support matrix](../../reference/database-support.md)
- [Configure Database Connection](database-connection.md)
- [Enable SSL Connections](ssl.md)
- [Native PostgreSQL driver](../postgres-native/README.md)
- [AsyncEngine and pool options](../postgres-native/async-engine.md)
