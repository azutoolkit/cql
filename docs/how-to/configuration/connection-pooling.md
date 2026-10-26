---
description: "Size the pool each schema opens, watch it, and fix checkouts that time out."
---

# Set Up Connection Pooling

## Configure the pool with `CQL.configure`

```crystal
CQL.configure do |config|
  config.db = ENV["DATABASE_URL"]
  config.pool_size = 25                       # also sets config.pool.size
  config.pool.initial_size = 5
  config.pool.max_idle_size = 10
  config.pool.checkout_timeout = 15.seconds
  config.pool.max_retry_attempts = 5
end

AppDB = CQL.build_schema(:app) do
end

puts CQL.config.full_db_url
# ...?initial_pool_size=5&max_pool_size=25&max_idle_pool_size=10&checkout_timeout=15.0
#    &retry_attempts=5&retry_delay=1.0&prepared_statements=true&...
```

`CQL.build_schema` turns these settings into URL parameters for crystal-db's pool, and parameters already in `config.db` win. The defaults depend on `CRYSTAL_ENV` (see [Configure Multiple Environments](environments.md)).

| `config.pool.*` | URL parameter | Default | Meaning |
|---|---|---|---|
| `size` (`config.pool_size`) | `max_pool_size` | 10 (5 in development, 1 in test, 25 in production) | Most connections open at once |
| `initial_size` | `initial_pool_size` | 1 | Connections opened when the schema is built |
| `max_idle_size` | `max_idle_pool_size` | 1 | Connections kept open while idle |
| `checkout_timeout` | `checkout_timeout` | 10 seconds | Wait for a free connection, then raise `DB::PoolTimeout` |
| `use_prepared_statements?` | `prepared_statements` | `true` | Whether crystal-db prepares statements |

`size`, `initial_size`, `max_idle_size` and `max_retry_attempts` must be positive, or `CQL.configure` raises `ArgumentError` (for example `initial_pool_size must be positive`). Setting `pool_size` lowers `initial_size` and `max_idle_size` to fit it. The retry settings (`max_retry_attempts`, `retry_delay`) and `query_timeout` do not affect CQL's queries; see the [configuration reference](../../reference/configuration.md#pool).

`postgres://` schemas use crystal-db's pool even with CQL's native driver. `CQL::Postgres::AsyncEngine` has its own pool with other URL options: see [Pool Options](../postgres-native/async-engine.md#pool-options).

## Set the pool in a `Schema.define` URI

```crystal
# Schema.define ignores CQL.config; the pool options are query parameters
AppDB = CQL::Schema.define(
  :app,
  adapter: CQL::Adapter::Postgres,
  uri: "postgres://app:secret@db.internal/app?initial_pool_size=5&max_pool_size=25&checkout_timeout=5&retry_attempts=3"
) do
end
```

Parameters you omit take crystal-db's defaults, not CQL's.

## Watch the pool

```crystal
stats = AppDB.pool_stats # CQL::PoolStats, read without checking out a connection
stats.open               # => 2  connections open
stats.idle               # => 2  open and free
stats.in_flight          # => 0  checked out right now
stats.max                # => 5  max_pool_size (0 means unlimited)
```

All counts are zero before the first query when the pool was opened with `initial_pool_size=0`.

## Fix checkout timeouts

```crystal
# ❌ Holds one connection and asks for a second: with max_pool_size=1 this waits
#    checkout_timeout, then raises DB::PoolTimeout: Could not check out a connection in 0.5 seconds
AppDB.with_connection do |connection|
  AppDB.exec_query(&.scalar("SELECT 1"))
end

# ✅ Run the statement on the connection you hold
AppDB.with_connection do |connection|
  connection.scalar("SELECT 1")
end
```

If the pool is simply too small for the traffic, raise `pool_size`, keeping the total across all processes below the server's connection limit.

## See Also

- [Configure CQL](configure-cql.md)
- [Configuration reference](../../reference/configuration.md)
- [Configure Multiple Environments](environments.md)
- [Fix Connection Errors](../troubleshooting/connection-errors.md)
- [Native PostgreSQL driver](../postgres-native/README.md)
