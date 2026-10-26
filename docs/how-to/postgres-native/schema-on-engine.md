# Run a Schema on the AsyncEngine's Pool

By default a `CQL::Schema` borrows connections from crystal-db's pool, even when the native driver serves the URL.
Give it a `CQL::Postgres::EngineSource` and models, queries, migrations, `schema.transaction` and
`schema.with_connection` use the [AsyncEngine's](async-engine.md) own pool instead, without writing `using(engine)` on
every statement.

```crystal
require "cql"

url = "postgres://app:secret@db.internal/app?sslmode=verify-full&pool_size=10"
source = CQL::Postgres::EngineSource.connect(url)

AppDB = CQL::Schema.define(:app, url, CQL::Adapter::Postgres, source: source) do
  table :users do
    primary :id, Int64, auto_increment: true
    text :name
  end
end

User.query.where(name: "ada").first   # engine pool
User.transaction { |tx| ... }          # BEGIN/COMMIT on one engine connection, savepoints when nested
source.engine.pipeline([...])         # the engine's own API stays reachable
AppDB.close                            # closes the pool; waiting fibers get PoolClosed
```

## What stays the same

- `Schema#transaction` still pins the fiber's statements to the transaction's connection and publishes
  `Telemetry` transaction events (`engine.transaction` does not publish them).
- `Schema#pool_stats` reports the engine pool (`open` = in use + idle, `max` = `pool_size`).
- Statements run through `CQL::Execution`, so telemetry and performance tracking see them. `Schema#exec`, `explain`, `engine.exec` and `engine.pipeline` pass `track: false`: telemetry sees them, the [performance monitor](../performance/query-profiler.md) does not.

## What differs from crystal-db's pool

- The URL is the engine's URL: `pool_size`, `pool_min_size`, `checkout_timeout`, `max_queries`, `max_idle_lifetime`
  and the other keys of [AsyncEngine and pool options](async-engine.md#pool-options). crystal-db keys
  (`max_pool_size`, `initial_pool_size`, `retry_attempts`, ...) are not understood by the engine and would be sent to the
  server as startup parameters; write the engine's names.
- A connection that cannot be opened raises `DB::ConnectionRefused` and a saturated pool `DB::PoolTimeout` (both keep the
  engine's error as `cause`). crystal-db raises `DB::ConnectionRefused` only for the first connect and
  `DB::PoolRetryAttemptsExceeded` (cause dropped) for a lazy one, so code rescuing that class will not match. A closed pool raises `CQL::Postgres::PoolClosed`, and server and TLS
  errors stay `CQL::Postgres::ServerError` subclasses and `TLSRefused`. `retry_attempts` and `retry_delay` do not exist:
  the engine does not retry connects.
- A transaction opened inside another one (`schema.transaction` or `Model.transaction`) runs as a SAVEPOINT on the outer
  transaction's engine connection, so nesting takes no extra pool slot and works with `pool_size=1`. `Migrator#up`/`#down`
  still run each migration's statements on a second pooled connection, so a pool of size 1 deadlocks there (see the
  CHANGELOG).
- `Schema#uri` is the URL you passed without the engine's pool options (`pool_size`, `max_queries`, ...; connection settings such as `sslmode` and `max_protocol_version` stay), because `SchemaDump`
  (migrations with `auto_sync`) opens its own connection from it through crystal-db. It must name the same server and
  database as the engine; Schema validates it but does not compare it.
- A source can be shared by schemas: closing it from one schema closes it for all. A schema refused for a mismatched adapter
  leaves the caller's source open.
- The source's adapter must match the schema's (`CQL::Adapter::Postgres` or `CockroachDB`); the schema raises
  `ArgumentError` otherwise.

`Schema.new` still validates the URI and never opens a socket for an `EngineSource` that was created with
`pool_min_size=0` (the default), so the first statement connects.
