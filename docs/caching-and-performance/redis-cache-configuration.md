# Redis Cache Configuration

CQL now supports configurable cache stores, allowing you to choose between in-memory caching and Redis-based caching for improved performance and scalability.

## Overview

The cache system provides multiple backends:

- **Memory Cache**: Fast in-process caching (default)
- **Redis Cache**: Distributed caching with persistence and advanced features

## Quick Start

### Environment Variable Configuration

The simplest way to configure Redis caching is through environment variables:

```bash
export CQL_CACHE_TYPE=redis
export CQL_REDIS_URL=redis://localhost:6379/0
export CQL_CACHE_PREFIX=myapp
export CQL_CACHE_TTL=3600
```

```crystal
require "cql"

# Configure from environment
CQL::Cache::Cache.configure_from_env

# Use the cache
CQL::Cache::Cache.set("user:123", user_data)
cached_user = CQL::Cache::Cache.get("user:123")
```

### Programmatic Configuration

For more control, configure the cache programmatically:

```crystal
config = CQL::Cache::CacheStoreConfig.new(
  type: CQL::Cache::CacheStoreType::Redis,
  redis_url: "redis://localhost:6379/1",
  key_prefix: "myapp",
  default_ttl: 1.hour,
  redis_pool_size: 25,
  redis_timeout: 5.seconds
)

CQL::Cache::Cache.configure(config)
```

## Configuration Options

### General Settings

| Option        | Environment Variable | Type    | Default    | Description                            |
| ------------- | -------------------- | ------- | ---------- | -------------------------------------- |
| `type`        | `CQL_CACHE_TYPE`     | String  | `"memory"` | Cache backend: `"memory"` or `"redis"` |
| `key_prefix`  | `CQL_CACHE_PREFIX`   | String  | `"cql"`    | Prefix for all cache keys              |
| `default_ttl` | `CQL_CACHE_TTL`      | Integer | `3600`     | Default TTL in seconds                 |

### Redis-Specific Settings

| Option            | Environment Variable         | Type    | Default                      | Description                   |
| ----------------- | ---------------------------- | ------- | ---------------------------- | ----------------------------- |
| `redis_url`       | `CQL_REDIS_URL`, `REDIS_URL` | String  | `"redis://localhost:6379/0"` | Redis connection URL          |
| `redis_pool_size` | `CQL_REDIS_POOL_SIZE`        | Integer | `25`                         | Connection pool size          |
| `redis_timeout`   | `CQL_REDIS_TIMEOUT`          | Integer | `5`                          | Connection timeout in seconds |

### Memory Cache Settings

| Option            | Environment Variable        | Type    | Default | Description                                  |
| ----------------- | --------------------------- | ------- | ------- | -------------------------------------------- |
| `memory_max_size` | `CQL_MEMORY_CACHE_MAX_SIZE` | Integer | `nil`   | Maximum number of entries (unlimited if nil) |

## Usage Patterns

### Basic Cache Operations

```crystal
# Set a value with default TTL
CQL::Cache::Cache.set("key", value)

# Set a value with custom TTL
CQL::Cache::Cache.set("key", value, 30.minutes)

# Get a value
cached_value = CQL::Cache::Cache.get("key")

# Check if key exists
exists = CQL::Cache::Cache.has_key?("key")

# Delete a key
CQL::Cache::Cache.delete("key")

# Clear all cache
CQL::Cache::Cache.clear
```

### Using CacheStore Factory

Create specific cache instances:

```crystal
# Create a Redis cache
redis_cache = CQL::Cache::CacheStore.create("redis",
  redis_url: "redis://localhost:6379/2",
  key_prefix: "specific_app"
)

# Create a memory cache
memory_cache = CQL::Cache::CacheStore.create("memory",
  max_size: 1000
)

# Use the cache
redis_cache.set("session:abc", session_data, 15.minutes)
```

### Global Cache Convenience Methods

```crystal
# Simple get/set
CQL::Cache::GlobalCache.set("config", {theme: "dark"})
config = CQL::Cache::GlobalCache.get("config", Hash(String, String))

# Cache with block execution
result = CQL::Cache::GlobalCache.cache("expensive_operation", 1.hour) do
  perform_expensive_calculation()
end
```

### Advanced Redis Features

#### Batch Operations

```crystal
# Set multiple values at once
data = {
  "user:1" => user1_data,
  "user:2" => user2_data,
  "user:3" => user3_data
}
redis_cache.set_multi(data, 30.minutes)

# Get multiple values at once
users = redis_cache.get_multi(["user:1", "user:2", "user:3"])
```

#### Tag-Based Invalidation

```crystal
# Set values with tags
redis_cache.set("user:1:profile", profile_data)
redis_cache.set("user:1:settings", settings_data)

# Tag the cache entries
redis_cache.tag_cache("user:1:profile", ["user", "profile"])
redis_cache.tag_cache("user:1:settings", ["user", "settings"])

# Invalidate all entries with a specific tag
redis_cache.invalidate_tags(["user"])
```

#### Version-Based Invalidation

```crystal
# Get current version for a key
version = redis_cache.get_version("data_key")

# Increment version (invalidates related cache entries)
new_version = redis_cache.increment_version("data_key")
```

## Production Configuration

### Docker Compose Example

```yaml
version: "3.8"
services:
  app:
    build: .
    environment:
      - CQL_CACHE_TYPE=redis
      - CQL_REDIS_URL=redis://redis:6379/0
      - CQL_CACHE_PREFIX=myapp_prod
      - CQL_REDIS_POOL_SIZE=50
    depends_on:
      - redis

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes

volumes:
  redis_data:
```

### Environment Configuration

```bash
# Production settings
export CQL_CACHE_TYPE=redis
export CQL_REDIS_URL=redis://redis-cluster:6379/0
export CQL_CACHE_PREFIX=myapp_prod
export CQL_CACHE_TTL=7200
export CQL_REDIS_POOL_SIZE=100
export CQL_REDIS_TIMEOUT=10
```

### High Availability Setup

```crystal
# Configure with Redis Sentinel or Cluster
config = CQL::Cache::CacheStoreConfig.new(
  type: CQL::Cache::CacheStoreType::Redis,
  redis_url: "redis://redis-sentinel:26379/mymaster",
  redis_pool_size: 100,
  redis_timeout: 10.seconds
)

CQL::Cache::Cache.configure(config)
```

## Performance Monitoring

### Cache Statistics

```crystal
# Get detailed statistics
stats = CQL::Cache::Cache.statistics

puts "Cache Type: #{stats["cache_store_type"]}"
puts "Hit Rate: #{stats["hit_rate"]}%"
puts "Total Requests: #{stats["total_requests"]}"
puts "Cache Size: #{stats["cache_size"]} entries"

# Redis-specific stats (if available)
if stats["redis_memory_usage_bytes"]?
  puts "Redis Memory: #{stats["redis_memory_usage_bytes"]} bytes"
  puts "Connected Clients: #{stats["redis_connected_clients"]}"
end
```

### Performance Summary

```crystal
# Get formatted performance summary
summary = CQL::Cache::Cache.performance_summary
puts summary
```

## Best Practices

### Key Naming Conventions

```crystal
# Use hierarchical key structure
"app:user:#{user_id}:profile"
"app:session:#{session_id}"
"app:query:#{query_hash}"

# Include version in keys when appropriate
"app:config:v2:feature_flags"
```

### TTL Strategy

```crystal
# Short TTL for frequently changing data
CQL::Cache::Cache.set("user:online_status", status, 30.seconds)

# Medium TTL for semi-static data
CQL::Cache::Cache.set("user:profile", profile, 15.minutes)

# Long TTL for rarely changing data
CQL::Cache::Cache.set("app:config", config, 24.hours)
```

### Error Handling

```crystal
begin
  cached_data = CQL::Cache::Cache.get("key")
  if cached_data.nil?
    # Cache miss - fetch from database
    data = fetch_from_database()
    CQL::Cache::Cache.set("key", data, 1.hour)
    data
  else
    cached_data
  end
rescue Redis::Error => e
  # Handle Redis errors gracefully
  Log.warn { "Cache error: #{e.message}" }
  fetch_from_database() # Fallback to database
end
```

### Memory Management

```crystal
# For memory cache, set reasonable limits
config = CQL::Cache::CacheStoreConfig.new(
  type: CQL::Cache::CacheStoreType::Memory,
  memory_max_size: 10_000  # Limit to 10k entries
)

# For Redis, monitor memory usage
stats = redis_cache.stats
if stats["redis_memory_usage_bytes"].as(Int64) > 1.gigabyte
  Log.warn { "Redis memory usage high: #{stats["redis_memory_usage_bytes"]} bytes" }
end
```

## Migration Guide

### From Built-in Cache to Redis

1. **Add Redis dependency** (already included):

   ```yaml
   dependencies:
     redis:
       github: stefanwille/crystal-redis
       version: ~> 2.8
   ```

2. **Update configuration**:

   ```crystal
   # Before (built-in cache)
   CQL::Cache::Cache.enabled = true

   # After (Redis cache)
   CQL::Cache::Cache.configure_from_env
   ```

3. **Set environment variables**:

   ```bash
   export CQL_CACHE_TYPE=redis
   export CQL_REDIS_URL=redis://localhost:6379/0
   ```

4. **Test the migration**:
   ```crystal
   # Verify cache is working
   CQL::Cache::Cache.set("test", "value")
   result = CQL::Cache::Cache.get("test")
   puts "Cache working: #{result == "value"}"
   ```

## Troubleshooting

### Common Issues

#### Redis Connection Errors

```crystal
# Check Redis connectivity
if redis_cache.is_a?(CQL::Cache::RedisCache)
  if redis_cache.ping
    puts "Redis connection OK"
  else
    puts "Redis connection failed"
  end
end
```

#### High Memory Usage

```crystal
# Monitor cache size
stats = CQL::Cache::Cache.statistics
if stats["cache_size"].as(Int32) > 100_000
  puts "Cache size getting large: #{stats["cache_size"]} entries"
  # Consider clearing cache or reducing TTL
end
```

#### Performance Issues

```crystal
# Check hit rates
stats = CQL::Cache::Cache.statistics
hit_rate = stats["hit_rate"].as(Float64)

if hit_rate < 80.0
  puts "Low cache hit rate: #{hit_rate}%"
  # Consider adjusting TTL or cache keys
end
```

### Debug Mode

```crystal
# Enable detailed logging
Log.setup(:debug)

# Test cache operations with logging
CQL::Cache::Cache.set("debug_key", "debug_value")
value = CQL::Cache::Cache.get("debug_key")
```

## Examples

See the complete working example in `examples/redis_cache_demo.cr` for a comprehensive demonstration of all features.
