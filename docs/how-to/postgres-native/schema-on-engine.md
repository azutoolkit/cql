---
description: "Give a CQL::Schema a CQL::Postgres::EngineSource so models, queries, migrations, schema.transaction and schema.with_connection use the AsyncEngine's pool without using(engine) on every statement."
---

# Run a Schema on the AsyncEngine's Pool

## Connect the Schema

```crystal
require "cql"

DATABASE_URL = "postgres://app:secret@db.internal/app?sslmode=verify-full&pool_size=10"
SOURCE       = CQL::Postgres::EngineSource.connect(DATABASE_URL) # adapter:, setup:, reset: as in AsyncEngine.connect

AppDB = CQL::Schema.define(:app, DATABASE_URL, CQL::Adapter::Postgres, source: SOURCE) do
  table :users do
    primary :id, Int64, auto_increment: true
    text :name
  end
end

class User
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :users
  property name : String

  def initialize(@name : String)
  end
end

AppDB.users.create!
User.create!(name: "Ada")
User.query.where(name: "Ada").first # runs on the engine's pool
```

`Schema.new` validates the URL but opens no connection while `pool_min_size` is 0, the default; the first statement connects.

## Use Transactions and the Engine

```crystal
CQL::Telemetry.subscribe_transactions("tx") { |event| puts event.state } # engine.transaction publishes none

AppDB.transaction do |tx| # BEGIN ... COMMIT on one engine connection
  User.create!(name: "Grace")
  AppDB.transaction { |inner| User.create!(name: "Linus") } # SAVEPOINT on the same connection, even at pool_size=1
end
# Begin, Begin, Commit, Commit

AppDB.pool_stats.max # => 10 (pool_size); open = in use + idle
SOURCE.engine.pipeline([AppDB.query.from(:users).select(:name)]) # the engine's own API stays reachable

AppDB.close # closes the pool for every schema sharing SOURCE; later statements raise CQL::Postgres::PoolClosed
```

Statements run through `CQL::Execution`, so telemetry and the [performance monitor](../observability/query-profiler.md) see them. `Schema#exec`, `explain`, `engine.exec` and `engine.pipeline` pass `track: false`: telemetry sees them, the monitor does not.

## What Differs from crystal-db's Pool

```crystal
# The engine's names: pool_size, pool_min_size, checkout_timeout, max_queries, max_idle_lifetime
CQL::Postgres::EngineSource.connect("postgres://app:secret@db.internal/app?pool_size=20")

# crystal-db's names, as CQL.config.full_db_url writes them, also work: max_pool_size is read as pool_size and
# initial_pool_size as pool_min_size; when the URL names both, the engine's key wins
CQL::Postgres::EngineSource.connect("postgres://app:secret@db.internal/app?max_pool_size=20&initial_pool_size=1")

# Schema#uri drops the engine's pool options and keeps sslmode, max_protocol_version and binary_params,
# because SchemaDump (migrations with auto_sync) opens its own crystal-db connection from it.
AppDB.uri # => "postgres://app:secret@db.internal/app?sslmode=verify-full"
```

| Failure | crystal-db's pool | `EngineSource` |
| --- | --- | --- |
| Cannot connect | `DB::ConnectionRefused` on the first connect, then `DB::PoolRetryAttemptsExceeded` without `cause` | `DB::ConnectionRefused`, `cause` is the `IO::Error` |
| Pool saturated | `DB::PoolTimeout` | `DB::PoolTimeout`, `cause` is `CQL::Postgres::PoolTimeout` |
| Server or TLS error | `CQL::Postgres::ServerError` subclass, `TLSRefused` | the same |
| Connect retries | `retry_attempts`, `retry_delay` | none |

The engine ignores `max_idle_pool_size`, `retry_attempts`, `retry_delay`, `prepared_statements` and `prepared_statements_cache`. `prepared_statements=false` has no effect on the engine: it still prepares statements and caches them up to `statement_cache_size`; set `statement_cache_size=0` to turn the cache off. Any other key it does not know is still sent to the server as a startup parameter.

{% hint style="warning" %}
`Schema#uri` must name the same server and database as the engine; the schema validates it but does not compare it.
{% endhint %}

The source's adapter must match the schema's (`CQL::Adapter::Postgres` or `CockroachDB`), or `Schema.new` raises `ArgumentError` and leaves the source open.

## See Also

- [Use AsyncEngine and Its Connection Pool](async-engine.md)
- [Use Transactions](../data-operations/transactions.md)
- [Set Up Connection Pooling](../configuration/connection-pooling.md)
- [Dump and Validate Your Schema](../migrations/schema-dump-and-validation.md)
- [Telemetry](../observability/telemetry.md)
