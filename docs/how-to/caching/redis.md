# Configure Redis Cache

Use Redis as the cache store so that every process shares the cached values.

CQL depends on the `crystal-redis` shard (`stefanwille/crystal-redis`, `~> 2.8`), so there is nothing to add to `shard.yml`. You need a reachable Redis server.

## Point the Cache at Redis

```crystal
CQL::Cache::Cache.configure(
  CQL::Cache::CacheStoreConfig.new(
    type: CQL::Cache::CacheStoreType::Redis,  # default Memory
    redis_url: ENV["REDIS_URL"],              # default "redis://localhost:6379/0"; user, password and db go here
    key_prefix: "myapp",                      # default "cql": every key is stored as "myapp:<key>"
    redis_pool_size: 25,                      # default 25 connections
    redis_timeout: 5.seconds,                 # default 5 s to check out a pooled connection
  )
)

CQL::Cache::Cache.cache_store.class  # => CQL::Cache::RedisCache
CQL::Cache::Cache.default_ttl = 10.minutes
```

`Cache.configure` replaces the store, so values cached before it stay in the old one. The config's `default_ttl` (1 hour) stays on the config: set `Cache.default_ttl` yourself.

## Configure From the Environment

```crystal
CQL::Cache::Cache.configure_from_env
```

```bash
CQL_CACHE_TYPE=redis                         # or memory
CQL_REDIS_URL=redis://:secret@cache:6379/1   # or REDIS_URL; either one also switches the type to redis
CQL_CACHE_PREFIX=myapp                       # key_prefix
CQL_CACHE_TTL=600                            # default_ttl, in seconds
CQL_REDIS_POOL_SIZE=25                       # redis_pool_size
CQL_REDIS_TIMEOUT=5                          # redis_timeout, in seconds
CQL_MEMORY_CACHE_MAX_SIZE=1000               # memory_max_size, for the memory store
```

The same settings as a Hash, for configuration files:

```crystal
CQL::Cache::CacheStore.configure_from_hash({"type" => "redis", "redis_url" => "redis://localhost:6379/0",
                                            "key_prefix" => "myapp", "default_ttl" => 600})
```

## Build a RedisCache Yourself

```crystal
cache = CQL::Cache::RedisCache.new("redis://localhost:6379/0", "myapp")

config = CQL::Cache::RedisCache::Config.new(
  url: ENV["REDIS_URL"], key_prefix: "myapp", connection_pool_size: 5, connection_timeout: 2.seconds
)
cache = CQL::Cache::RedisCache.new(config)  # command_timeout and reconnect_attempts are accepted but not applied
```

## Read and Write

```crystal
cache = CQL::Cache::Cache.cache_store

cache.set("report", report_json, 1.hour)  # SETEX with whole seconds; a TTL under 1 second fails (false)
cache.set("flag", "on")                   # no TTL: kept until deleted or evicted by Redis
cache.get("report")                       # => String?
cache.exists?("report")                   # => true
cache.delete("report")                    # => true

cache.set_multi({"a" => "1", "b" => "2"}, 5.minutes)
cache.get_multi(["a", "b"])               # => {"a" => "1", "b" => "2"}
cache.delete_multi(["a", "b"])            # => 2

CQL::Cache::GlobalCache.set("user:1", {"name" => "Ada"}, 5.minutes)  # JSON
CQL::Cache::GlobalCache.get("user:1", Hash(String, String))           # => {"name" => "Ada"}

cache.clear  # deletes every key under the prefix
cache.size   # counts them, leaving out tag and version keys
```

{% hint style="warning" %}
`clear` and `size` run `KEYS myapp:*`, which scans the whole keyspace. Keep them off hot paths on a large Redis.
{% endhint %}

## Tag and Version Keys

```crystal
cache.set("post:1", post_json, 1.hour)
cache.tag_cache("post:1", ["posts"])  # adds "myapp:post:1" to the set "myapp:tag:posts"
cache.invalidate_tags(["posts"])      # => 1, keys deleted

cache.increment_version("posts")      # => 1, INCR "myapp:version:posts"
cache.get_version("posts")            # => 1
```

[Fragment Cache and Tag Invalidation](query-cache.md#fragment-cache-and-tag-invalidation) tags entries for you.

## Verify the Connection

```crystal
cache = CQL::Cache::RedisCache.new(ENV["REDIS_URL"])
cache.ping                       # => true; false when Redis cannot be reached
cache.set("probe", "ok", 1.minute)
cache.get("probe")               # => "ok"
cache.stats                      # type, key_prefix, hits, misses, hit_rate_percent, sets, deletes, evictions
```

Redis errors are rescued: reads return `nil`, writes `false`, `size` 0. The hit and miss counters live in your process.

```bash
redis-cli -u "$REDIS_URL" ping        # PONG
redis-cli -u "$REDIS_URL" INFO stats  # keyspace_hits, keyspace_misses, evicted_keys
redis-cli -u "$REDIS_URL" MONITOR     # every command, live
```

If the cache still behaves like memory, the config's `type` is still `Memory`, or no `CQL_REDIS_URL`/`REDIS_URL` was set for `configure_from_env`. To bound Redis memory, set `maxmemory` with `maxmemory-policy volatile-lru`.

## See Also

- [Enable Query Caching](query-cache.md)
- [Use Per-Request Caching](per-request.md)
- [Configure Database Connection](../configuration/database-connection.md)
