# Configure Redis Cache

Use Redis as the cache store so cached values are shared across processes.

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

Describe the store with `CQL::Cache::CacheStoreConfig` and hand it to `CQL::Cache::Cache.configure`:

```crystal
require "cql"

CQL::Cache::Cache.configure(
  CQL::Cache::CacheStoreConfig.new(
    type: CQL::Cache::CacheStoreType::Redis,
    redis_url: ENV["REDIS_URL"],
    key_prefix: "myapp"
  )
)
```

`CacheStoreConfig` options:

| Option | Default | Meaning |
|---|---|---|
| `type` | `Memory` | `CacheStoreType::Memory` or `CacheStoreType::Redis` |
| `default_ttl` | `1.hour` | Stored on the config; see [TTL Configuration](#ttl-configuration) |
| `key_prefix` | `"cql"` | Prefix for every key |
| `redis_url` | `redis://localhost:6379/0` | Redis connection URL |
| `redis_pool_size` | `25` | Connection pool size |
| `redis_timeout` | `5.seconds` | Pool checkout timeout |
| `memory_max_size` / `max_size` | `nil` | Entry limit for the memory store |

## Configure From the Environment

```crystal
CQL::Cache::Cache.configure_from_env
```

| Variable | Sets |
|---|---|
| `CQL_CACHE_TYPE` | `redis` or `memory` |
| `CQL_REDIS_URL` or `REDIS_URL` | `redis_url` (also switches the type to Redis) |
| `CQL_CACHE_PREFIX` | `key_prefix` |
| `CQL_CACHE_TTL` | `default_ttl`, in seconds |
| `CQL_REDIS_POOL_SIZE` | `redis_pool_size` |
| `CQL_REDIS_TIMEOUT` | `redis_timeout`, in seconds |
| `CQL_MEMORY_CACHE_MAX_SIZE` | `memory_max_size` |

`CQL::Cache::CacheStore.configure_from_hash` accepts the same settings as a hash with string keys (`"type"`, `"default_ttl"`, `"key_prefix"`, `"redis_url"`, `"redis_pool_size"`, `"redis_timeout"`, `"memory_max_size"`).

## Using the Redis Cache Directly

Skip the factory and build a `RedisCache` yourself:

```crystal
cache = CQL::Cache::RedisCache.new("redis://localhost:6379/0", "myapp")
```

or with a `Config`:

```crystal
config = CQL::Cache::RedisCache::Config.new(
  url: ENV["REDIS_URL"],
  key_prefix: "myapp",
  connection_pool_size: 5,
  connection_timeout: 2.seconds
)
cache = CQL::Cache::RedisCache.new(config)
```

`Config` also has `command_timeout` and `reconnect_attempts`; the current implementation does not apply them. Credentials and the database number go in the URL: `redis://user:pass@host:6379/1`.

## Key Prefixing

Every key is stored as `<key_prefix>:<key>`. With `key_prefix: "myapp"`, the key `users:1` is stored as `myapp:users:1`. `clear` deletes only keys under your prefix.

## TTL Configuration

The TTL is a per-call argument on the store, and a default on the `Cache` class:

```crystal
CQL::Cache::Cache.default_ttl = 10.minutes

cache = CQL::Cache::Cache.cache_store
cache.set("report", json, 1.hour)  # explicit TTL
cache.set("flag", "on")            # no TTL, never expires
```

`CacheStoreConfig#default_ttl` is not copied to `Cache.default_ttl`; set that one explicitly as above. Without a TTL, Redis keeps the key until it is deleted or evicted.

## Cache Operations

```crystal
cache = CQL::Cache::Cache.cache_store

cache.set("custom_key", data.to_json, 1.hour)
cache.get("custom_key")        # => String?
cache.exists?("custom_key")
cache.delete("custom_key")
cache.clear                    # removes keys under the prefix

cache.set_multi({"a" => "1", "b" => "2"}, 5.minutes)
cache.get_multi(["a", "b"])    # => Hash(String, String?)
cache.delete_multi(["a", "b"]) # => number deleted
```

For typed values, `CQL::Cache::GlobalCache` serializes through JSON:

```crystal
CQL::Cache::GlobalCache.set("user:1", user_hash, 5.minutes)
CQL::Cache::GlobalCache.get("user:1", Hash(String, String))
```

`GlobalCache` uses `CacheStore.instance`, which is built from the config passed to `CacheStore.configure` (`Cache.configure` calls it).

## Tags and Versions

`RedisCache` supports tag invalidation and per-key version counters. See [Tag Invalidation](query-cache.md#fragment-cache-and-tag-invalidation) for how to use tags.

```crystal
cache.tag_cache("post:1", ["posts"])  # tag an existing key
cache.invalidate_tags(["posts"])      # => number of keys deleted

cache.increment_version("posts")      # => 1
cache.get_version("posts")            # => 1
```

Redis errors are rescued: reads return `nil`, writes return `false`.

## Monitoring

```crystal
stats = CQL::Cache::Cache.cache_store.stats
puts stats["hits"]
puts stats["misses"]
puts stats["hit_rate_percent"]
puts stats["redis_memory_usage_bytes"]?  # from INFO, when available
```

The hit and miss counters are kept by the CQL process. `redis_memory_usage_bytes`, `redis_connected_clients`, `redis_keyspace_hits` and `redis_keyspace_misses` come from the server.

Direct Redis monitoring:

```bash
redis-cli INFO stats
redis-cli MONITOR
```

## Verify Configuration

```crystal
cache = CQL::Cache::RedisCache.new(ENV["REDIS_URL"])

if cache.ping
  puts "Redis connected"
else
  puts "Redis connection failed"
end

cache.set("probe", "ok", 1.minute)
puts cache.get("probe")  # => "ok"
puts cache.stats
```

## Troubleshooting

**Connection refused (`ping` returns false, reads return nil):**
- Verify Redis is running: `redis-cli ping`
- Check the host and port in `redis_url`
- Check firewall rules

**Authentication failed:**
- Put the password in the URL: `redis://:password@host:6379/0`
- Check Redis `requirepass` configuration

**The cache still behaves like memory:**
- `type` defaults to `Memory`. Set `CacheStoreType::Redis`, or provide `CQL_REDIS_URL` / `REDIS_URL` when using `configure_from_env`.
- Configure before the first cache call. `Cache.configure` resets the stored instance so the new config takes effect.

**Memory issues:**
- Set `maxmemory` in Redis config
- Use `maxmemory-policy volatile-lru`

**`clear` or `size` is slow:**
- Both use `KEYS <prefix>:*`, which scans the whole keyspace. Avoid calling them on hot paths against a large Redis.

## See Also

- [Enable Query Caching](query-cache.md)
- [Use Per-Request Caching](per-request.md)
- [Configure Database Connection](../configuration/database-connection.md)
