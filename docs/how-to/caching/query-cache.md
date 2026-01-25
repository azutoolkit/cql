# Enable Query Caching

Improve performance by caching frequently executed queries.

## Prerequisites

- CQL installed and configured
- Understanding of your query patterns

## Basic Query Caching

Enable caching for specific queries:

```crystal
# Cache user by ID for 5 minutes
user = User.cache(5.minutes).find(user_id)

# Cache query results
posts = Post.cache(1.minute)
            .where(published: true)
            .order(created_at: :desc)
            .limit(10)
            .all
```

## Configure Default Cache

Set up a cache store in your schema:

```crystal
MyDB = CQL::Schema.define(
  :my_db,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do
  cache_store CQL::Cache::Memory.new
  default_cache_ttl 5.minutes
end
```

## Cache Stores

### Memory Cache

Simple in-memory cache (per-process):

```crystal
cache_store CQL::Cache::Memory.new(max_size: 1000)
```

### Redis Cache

Shared cache across processes:

```crystal
cache_store CQL::Cache::Redis.new(
  host: ENV["REDIS_HOST"],
  port: 6379,
  db: 1
)
```

See [Configure Redis Cache](redis.md) for details.

## Cache Keys

CQL generates cache keys from the query:

```crystal
# These generate the same cache key:
User.cache(1.minute).find(1)
User.cache(1.minute).find(1)  # Cache hit!

# Different query = different key:
User.cache(1.minute).where(id: 1).first  # Different key
```

## Custom Cache Keys

Override the default key:

```crystal
posts = Post.cache(1.hour, key: "homepage_posts")
            .where(featured: true)
            .limit(5)
            .all
```

## Cache Invalidation

### Manual Invalidation

```crystal
# Clear specific cache
MyDB.cache.delete("homepage_posts")

# Clear all caches
MyDB.cache.clear
```

### Automatic Invalidation

Invalidate on model changes:

```crystal
struct Post
  after_save :invalidate_cache
  after_destroy :invalidate_cache

  private def invalidate_cache
    MyDB.cache.delete("homepage_posts")
    MyDB.cache.delete("post:#{@id}")
    true
  end
end
```

## Conditional Caching

Cache based on conditions:

```crystal
def find_user(id : Int64, use_cache : Bool = true)
  query = User.where(id: id)
  query = query.cache(5.minutes) if use_cache
  query.first
end
```

## Cache Statistics

Monitor cache performance:

```crystal
stats = MyDB.cache.stats
puts "Hits: #{stats[:hits]}"
puts "Misses: #{stats[:misses]}"
puts "Hit rate: #{stats[:hit_rate]}%"
```

## Verify Caching

```crystal
# First call - cache miss
user = User.cache(1.minute).find(1)
puts "First: #{user.name}"

# Second call - cache hit (no query logged)
user = User.cache(1.minute).find(1)
puts "Second: #{user.name}"
```

## Best Practices

1. **Cache read-heavy queries** - Queries run many times with same parameters
2. **Short TTLs for volatile data** - Data that changes frequently
3. **Long TTLs for static data** - Reference tables, configurations
4. **Invalidate on writes** - Clear cache when data changes

## See Also

- [Configure Redis Cache](redis.md)
- [Use Per-Request Caching](per-request.md)
- [Optimize Queries](../performance/optimize-queries.md)
