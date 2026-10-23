# Set Up Connection Pooling

Configure database connection pooling for better performance and resource management.

## Prerequisites

- CQL installed and configured
- Database connection working

## Basic Pool Configuration

`CQL::Schema` opens its pool through crystal-db, so pool settings are query parameters on the database URI. There is no `pool_size` DSL inside `Schema.define`:

```crystal
MyDB = CQL::Schema.define(
  :my_db,
  adapter: CQL::Adapter::Postgres,
  uri: "#{ENV["DATABASE_URL"]}?initial_pool_size=5&max_pool_size=25&checkout_timeout=5&retry_attempts=3"
) do
end
```

(If `DATABASE_URL` already has a query string, join with `&` instead of `?`.)

## Pool Settings

These parameters are read by crystal-db's pool and work for every adapter:

| Parameter | Meaning |
|-----------|---------|
| `initial_pool_size` | Connections opened up front (`0` opens lazily on first use) |
| `max_pool_size` | Maximum open connections (`0` means unlimited) |
| `max_idle_pool_size` | Connections kept open while idle |
| `checkout_timeout` | Seconds to wait for a free connection |
| `retry_attempts` | Times a failed connection attempt is retried |
| `retry_delay` | Seconds between retries |

Defaults come from crystal-db, not CQL: check your crystal-db version if you rely on them.

**Guidelines for `max_pool_size`:**
- Web apps: 2-3x your web server threads
- Background jobs: Match worker count
- Maximum: Check database limits

If `checkout_timeout` is reached, crystal-db raises `DB::PoolTimeout`.

## Configure Pools with `CQL.configure`

`CQL.configure` has `pool_size` and a detailed `pool` object. Build the final URL with `full_db_url`, which appends the matching URI parameters:

```crystal
CQL.configure do |config|
  config.db = ENV["DATABASE_URL"]
  config.pool_size = 25
  config.pool.initial_size = 5
  config.pool.max_idle_size = 10
  config.pool.checkout_timeout = 15.seconds
  config.pool.max_retry_attempts = 5
end

MyDB = CQL::Schema.define(:my_db, CQL.config.full_db_url, CQL.config.adapter) do
end
```

`CQL.build_schema` uses `config.db` as-is (it does not call `full_db_url`), so use `full_db_url` explicitly when you want the pool settings applied. Parameters already present in the URL win over configured ones.

The defaults depend on `config.env` (`CRYSTAL_ENV`): production uses a pool of 25, development 5, test 1. See [Configure Multiple Environments](environments.md).

## Native PostgreSQL Driver Pool

`postgres://` and `postgresql://` URLs are opened by CQL's native driver unless the `pg` shard registered those names first (`cockroachdb://` is opt-in). Through `CQL::Schema` the native driver still uses crystal-db's pool, so the parameters above apply.

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

- [Configure Database Connection](database-connection.md)
- [Configure Multiple Environments](environments.md)
- [Enable SSL Connections](ssl.md)
