# Set Up Connection Pooling

Configure database connection pooling for better performance and resource management.

## Prerequisites

- CQL installed
- A database URL (see [Configure Database Connection](database-connection.md))

## Configure the Pool with `CQL.configure`

`CQL.configure` is the entrypoint. `config.pool_size` and the `config.pool` object describe the pool, and `CQL.build_schema` turns them into URL parameters for crystal-db's pool:

```crystal
CQL.configure do |config|
  config.db = ENV["DATABASE_URL"]
  config.pool_size = 25
  config.pool.initial_size = 5
  config.pool.max_idle_size = 10
  config.pool.checkout_timeout = 15.seconds
  config.pool.max_retry_attempts = 5
end

MyDB = CQL.build_schema(:my_db) do
end

puts CQL.config.full_db_url   # ...?initial_pool_size=5&max_pool_size=25&...
```

`config.pool_size=` also sets `config.pool.size`, so either spelling works. Parameters already present in `config.db` win over configured ones. The defaults depend on `config.env` (`CRYSTAL_ENV`): see [Configure Multiple Environments](environments.md).

For the lifecycle and the full list of settings see [Configure CQL](configure-cql.md) and the [configuration reference](../../reference/configuration.md).

## Pool Settings

| `config.pool.*` | URL parameter | Default | Meaning |
|-----------------|---------------|---------|---------|
| `size` (also `config.pool_size`) | `max_pool_size` | 10 | Maximum open connections (`0` means unlimited in crystal-db, but CQL rejects a size of 0) |
| `initial_size` | `initial_pool_size` | 1 | Connections opened up front |
| `max_idle_size` | `max_idle_pool_size` | 1 | Connections kept open while idle |
| `checkout_timeout` | `checkout_timeout` | 10 seconds | Time to wait for a free connection (sent as seconds) |
| `max_retry_attempts` | `retry_attempts` | 3 | Times a failed connection attempt is retried |
| `retry_delay` | `retry_delay` | 1 second | Pause between retries (sent as seconds) |
| `use_prepared_statements?` | `prepared_statements` | `true` | Whether crystal-db uses prepared statements |
| `query_timeout` | never emitted | 30 seconds | Stored on the config only; nothing reads it, so it does not limit queries |

`size`, `initial_size`, `max_idle_size` and `max_retry_attempts` must be positive; `CQL.configure` raises `ArgumentError` otherwise.

**Guidelines for `max_pool_size`:**
- Web apps: 2-3x your web server threads
- Background jobs: Match worker count
- Maximum: Check database limits

If `checkout_timeout` is reached, crystal-db raises `DB::PoolTimeout`.

## Low-Level: `Schema.define`

`CQL::Schema.define` opens its pool through crystal-db and ignores `CQL.config`, so pool settings are query parameters on the URI you pass. There is no `pool_size` DSL inside the block:

```crystal
MyDB = CQL::Schema.define(
  :my_db,
  adapter: CQL::Adapter::Postgres,
  uri: "#{ENV["DATABASE_URL"]}?initial_pool_size=5&max_pool_size=25&checkout_timeout=5&retry_attempts=3"
) do
end
```

(If `DATABASE_URL` already has a query string, join with `&` instead of `?`.) To reuse the configured values, pass `CQL.config.full_db_url` and `CQL.config.adapter` as the second and third arguments.

The parameters are read by crystal-db's pool and work for every adapter. Defaults for parameters you omit come from crystal-db, not CQL: check your crystal-db version if you rely on them.

## Native PostgreSQL Driver Pool

`postgres://` and `postgresql://` URLs are opened by CQL's native driver unless the `pg` shard registered those names first (`cockroachdb://` is opt-in). Through `CQL.build_schema` or `CQL::Schema` the native driver still uses crystal-db's pool, so the parameters above apply.

`CQL::Postgres::AsyncEngine` has its own pool with different parameters:

| Parameter | Meaning |
|-----------|---------|
| `pool_size` | Maximum connections |
| `pool_min_size` | Connections opened by `warm_up` at startup |
| `checkout_timeout` | Seconds to wait for a free connection |
| `health_check_after` | Seconds idle before a connection is pinged |
| `max_queries` | Retire a connection after this many requests |
| `max_idle_lifetime` | Retire a connection idle this many seconds |

```crystal
engine = CQL::Postgres::AsyncEngine.connect("postgres://app:secret@db/app?pool_size=10&checkout_timeout=2")
```

When no connection becomes free in time, it raises `CQL::Postgres::PoolTimeout`. See the [native PostgreSQL driver guide](../postgres-native/README.md) and [CockroachDB](cockroachdb.md) for details.

## Monitoring Pool Health

`Schema#pool_stats` reads the pool without checking out a connection and returns a `CQL::PoolStats`:

```crystal
stats = MyDB.pool_stats
puts "Open: #{stats.open}"
puts "Idle: #{stats.idle}"
puts "In flight: #{stats.in_flight}"
puts "Max: #{stats.max}"   # 0 means unlimited
```

Before the first query it is all zeros when the pool was opened with `initial_pool_size=0`. For the async engine use `engine.pool.stats` (`max_size`, `idle`, `in_use`).

## Verify Configuration

Test your pool under load:

```crystal
# Simulate concurrent connections
10.times do
  spawn do
    User.count
    puts "Connection successful"
  end
end
sleep 1.second
```

## Common Issues

**Pool exhaustion:**
- Increase `max_pool_size`
- Reduce connection hold time
- Use transactions efficiently

**Connection timeouts:**
- Increase `checkout_timeout`
- Check network latency
- Verify database is responsive

## See Also

- [Configure CQL](configure-cql.md)
- [Configuration reference](../../reference/configuration.md)
- [Configure Database Connection](database-connection.md)
- [Configure Multiple Environments](environments.md)
- [Enable SSL Connections](ssl.md)
