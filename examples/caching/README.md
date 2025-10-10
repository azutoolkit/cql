# Advanced Caching Examples

This directory contains comprehensive examples of CQL's enterprise-grade caching system. These examples demonstrate advanced patterns, strategies, and integrations for building high-performance Crystal applications.

## 📝 Examples Overview

### 🏗️ **active_record_cache_demo.cr**

**Purpose:** Demonstrates how caching integrates seamlessly with ActiveRecord model operations
**Features:**

- Model-level cache configuration
- Automatic cache key and tag generation
- Cached find operations with performance gains
- Fragment caching for expensive computations
- Automatic cache invalidation on model changes
- Tag-based invalidation for related data
- Cache versioning and advanced control
- Comprehensive performance monitoring

**Run:** `crystal active_record_cache_demo.cr`

### 🎯 **activerecord_cache_demo.cr**

**Purpose:** ActiveRecord Model integration with advanced caching capabilities
**Features:**

- CQL::ActiveRecord::Model includes CQL::Cache::ActiveRecordCaching
- Model instances with cache key generation methods
- Cache tag generation for model relationships
- Automatic invalidation on model updates
- Fragment caching for expensive computations
- Performance monitoring and statistics

**Run:** `crystal activerecord_cache_demo.cr`

### 🚀 **advanced_caching_example.cr**

**Purpose:** Complex caching patterns with database integration
**Features:**

- Fragment caching with database models
- Timestamp-based invalidation
- Version-based invalidation
- Transaction-aware invalidation
- Tag-based invalidation
- Complex query caching
- Cache performance monitoring
- LRU eviction demonstration

**Run:** `crystal advanced_caching_example.cr`

### ⚙️ **cache_configuration_example.cr**

**Purpose:** Demonstrates cache configuration and setup patterns
**Features:**

- Environment-based cache configuration
- Memory cache configuration
- TTL (Time To Live) management
- Cache size and performance tuning
- Error handling and validation

**Run:** `crystal cache_configuration_example.cr`

### 🔴 **redis_cache_demo.cr**

**Purpose:** Comprehensive Redis cache backend integration
**Features:**

- Multiple Redis configuration methods
- Environment variable configuration
- Programmatic configuration
- Direct CacheStore factory usage
- Batch operations (set_multi, get_multi)
- Tag-based invalidation
- Performance comparison (Memory vs Redis)
- Redis-specific features

**Run:** `crystal redis_cache_demo.cr`
**Prerequisites:** Redis server running

### 🌐 **per_request_query_cache_demo.cr**

**Purpose:** Per-request query caching for web applications
**Features:**

- Automatic SQL query deduplication per request
- Manual request lifecycle management
- Automatic request block management
- Complex queries with JOINs
- Web framework integration simulation
- Performance benchmarking
- Thread-safe operations

**Run:** `crystal per_request_query_cache_demo.cr`

### 🔧 **with_cache_demo.cr**

**Purpose:** Comprehensive demonstration of the `with_cache` method
**Features:**

- Basic `with_cache` usage with different data types
- Custom TTL (Time To Live) settings
- Caching complex objects and database results
- Expensive computation caching with performance monitoring
- Cache key generation strategies
- Cache statistics and monitoring
- Cache invalidation patterns
- Performance comparison (with/without cache)

**Run:** `crystal with_cache_demo.cr`

## 🚀 Getting Started

### Prerequisites

- Crystal 1.16.3+
- SQLite3 (for database examples)
- Redis (for Redis examples)

### Recommended Learning Path

#### 1. **Start with Configuration**

```bash
crystal cache_configuration_example.cr
```

Understand how to set up and configure caching.

#### 2. **Explore Advanced Patterns**

```bash
crystal advanced_caching_example.cr
```

Learn complex caching strategies and invalidation patterns.

#### 3. **ActiveRecord Integration**

```bash
crystal active_record_cache_demo.cr
```

See how caching integrates with your models.

#### 4. **Redis Backend**

```bash
# Start Redis first
redis-server

# Run Redis demo
crystal redis_cache_demo.cr
```

#### 5. **Web Application Patterns**

```bash
crystal per_request_query_cache_demo.cr
```

Learn request-scoped caching for web apps.

## 🎯 Key Concepts Demonstrated

### Enterprise-Grade Features

- **Multi-Backend Support** - Memory, Redis, and custom backends
- **Intelligent Invalidation** - Timestamp, version, and transaction-aware strategies
- **Tag-Based Organization** - Group and invalidate related cache entries
- **Fragment Caching** - Cache expensive computations and blocks
- **Performance Monitoring** - Real-time statistics and optimization insights
- **Thread Safety** - Concurrent access and request isolation

### Advanced Patterns

- **Cache-Aside Pattern** - Manual cache management with fallback to database
- **Write-Through Caching** - Automatic cache updates on data changes
- **Cache Warming** - Pre-populate cache with frequently accessed data
- **Circuit Breaker** - Fallback when cache is unavailable
- **Hierarchical Invalidation** - Cascade invalidation through related data

### Web Application Integration

- **Request-Scoped Caching** - Automatic query deduplication per request
- **Middleware Integration** - Seamless framework integration
- **Session Caching** - User session and authentication data
- **API Response Caching** - Cache expensive API responses

## 📊 Performance Benefits

### Typical Performance Improvements

- **Query Deduplication:** 2-10x faster response times
- **Fragment Caching:** 5-50x faster for expensive computations
- **Redis Backend:** Persistent caching across application restarts
- **Tag Invalidation:** Efficient cleanup of related data

### Monitoring and Optimization

- **Hit Rate Tracking** - Monitor cache effectiveness (aim for >80%)
- **Memory Usage** - Track cache memory consumption
- **Eviction Statistics** - Understand cache pressure
- **Query Pattern Analysis** - Identify optimization opportunities

## 🛠️ Production Deployment

### Configuration Best Practices

```crystal
# Development
CQL.configure do |c|
  c.cache.on = true
  c.cache.ttl = 15.minutes
  c.cache.memory_size = 1000
end

# Production
CQL.configure do |c|
  c.cache.on = true
  c.cache.ttl = 1.hour
  c.cache.memory_size = 10000
  # Use Redis for persistence
  config.cache.redis_url = ENV["REDIS_URL"]
end
```

### Monitoring in Production

- Set up alerts for low hit rates (<70%)
- Monitor memory usage and eviction rates
- Track slow query patterns
- Use Redis monitoring tools for persistent caches

## 🔗 Framework Integration

### Kemal Integration

```crystal
require "cql/cache/middleware"

# Add to your Kemal app
before_all do |env|
  CQL::Cache::Middleware::Kemal.before_request(env)
end

after_all do |env|
  CQL::Cache::Middleware::Kemal.after_request(env)
end
```

### Azu Framework

See `../framework-integration/azu_query_cache_demo.cr` for detailed Azu integration examples.

## 🧪 Testing Your Cache

### Cache Testing Strategies

- **Unit Tests** - Test cache behavior in isolation
- **Integration Tests** - Test cache with database operations
- **Performance Tests** - Benchmark cache effectiveness
- **Load Tests** - Verify cache under concurrent access

### Debugging Cache Issues

- Use `cache.stats` to check hit rates
- Monitor eviction patterns
- Check for cache key collisions
- Verify TTL settings

## 🔗 Next Steps

After mastering these caching examples:

- **[../performance/](../performance/)** - Performance monitoring and optimization
- **[../blog/](../blog/)** - See caching in a real application
- **[../framework-integration/](../framework-integration/)** - Web framework integration

---

**Ready to supercharge your application with enterprise-grade caching?** Start with cache configuration and work your way through the advanced patterns! 🚀
