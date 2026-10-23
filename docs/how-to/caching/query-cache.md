# Enable Query Caching

Improve performance by caching expensive query results and rendered fragments in a cache store.

## Prerequisites

- CQL installed and configured
- Understanding of your query patterns

## How Caching Is Organized

| Piece | Class | Use it for |
|---|---|---|
| Value cache | `CQL::Cache::Cache` | Caching results under keys you choose, with a TTL |
| Stores | `MemoryCache`, `RedisCache` | Where values live (selected through `CacheStoreConfig`) |
| Fragment cache | `CQL::Cache::FragmentCache` | Keyed fragments and query results with tags |
| Per-request tracking | `RequestQueryCache` | Counting duplicate statements in one request, see [Use Per-Request Caching](per-request.md) |

Query objects are not cached automatically. You wrap the call you want cached.

## Basic Query Caching

```crystal
key = CQL::Cache::Cache.generate_cache_key(sql, params)

posts = CQL::Cache::Cache.with_cache(key, 1.minute) do
  # run the query and return something JSON-serializable
  Post.where(published: true).all.map(&.to_h)
end
```

`generate_cache_key(sql, params)` builds `cql:<md5 of sql + params>`; pass a third argument to use a different name than `"cql"`. Use any string you like as a key instead.

`with_cache(key, ttl)` runs the block only on a miss and stores the result as JSON. A hit returns the parsed `JSON::Any`, a miss returns the block's own value, so convert at the call site if you need one type.

The lower-level calls:

```crystal
CQL::Cache::Cache.set(key, rows, 5.minutes)  # rows : Array(DB::Any)
CQL::Cache::Cache.get(key)                   # => Array(DB::Any)?
CQL::Cache::Cache.cached?(key)               # => Bool
```

## Configure the Cache Store

The default store is an in-process `MemoryCache` with no size limit. To choose a store, pass a config:

```crystal
CQL::Cache::Cache.configure(
  CQL::Cache::CacheStoreConfig.new(
    type: CQL::Cache::CacheStoreType::Memory,
    memory_max_size: 1000
  )
)

CQL::Cache::Cache.default_ttl = 5.minutes
```

Or from environment variables: `CQL::Cache::Cache.configure_from_env` (see [Configure Redis Cache](redis.md#configure-from-the-environment)).

You can also use the central settings:

```crystal
CQL.configure do |c|
  c.cache.on = true
  c.cache.ttl = 5.minutes
  c.cache.key_prefix = "myapp"
end
```

`c.cache.on` is off by default in production and test, and on in development. `CQL.build_schema` applies these settings to the cache classes when `on` is true.

## Cache Stores

### Memory Cache

In-memory, per process, least-recently-used eviction once `max_size` is reached:

```crystal
cache = CQL::Cache::MemoryCache.new(max_size: 1000)
```

Expired entries are removed on access; `cache.cleanup_expired` sweeps them all.

### Redis Cache

Shared across processes:

```crystal
cache = CQL::Cache::RedisCache.new(ENV["REDIS_URL"], "myapp")
```

See [Configure Redis Cache](redis.md) for details.

## Cache Keys

Keys derive from the SQL text and parameters, so the same statement with the same parameters is a hit and any change is a different key:

```crystal
CQL::Cache::Cache.generate_cache_key("SELECT * FROM users WHERE id = ?", [1] of DB::Any)
CQL::Cache::Cache.generate_cache_key("SELECT * FROM users WHERE id = ?", [2] of DB::Any)  # different key
```

## Cache Invalidation

### Manual Invalidation

```crystal
store = CQL::Cache::Cache.cache_store

store.delete("homepage_posts")  # one key
CQL::Cache::Cache.clear         # everything in the store
```

### Invalidate on Model Changes

Delete or tag-invalidate from your model callbacks:

```crystal
struct Post
  after_save :invalidate_cache
  after_destroy :invalidate_cache

  private def invalidate_cache
    CQL::Cache::Cache.cache_store.invalidate_tags(["posts"])
    true
  end
end
```

## Fragment Cache and Tag Invalidation

`FragmentCache` caches a string fragment (such as rendered HTML or JSON) or a query result, and lets you tag entries so a whole group can be dropped at once.

```crystal
store = CQL::Cache::MemoryCache.new(max_size: 1000)
strategy = CQL::Cache::TimestampInvalidation.new(1.hour)
fragments = CQL::Cache::FragmentCache.new(store, strategy)
```

Or build one from `CQL.configure` settings with `CQL.fragment_cache` (it uses a new `MemoryCache` sized by `c.cache.memory_size`).

### Cache a fragment

```crystal
html = fragments.cache_fragment(
  "sidebar",
  params: {"user_id" => 7_i64} of String => DB::Any,
  tags: ["posts", "user:7"],
  ttl: 10.minutes
) do
  render_sidebar(7)   # block returns a String
end
```

The key is `<prefix>:fragment:sidebar:<md5 of sorted params>`. The block runs only on a miss. Other helpers:

```crystal
fragments.get_fragment("sidebar", params)        # => String?
fragments.fragment_cached?("sidebar", params)    # => Bool
fragments.delete_fragment("sidebar", params)     # => Bool
fragments.cache_with_key("my:key", ["posts"]) { "value" }
```

### Cache a query result

```crystal
rows = fragments.cache_query(
  "SELECT * FROM posts WHERE published = ?",
  [true] of DB::Any,
  cache_tags: ["posts"],
  ttl: 5.minutes
) do
  run_query   # returns rows that respond to to_json
end
```

On a hit the cached JSON is parsed into an array of hashes of `DB::Any` values; on a miss the block's result is returned as is.

### Invalidate by tag

```crystal
fragments.invalidate_tags(["posts"])  # => number of entries removed
```

Every entry tagged `posts` is removed, whichever fragment or query stored it. Tags work with both stores. With `MemoryCache` an entry must exist before it can be tagged, which `FragmentCache` handles by storing the value first.

### Build keys by hand

```crystal
key = CQL::Cache::CacheKeyBuilder.new("myapp")
  .add_component("posts")
  .add_param("page", 2)
  .build
```

## Invalidation Strategies

Strategies decide when a cached entry is stale. All of them implement `should_invalidate?(key, metadata)` and `generate_metadata(key)`.

| Strategy | Stale when |
|---|---|
| `TimestampInvalidation.new(max_age)` | The entry's `timestamp` metadata is older than `max_age` (default 1 hour) |
| `VersionInvalidation.new` | The entry's `version` metadata is behind the key's current version |
| `TransactionAwareInvalidation.new(base)` | Defers invalidations until you run them after a commit; otherwise delegates to `base` |

```crystal
versions = CQL::Cache::VersionInvalidation.new
versions.increment_version("posts")      # => 1
versions.get_current_version("posts")    # => 1
versions.reset_version("posts")
```

### Invalidate after a transaction commits

Avoid dropping cache entries for a transaction that rolls back:

```crystal
deferred = CQL::Cache::TransactionAwareInvalidation.new(
  CQL::Cache::TimestampInvalidation.new
)

deferred.mark_for_invalidation("post:1")             # or an Array of keys
deferred.mark_tags_for_invalidation(["posts"])

deferred.execute_pending_invalidations(store)        # after commit
deferred.clear_pending_invalidations                 # after rollback
```

You call `execute_pending_invalidations` and `clear_pending_invalidations` yourself; CQL does not hook them into transactions for you.

From `CQL.configure`, `c.cache.invalidation` selects `"timestamp"`, `"version"` or `"transaction_aware"`, and `c.cache.max_age` sets the timestamp age. Anything else fails validation when the cache is on.

`FragmentCache` records the strategy you give it (its class name appears in `fragments.stats`) but expiry and tag invalidation are what actually remove entries today. Keep the strategy objects for your own staleness checks, or use the store's TTL.

## Cache Statistics

Library-level counters live in `CacheStats`:

```crystal
stats = CQL::Cache::Cache.stats
puts "Requests: #{stats.total_requests}"
puts "Hits: #{stats.hits}"
puts "Misses: #{stats.misses}"
puts "Hit rate: #{stats.hit_rate.round(2)}%"
puts "Avg cache time: #{stats.average_cache_time}s"
puts "Avg execution time: #{stats.average_execution_time}s"
puts "Uptime: #{stats.uptime}"
stats.reset
```

`CacheStats` has `hits`, `misses`, `total_requests`, `total_cache_time`, `total_execution_time`, `start_time`, `hit_rate`, `miss_rate`, `average_cache_time`, `average_execution_time`, `uptime` and `reset`. `Cache.reset_stats` resets the shared instance.

A merged view with the store's own numbers (size, memory, and so on):

```crystal
CQL::Cache::Cache.statistics["hit_rate"]
CQL::Cache::Cache.statistics["cache_store_type"]  # "memory" or "redis"

puts CQL::Cache::Cache.performance_summary
```

The store reports its own counters too: `CQL::Cache::Cache.cache_store.stats` returns `hits`, `misses`, `hit_rate_percent`, `sets`, `deletes`, `evictions` and more.

## Verify Caching

```crystal
key = "verify:users:1"

CQL::Cache::Cache.with_cache(key, 1.minute) { puts "computing"; "alice" }  # prints "computing"
CQL::Cache::Cache.with_cache(key, 1.minute) { puts "computing"; "alice" }  # no output, a hit

puts CQL::Cache::Cache.stats.hits  # => 1
```

## Enable and Disable

```crystal
CQL::Cache::Cache.enabled = false  # with_cache just runs the block
CQL::Cache::Cache.enabled?
```

## Best Practices

1. **Cache read-heavy queries** - Queries run many times with the same parameters
2. **Short TTLs for volatile data** - Data that changes frequently
3. **Long TTLs for static data** - Reference tables, configurations
4. **Tag related entries** - Invalidate a group in one call instead of tracking keys
5. **Invalidate on writes** - Clear or tag-invalidate when data changes

## Troubleshooting

**Block runs every time:**
- Check `Cache.enabled?`.
- Check the key is stable: it must not include timestamps or object IDs.

**`invalidate_tags` returns 0:**
- Entries must have been stored with `tags:` (or `cache_tags:`) and not expired.
- On `MemoryCache`, evicted entries are also removed from their tags.

**Different processes see different data:**
- `MemoryCache` is per process. Use Redis, see [Configure Redis Cache](redis.md).

## See Also

- [Configure Redis Cache](redis.md)
- [Use Per-Request Caching](per-request.md)
- [Optimize Queries](../performance/optimize-queries.md)
