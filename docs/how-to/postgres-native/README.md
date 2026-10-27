---
icon: "server"
description: "CQL ships its own PostgreSQL wire-protocol driver; these guides use it for pooling, streaming, pipelining, COPY, TLS and connection poolers."
---

# Native PostgreSQL Driver

<table data-view="cards"><thead><tr><th></th><th></th><th data-hidden data-card-target data-type="content-ref"></th></tr></thead><tbody>
<tr><td><strong>AsyncEngine and pool options</strong></td><td>Connect, size the pool, run queries and transactions.</td><td><a href="async-engine.md">async-engine.md</a></td></tr>
<tr><td><strong>A Schema on the engine's pool</strong></td><td>Run models, migrations and <code>schema.transaction</code> on the engine's pool.</td><td><a href="schema-on-engine.md">schema-on-engine.md</a></td></tr>
<tr><td><strong>Streaming and pipelining</strong></td><td>Read large results in batches, send many statements in one round trip.</td><td><a href="streaming-and-pipelining.md">streaming-and-pipelining.md</a></td></tr>
<tr><td><strong>COPY and binary parameters</strong></td><td>Bulk load and export, send parameters in binary.</td><td><a href="copy-and-binary-params.md">copy-and-binary-params.md</a></td></tr>
<tr><td><strong>TLS, poolers and timeouts</strong></td><td>Secure connections, PgBouncer and friends, cancel, <code>LISTEN</code>/<code>NOTIFY</code>, isolation levels.</td><td><a href="tls-and-poolers.md">tls-and-poolers.md</a></td></tr>
</tbody></table>

## Pick an Entry Point

```crystal
require "cql" # registers the driver with crystal-db for postgres:// and postgresql:// URLs

DATABASE_URL = "postgres://app:secret@db.internal/app?sslmode=verify-full"

# CQL::Schema, models and migrations: crystal-db's pool, connections from the native driver
AppDB = CQL::Schema.define(:app, DATABASE_URL, CQL::Adapter::Postgres) do
  table :users do
    primary :id, Int64, auto_increment: true
    text :name
  end
end

# The same on the AsyncEngine's pool: pool_size, max_queries and friends come from the URL
EngineDB = CQL::Schema.define(:engine_app, DATABASE_URL, CQL::Adapter::Postgres,
  source: CQL::Postgres::EngineSource.connect(DATABASE_URL)) { }

# Your own pool, streaming, pipelining, per-transaction options
engine = CQL::Postgres::AsyncEngine.connect(DATABASE_URL)

# Plain crystal-db: nothing extra
DB.open(DATABASE_URL) { |db| db.scalar("SELECT 1") } # => 1
```

The driver speaks protocol 3.2 with fallback to 3.0, TLS, Unix sockets, SCRAM-SHA-256, MD5 and cleartext passwords, prepared-statement caching, `COPY`, `LISTEN`/`NOTIFY`, cancellation and statement timeouts. Versions, poolers and benchmarks it was run against are in the README's [measured compatibility](https://github.com/azutoolkit/cql#measured-compatibility).

## Switch from the `pg` Shard

```crystal
# ❌ the pg shard serves postgres:// URLs if it is required anywhere, before or after cql
require "pg"
require "cql"

# ✅ the native driver serves them
require "cql"

DB.open(DATABASE_URL) { |db| db.using_connection(&.class) } # => CQL::Postgres::Connection
```

```bash
crystal build -Dcql_no_postgres_driver src/app.cr          # keep the native driver out of crystal-db's registry
crystal build -Dcql_postgres_driver_cockroachdb src/app.cr # also serve DB.open("cockroachdb://...")
```

`CQL::Postgres::Driver.register_cockroachdb` opts in to `cockroachdb://` at runtime. What changes for URLs and values:

```crystal
"postgres://app:secret@db/app?sslmode=verify-ca"  # ArgumentError: use disable, prefer, require or verify-full
"postgres://app:secret@db/app?sslcert=client.pem" # ArgumentError: the sslcert option is not supported (sslkey too)
"postgres://app:secret@db/app?auth_methods=md5"   # ignored: SCRAM and MD5 are negotiated
"postgres:///app"                                 # host, port, user and password from PGHOST, PGPORT, PGUSER, PGPASSWORD
                                                  # (CQL::Schema needs PGHOST or ?host= for it)
"postgres://app:p%2Bss@db/app"                    # a literal + in the user or password is %2B for DB.open and CQL::Schema
"postgres://app:p%40ss@db/app"                    # '@', '/', '?' and '#' in a password are %40, %2F, %3F, %23 (DB.open refuses a bare '@')

DB.open(DATABASE_URL) do |db|
  db.query_one("SELECT 1.50::numeric", as: CQL::Postgres::Types::DecimalText).to_s # => "1.50", exact
  db.query_one("SELECT ARRAY[1, 2]", as: String)                                     # => "{1,2}", arrays arrive as text
  db.query_one("SELECT 1.50::numeric", as: Float64) # raises DB::ColumnTypeMismatchError
end
# CQL::Postgres::Types.register(oid) { |bytes| ... } decodes another type.
```

## Troubleshooting

**`DB.open` returns a `PG::Connection`**: something requires `pg`; remove it.

**`ArgumentError: unsupported sslmode`**: use `disable`, `prefer`, `require` or `verify-full`.

## See Also

- [Configure Database Connection](../configuration/database-connection.md)
- [Enable SSL Connections](../configuration/ssl.md)
- [Use CockroachDB](../configuration/cockroachdb.md)
- [Database Support](../../reference/database-support.md)
