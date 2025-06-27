# Advanced Caching Architecture for CQL

This document outlines the enhanced caching capabilities for CQL (Crystal Query Language), providing comprehensive invalidation strategies and fragment caching functionality.

## Architecture Overview

The advanced caching system is built around a modular, extensible architecture that follows SOLID principles and integrates seamlessly with CQL's existing ActiveRecord pattern.

### Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                    CQL Advanced Caching                    │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐│
│  │ Cache Interface │  │ Fragment Cache  │  │ ActiveRecord    ││
│  │                 │  │                 │  │ Integration     ││
│  │ • Basic Ops     │  │ • Query Caching │  │                 ││
│  │ • Batch Ops     │  │ • Key Building  │  │ • Auto-invalid. ││
│  │ • Tag Support   │  │ • Tag Support   │  │ • Transactions  ││
│  │ • Versioning    │  │                 │  │ • Callbacks     ││
│  └─────────────────┘  └─────────────────┘  └─────────────────┘│
├─────────────────────────────────────────────────────────────┤
│                 Invalidation Strategies                    │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐│
│  │ Timestamp-based │  │ Version-based   │  │ Transaction-    ││
│  │ Invalidation    │  │ Invalidation    │  │ aware           ││
│  │                 │  │                 │  │ Invalidation    ││
│  │ • TTL Support   │  │ • Version Incr. │  │ • Pending Queue ││
│  │ • Auto-expire   │  │ • Consistency   │  │ • Commit/Rollbk ││
│  └─────────────────┘  └─────────────────┘  └─────────────────┘│
├─────────────────────────────────────────────────────────────┤
│                   Cache Implementations                    │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐│
│  │ Memory Cache    │  │ Redis Cache     │  │ Custom Cache    ││
│  │                 │  │ (Future)        │  │ (Extensible)    ││
│  │ • LRU Eviction  │  │                 │  │                 ││
│  │ • Thread-safe   │  │ • Distributed   │  │ • Your impl.    ││
│  │ • Tag Indexing  │  │ • Persistence   │  │ • Pluggable     ││
│  └─────────────────┘  └─────────────────┘  └─────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Cache Interface (`CacheInterface`)

The foundation of the caching system, defining a consistent API for all cache implementations.

**Key Features:**

- Basic CRUD operations (get, set, delete, exists, clear)
- Batch operations for efficiency (get_multi, set_multi, delete_multi)
- Tag-based invalidation support
- Version-based invalidation support
- Statistics and monitoring

**Crystal Code Example:**

```crystal
# Custom cache implementation
class MyRedisCache < CQL::Cache::CacheInterface
  def get(key : String) : String?
    @redis.get(key)
  end

  def set(key : String, value : String, ttl : Time::Span? = nil) : Bool
    if ttl
      @redis.setex(key, ttl.total_seconds.to_i, value)
    else
      @redis.set(key, value)
    end
    true
  end

  # ... implement other required methods
end
```

### 2. Invalidation Strategies

#### Timestamp-based Invalidation

Invalidates cache entries based on their age, providing automatic TTL-like behavior.

```crystal
# Configure timestamp-based invalidation
strategy = CQL::Cache::TimestampInvalidation.new(max_age: 1.hour)

# Use with fragment cache
cache = CQL::Cache::MemoryCache.new
fragment_cache = CQL::Cache::FragmentCache.new(cache, strategy)
```

#### Version-based Invalidation

Uses version numbers to track changes, ensuring cache consistency when data is modified.

```crystal
# Configure version-based invalidation
strategy = CQL::Cache::VersionInvalidation.new

# Increment version when data changes
strategy.increment_version("user_data")

# Cache entries with old versions will be invalidated
```

#### Transaction-aware Invalidation

Defers cache invalidation until after database transactions commit, ensuring consistency.

```crystal
# Wrap base strategy with transaction awareness
base_strategy = CQL::Cache::TimestampInvalidation.new
tx_strategy = CQL::Cache::TransactionAwareInvalidation.new(base_strategy)

# During transaction: mark for invalidation
User.transaction do |tx|
  user.save!
  tx_strategy.mark_for_invalidation(["user:#{user.id}"])
  # Cache not invalidated yet
end
# After commit: cache invalidated automatically
```

### 3. Fragment Cache (`FragmentCache`)

Provides flexible caching for arbitrary code blocks, query results, and computed values.

**Key Features:**

- Automatic cache key generation
- Parameter-based key customization
- Tag-based invalidation
- Query result caching
- Metadata storage for invalidation strategies

**Usage Patterns:**

```crystal
# Basic fragment caching
fragment_cache.cache_fragment("expensive_computation", {"param" => value}) do
  perform_expensive_operation
end

# Query result caching
fragment_cache.cache_query(sql, params, ["user", "posts"]) do
  execute_database_query
end

# Custom cache key building
key_builder = CQL::Cache::CacheKeyBuilder.new("namespace")
  .add_component("operation")
  .add_param("user_id", user.id)
  .add_param("date", Date.today)

cache_key = key_builder.build
# Result: "namespace:operation:hash_of_params"
```

### 4. ActiveRecord Integration

Seamlessly integrates caching with CQL's ActiveRecord models, providing automatic invalidation and transaction awareness.

#### Model Setup

```crystal
class User
  include CQL::ActiveRecord::Model(Int32)
  include CQL::Cache::ActiveRecordCaching
  include CQL::Cache::CacheControl

  # Set up caching for the model
  User.setup_caching(
    cache: CQL::Cache::MemoryCache.new,
    strategy: CQL::Cache::TimestampInvalidation.new,
    config: CQL::Cache::CacheConfig.new(
      default_ttl: 30.minutes,
      key_prefix: "user_cache"
    )
  )
end
```

#### Cached Operations

```crystal
# Cached finder methods
user = User.cache_find(user_id, ttl: 15.minutes)

# Cached count queries
count = User.cache_count("active_users") { User.where(active: true).count }

# Automatic invalidation on model changes
user.update!(name: "New Name")  # Automatically invalidates cache
```

#### Transaction Integration

```crystal
# Cache invalidation waits for transaction commit
User.transaction do |tx|
  user.save!  # Cache invalidation marked but not executed
  post.save!  # More cache invalidation marked
  # If transaction fails, cache invalidation is cancelled
end
# Cache invalidation executed after successful commit
```

## Cache Key Naming Schemes

### Recommended Patterns

1. **Hierarchical Keys**: `namespace:type:id:operation`

   ```
   user_cache:user:123:profile
   post_cache:post:456:content
   ```

2. **Parameter-based Keys**: Include relevant parameters in hash

   ```
   query:users:where:a1b2c3d4  # Hash of WHERE conditions
   fragment:stats:period:2024-01  # Time-based parameters
   ```

3. **Tag-based Organization**: Use consistent tagging
   ```
   Tags: ["user:123", "table:users", "profile"]
   Tags: ["post:456", "table:posts", "user:123"]
   ```

### Key Generation Utilities

```crystal
# Automatic key generation for queries
def generate_query_key(sql : String, params : Array) : String
  signature = sql + params.map(&.to_s).join(",")
  hash = Digest::MD5.hexdigest(signature)
  "query:#{hash}"
end

# Hierarchical key building
def build_model_key(model : Class, id : ID, operation : String) : String
  "#{model.name.downcase}:#{id}:#{operation}"
end

# Parameter-based key with sorting for consistency
def build_param_key(base : String, params : Hash) : String
  sorted = params.to_a.sort_by(&.[0])
  param_str = sorted.map { |k, v| "#{k}=#{v}" }.join("&")
  hash = Digest::MD5.hexdigest(param_str)
  "#{base}:#{hash}"
end
```

## Testing Strategy

### Unit Tests

1. **Cache Interface Compliance**

```crystal
describe "Cache Implementation" do
  it "implements all required interface methods" do
    cache = MyCache.new
    cache.should respond_to(:get)
    cache.should respond_to(:set)
    cache.should respond_to(:delete)
    # ... test all interface methods
  end
end
```

2. **Invalidation Strategy Tests**

```crystal
describe "TimestampInvalidation" do
  it "invalidates expired entries" do
    strategy = TimestampInvalidation.new(max_age: 1.second)

    # Cache something
    metadata = strategy.generate_metadata("key")

    # Wait for expiration
    sleep(2)

    # Should be marked for invalidation
    strategy.should_invalidate?("key", metadata).should be_true
  end
end
```

3. **Fragment Cache Tests**

```crystal
describe "FragmentCache" do
  it "caches expensive operations" do
    expensive_calls = 0

    result1 = fragment_cache.cache_fragment("test") do
      expensive_calls += 1
      "result"
    end

    result2 = fragment_cache.cache_fragment("test") do
      expensive_calls += 1
      "result"
    end

    expensive_calls.should eq(1)  # Only called once
    result1.should eq(result2)
  end
end
```

### Integration Tests

1. **ActiveRecord Integration**

```crystal
describe "ActiveRecord Caching" do
  it "invalidates cache on model updates" do
    user = User.create!(name: "Test")

    # Cache the user
    cached_user = User.cache_find(user.id)

    # Update the user
    user.update!(name: "Updated")

    # Cache should be invalidated
    User.fragment_cache.fragment_cached?("user:find:#{user.id}").should be_false
  end
end
```

2. **Transaction Awareness**

```crystal
describe "Transaction-aware Invalidation" do
  it "defers invalidation until commit" do
    cache = MemoryCache.new
    cache.set("key", "value")

    strategy = TransactionAwareInvalidation.new(base_strategy)

    User.transaction do |tx|
      strategy.mark_for_invalidation(["key"])
      cache.get("key").should eq("value")  # Still cached
    end

    cache.get("key").should be_nil  # Invalidated after commit
  end
end
```

### Performance Tests

```crystal
describe "Cache Performance" do
  it "provides significant speedup for repeated operations" do
    # Measure uncached performance
    uncached_time = measure_time do
      100.times { expensive_operation }
    end

    # Measure cached performance
    cached_time = measure_time do
      100.times {
        fragment_cache.cache_fragment("expensive") { expensive_operation }
      }
    end

    # Should be significantly faster (first call slower, rest very fast)
    speedup = uncached_time / cached_time
    speedup.should be > 50  # Expect 50x+ speedup
  end
end
```

### Memory and Resource Tests

```crystal
describe "Cache Memory Management" do
  it "respects size limits and evicts LRU entries" do
    cache = MemoryCache.new(max_size: 10)

    # Fill cache beyond limit
    20.times do |i|
      cache.set("key_#{i}", "value_#{i}")
    end

    # Should only contain 10 entries
    cache.size.should eq(10)

    # First entries should be evicted
    cache.get("key_0").should be_nil
    cache.get("key_19").should_not be_nil
  end
end
```

## Configuration Best Practices

### Development Environment

```crystal
# Liberal caching with short TTLs for fast development iteration
User.setup_caching(
  cache: MemoryCache.new(max_size: 1000),
  strategy: TimestampInvalidation.new(max_age: 5.minutes),
  config: CacheConfig.new(
    default_ttl: 2.minutes,
    key_prefix: "dev_cache"
  )
)
```

### Production Environment

```crystal
# Conservative caching with longer TTLs and transaction safety
User.setup_caching(
  cache: RedisCache.new(redis_url: ENV["REDIS_URL"]),
  strategy: CompositeInvalidation.new([
    TimestampInvalidation.new(max_age: 1.hour),
    VersionInvalidation.new
  ], logic: Logic::Or),
  config: CacheConfig.new(
    default_ttl: 30.minutes,
    key_prefix: "prod_cache",
    enable_statistics: true
  )
)
```

### Monitoring and Observability

```crystal
# Regular cache statistics reporting
spawn do
  loop do
    cache.stats.each do |key, value|
      Log.info { "Cache #{key}: #{value}" }
    end
    sleep(60.seconds)
  end
end

# Cache hit rate alerting
if cache.stats["hit_rate_percent"].as(Float64) < 80.0
  Alert.notify("Low cache hit rate: #{cache.stats["hit_rate_percent"]}%")
end
```

## Performance Considerations

### Memory Usage

- **Tag Indexing**: Tags create additional memory overhead
- **Metadata Storage**: Each cache entry stores invalidation metadata
- **LRU Tracking**: Access tracking for eviction adds memory cost

### Concurrency

- **Thread Safety**: All implementations use mutex for thread safety
- **Lock Contention**: High concurrency may create contention
- **Fiber-friendly**: Designed for Crystal's fiber concurrency model

### Network Overhead (Distributed Caches)

- **Batch Operations**: Use `get_multi`/`set_multi` for efficiency
- **Connection Pooling**: Reuse connections to reduce overhead
- **Serialization**: Consider compact serialization formats

## Extensibility

### Custom Cache Backends

```crystal
class MyCustomCache < CacheInterface
  # Implement all required methods
  # Add custom functionality like compression, encryption, etc.
end
```

### Custom Invalidation Strategies

```crystal
class BusinessLogicInvalidation < InvalidationStrategy
  def should_invalidate?(key : String, metadata : Hash(String, String)) : Bool
    # Custom business logic for invalidation
  end

  def generate_metadata(key : String) : Hash(String, String)
    # Custom metadata generation
  end
end
```

### Plugin Architecture

The modular design allows for easy extension and customization:

- Cache backends (Redis, Memcached, custom)
- Invalidation strategies (time, version, event-based)
- Key generation algorithms
- Serialization formats
- Statistics collection

This architecture provides a solid foundation for building high-performance, consistent caching solutions in Crystal applications using CQL.
