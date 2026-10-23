# Native PostgreSQL Driver

CQL ships its own PostgreSQL wire-protocol driver. These guides show how to use it directly for pooling, streaming,
pipelining, `COPY`, TLS and connection poolers.

Reference material and the measured compatibility results live in the
[Native PostgreSQL Driver section of the README](../../../README.md#native-postgresql-driver).

## What you get

- `require "cql"` registers the driver with crystal-db for `postgres://` and `postgresql://` URLs, so `CQL::Schema`
  and `DB.open` work without the `pg` shard.
- `CQL::Postgres::AsyncEngine` is a `CQL::Executor` with its own fiber-safe connection pool. Point any statement at it
  with `query.using(engine)`.
- Protocol 3.2 with automatic fallback to 3.0, TLS, Unix sockets, prepared-statement caching, `COPY`, `LISTEN`/`NOTIFY`,
  cancellation and statement timeouts.

## Guides

| Guide | Use it to |
| --- | --- |
| [AsyncEngine and pool options](async-engine.md) | Connect, size the pool, run queries and transactions |
| [Streaming and pipelining](streaming-and-pipelining.md) | Read large results in batches, send many statements in one round trip |
| [COPY and binary parameters](copy-and-binary-params.md) | Bulk load and export, send parameters in binary |
| [TLS, poolers and timeouts](tls-and-poolers.md) | Secure connections, PgBouncer and friends, cancel, `LISTEN`/`NOTIFY`, isolation levels |

Related guides: [Configure Database Connection](../configuration/database-connection.md),
[Enable SSL Connections](../configuration/ssl.md), [Use CockroachDB](../configuration/cockroachdb.md).

## Which entry point should I use?

| You want | Use |
| --- | --- |
| `CQL::Schema`, models and migrations on PostgreSQL | `CQL::Adapter::Postgres` with a `postgres://` URI; the native driver serves it |
| Your own pool, streaming, pipelining, per-transaction options | `CQL::Postgres::AsyncEngine.connect(url)` |
| Plain `DB.open("postgres://...")` | Nothing extra; `require "cql"` registers the driver |

## Using the `pg` shard instead

If your app requires `pg` before `cql` (the shard keeps the names) or after it (the shard replaces them), the `pg`
driver serves `postgres://` URLs. Remove `require "pg"` to switch to the native driver. Compile with
`-Dcql_no_postgres_driver` to keep the native driver out of crystal-db's registry entirely.

Differences to know about when switching:

- `sslmode` takes `disable`, `prefer`, `require` or `verify-full`. `verify-ca`, `allow` and the libpq options
  `sslcert`, `sslkey` and `auth_methods` are rejected, not ignored.
- `PGHOST`, `PGPORT`, `PGUSER` and `PGPASSWORD` are read from the environment when the URL omits them.
- Arrays decode to their text form and `numeric` to `CQL::Postgres::Types::DecimalText`, so `read(Float64)` and
  `read(Array(Int32))` raise `TypeCastError`. Register a codec with `CQL::Postgres::Types.register` to decode more.
- A literal `+` in a user name or password must be written `%2B`.

## Troubleshooting

**`pg` shard still serves my URLs**: something required `pg` around `require "cql"`. Remove it, or check the load order.

**`ArgumentError: unsupported sslmode`**: use one of `disable`, `prefer`, `require`, `verify-full`.
