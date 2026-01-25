# Configure Redis Cache

Set up Redis as your query cache store for shared caching across processes.

## Prerequisites

- CQL installed
- Redis server running
- `crystal-redis` shard installed

## Install Redis Shard

Add to your `shard.yml`:

```yaml
dependencies:
  redis:
    github: stefanwille/crystal-redis
    version: ~> 2.8.0
```

Run `shards install`.

## Basic Configuration

```crystal
require "cql"
require "redis"

MyDB = CQL::Schema.define(
  :my_db,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do
  cache_store CQL::Cache::Redis.new(
    host: "localhost",
    port: 6379
  )
end
```

## Connection Options

```crystal
cache_store CQL::Cache::Redis.new(
  host: ENV["REDIS_HOST"]? || "localhost",
  port: (ENV["REDIS_PORT"]? || "6379").to_i,
  password: ENV["REDIS_PASSWORD"]?,
  db: 1,                    # Use database 1 for cache
  pool_size: 5,
  timeout: 2.seconds
)
```

## Using Redis URL

```crystal
cache_store CQL::Cache::Redis.new(
  url: ENV["REDIS_URL"]  # redis://user:pass@host:port/db
)
```

## Key Prefixing

Namespace your cache keys:

```crystal
cache_store CQL::Cache::Redis.new(
  host: "localhost",
  prefix: "myapp:cache:"
)
```

All keys will be prefixed: `myapp:cache:users:1`

## TTL Configuration

```crystal
MyDB = CQL::Schema.define(:my_db, adapter: CQL::Adapter::Postgres, uri: db_url) do
  cache_store CQL::Cache::Redis.new(host: "localhost")
  default_cache_ttl 10.minutes
end

# Override per query
User.cache(1.hour).find(1)
```

## Connection Pooling

For high-traffic apps:

```crystal
cache_store CQL::Cache::Redis.new(
  host: "localhost",
  pool_size: 25,
  checkout_timeout: 3.seconds
)
```

## Cluster Support

For Redis Cluster:

```crystal
cache_store CQL::Cache::RedisCluster.new(
  nodes: [
    "redis://node1:6379",
    "redis://node2:6379",
    "redis://node3:6379"
  ]
)
```

## Cache Operations

```crystal
# Manual cache operations
cache = MyDB.cache

# Set value
cache.set("custom_key", data.to_json, ttl: 1.hour)

# Get value
value = cache.get("custom_key")

# Delete
cache.delete("custom_key")

# Clear all (with prefix)
cache.clear
```

## Monitoring

Check Redis cache stats:

```crystal
stats = MyDB.cache.stats
puts "Hits: #{stats[:hits]}"
puts "Misses: #{stats[:misses]}"
puts "Memory: #{stats[:memory_used]}"
```

Direct Redis monitoring:

```bash
redis-cli INFO stats
redis-cli MONITOR
```

## Verify Configuration

```crystal
# Test connection
if MyDB.cache.connected?
  puts "Redis connected"
else
  puts "Redis connection failed"
end

# Test caching
User.cache(1.minute).find(1)
User.cache(1.minute).find(1)  # Should be cached

puts MyDB.cache.stats
```

## Troubleshooting

**Connection refused:**
- Verify Redis is running: `redis-cli ping`
- Check host/port configuration
- Check firewall rules

**Authentication failed:**
- Verify password is correct
- Check Redis `requirepass` configuration

**Memory issues:**
- Set `maxmemory` in Redis config
- Use `maxmemory-policy volatile-lru`

## See Also

- [Enable Query Caching](query-cache.md)
- [Use Per-Request Caching](per-request.md)
- [Configure Database Connection](../configuration/database-connection.md)
