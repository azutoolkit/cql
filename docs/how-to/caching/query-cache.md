---
description: "Cache expensive results and rendered fragments in a memory or Redis store, and drop them by key or by tag."
---

# Enable Query Caching

| Piece | Class | Use it for |
| :--- | :--- | :--- |
| Value cache | `CQL::Cache::Cache`, `GlobalCache` | Results under keys you choose, with a TTL |
| Stores | `MemoryCache`, `RedisCache` | Where values live, chosen with `CacheStoreConfig` |
| Fragment cache | `FragmentCache` | Strings and query results, grouped by tags |
| Request tracking | `RequestQueryCache` | Duplicate statements in one request: [Use Per-Request Caching](per-request.md) |

## Cache a Result

CQL caches nothing on its own: wrap the call whose result you want to keep.

```crystal
titles = CQL::Cache::Cache.with_cache("homepage_titles", 1.minute) do
  Post.where(published: true).all.map(&.title)  # runs only on a miss; the value is stored as JSON
end
# miss: the block's value, Array(String); hit: the stored JSON parsed into a JSON::Any

# Keyed by a name and a Hash: "homepage:<md5 of the params>"; same return types as with_cache
CQL::Cache::Cache.cache("homepage", {"page" => 1}, 1.minute) { Post.limit(10).all.map(&.title) }

# Typed on hits too, through T.from_json
titles = CQL::Cache::GlobalCache.cache("homepage_titles:typed", 1.minute) do
  Post.where(published: true).all.map(&.title)
end

key = CQL::Cache::Cache.generate_cache_key(sql, params)  # "cql:<md5 of sql and params>"; a third argument replaces "cql"
CQL::Cache::Cache.with_cache(key, 5.minutes) { AppDB.query.from(:users).select(:name).all(as: String) }
CQL::Cache::Cache.get(key)      # => ["Ada"] as Array(DB::Any)?, for a cached JSON array
CQL::Cache::Cache.cached?(key)  # => true

CQL::Cache::Cache.enabled = false  # with_cache runs the block, get returns nil, cached? false
```

`with_cache` without a TTL uses `Cache.default_ttl` (1 hour). `GlobalCache` ignores `Cache.enabled` and is not counted in `Cache.stats`.

{% hint style="warning" %}
`Cache.set(key, rows, ttl)` does not compile: its `Array(DB::Any)` can hold `Bytes`, which has no JSON form. Store values with `with_cache`, `GlobalCache.set` or `cache_store.set`, and keep `Bytes` out of cached values.
{% endhint %}

## Choose a Store

{% tabs %}
{% tab title="Memory" %}
```crystal
CQL::Cache::Cache.configure(
  CQL::Cache::CacheStoreConfig.new(type: CQL::Cache::CacheStoreType::Memory, memory_max_size: 1000)
)

store = CQL::Cache::Cache.cache_store         # a MemoryCache unless configured: per process, unbounded
store.as(CQL::Cache::MemoryCache).cleanup_expired  # expired entries are otherwise dropped when read
```

A full `MemoryCache` evicts its least recently used entry.
{% endtab %}

{% tab title="Redis" %}
```crystal
CQL::Cache::Cache.configure(
  CQL::Cache::CacheStoreConfig.new(type: CQL::Cache::CacheStoreType::Redis, redis_url: ENV["REDIS_URL"])
)

CQL::Cache::Cache.cache_store.class  # => CQL::Cache::RedisCache, shared by every process
```

Every Redis option and the environment variables are in [Configure Redis Cache](redis.md).
{% endtab %}
{% endtabs %}

Then set the TTL, or read the whole setup from the environment:

```crystal
CQL::Cache::Cache.default_ttl = 5.minutes
CQL::Cache::Cache.configure_from_env  # CQL_CACHE_* variables, see Configure Redis Cache

CQL.configure do |c|
  c.cache.on = true        # default: on when CRYSTAL_ENV is development or unset, off otherwise
  c.cache.ttl = 5.minutes  # with c.cache.on, CQL.build_schema copies it to Cache.default_ttl
end
```

## Invalidate by Key

```crystal
CQL::Cache::Cache.cache_store.delete("homepage_titles")  # one key
CQL::Cache::Cache.clear                                  # every entry in the store

class Post
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: AppDB, table: :posts
  # ...
  after_save :expire_cache     # runs on save and save!; create! and update! skip callbacks
  after_destroy :expire_cache  # runs on delete!

  private def expire_cache
    CQL::Cache::Cache.cache_store.delete("homepage_titles")
    true
  end
end
```

## Fragment Cache and Tag Invalidation

```crystal
store = CQL::Cache::MemoryCache.new(max_size: 1000)
fragments = CQL::Cache::FragmentCache.new(store, CQL::Cache::TimestampInvalidation.new(1.hour))

params = {"user_id" => 7_i64} of String => DB::Any
html = fragments.cache_fragment("sidebar", params: params, tags: ["posts", "user:7"], ttl: 10.minutes) do
  render_sidebar(7)  # returns a String; runs only on a miss
end
# key: "cql:fragment:sidebar:<md5 of the sorted params>"; the default TTL is 1 hour

fragments.get_fragment("sidebar", params)      # => String?
fragments.fragment_cached?("sidebar", params)  # => true
fragments.delete_fragment("sidebar", params)   # => true
fragments.cache_with_key("nav", ["posts"]) { render_nav }

rows = fragments.cache_query("SELECT title FROM posts WHERE published = ?", [true] of DB::Any,
  cache_tags: ["posts"], ttl: 5.minutes) do
  AppDB.query.from(:posts).select(:title).where(published: true).all(as: String).map { |t| {"title" => t} }
end
# miss: the block's value; hit: Array(Hash(String, DB::Any)) parsed from the stored JSON

fragments.invalidate_tags(["posts"])  # => 2, every entry tagged "posts", whichever call stored it

CQL::Cache::CacheKeyBuilder.new("myapp").add_component("posts").add_param("page", 2).build
# => "myapp:posts:<md5 of page=2>"
```

Tags work with both stores; deleting or evicting a `MemoryCache` entry also removes it from its tags. `FragmentCache` never consults its strategy: only TTLs and tags remove entries.

## Use an Invalidation Strategy

```crystal
versions = CQL::Cache::VersionInvalidation.new
versions.increment_version("posts")                       # => 1
versions.should_invalidate?("posts", {"version" => "0"})  # => true: behind the current version
versions.reset_version("posts")

stale = CQL::Cache::TimestampInvalidation.new(1.hour)     # default max age 1 hour
stale.should_invalidate?("k", stale.generate_metadata("k"))  # => false while younger than 1 hour

# Drop entries only once a transaction commits
deferred = CQL::Cache::TransactionAwareInvalidation.new(CQL::Cache::TimestampInvalidation.new)
AppDB.transaction do
  Post.create!(title: "New", published: true)
  deferred.mark_for_invalidation("homepage_titles")  # or an Array of keys
  deferred.mark_tags_for_invalidation(["posts"])
end
deferred.execute_pending_invalidations(store)  # after commit; CQL does not call it for you
deferred.clear_pending_invalidations           # after a rollback instead
```

{% hint style="warning" %}
`TransactionAwareInvalidation` is not an `InvalidationStrategy`, so `FragmentCache.new` rejects it, and `CQL.fragment_cache` fails to compile for the same reason. Build the `FragmentCache` yourself.
{% endhint %}

## Read Cache Statistics

```crystal
stats = CQL::Cache::Cache.stats  # CacheStats for with_cache, Cache.cache and get
stats.hits                       # => 1
stats.misses                     # => 1
stats.hit_rate                   # => 50.0 (percent; also miss_rate)
stats.average_execution_time     # seconds per request spent in blocks (also average_cache_time, uptime)
CQL::Cache::Cache.reset_stats

CQL::Cache::Cache.statistics["cache_store_type"]  # "memory" or "redis", merged with the store's stats
CQL::Cache::Cache.cache_store.stats               # the store's own: hits, misses, hit_rate_percent, sets, deletes, evictions
puts CQL::Cache::Cache.performance_summary
```

When the block runs every time, check `Cache.enabled?` and that the key holds no timestamps or object ids. When `invalidate_tags` returns 0, the entries were stored without tags or have expired.

## See Also

- [Configure Redis Cache](redis.md)
- [Use Per-Request Caching](per-request.md)
- [Optimize Queries](../performance/optimize-queries.md)
- [Avoid N+1 Queries](../performance/n-plus-one.md)
