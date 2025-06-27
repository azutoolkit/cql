# Basic CQL Examples

Welcome to the basic CQL examples! These simple, focused examples are perfect for getting started with CQL's caching system. Each example demonstrates core concepts without complex dependencies.

## 📝 Examples Overview

### 🎯 **simple_cache_demo.cr**

**Purpose:** Comprehensive demonstration of CQL's advanced caching features
**Features:**

- Basic memory cache operations (set/get/delete/exists)
- TTL (Time To Live) demonstration
- Tag-based cache invalidation
- Fragment caching with performance measurement
- Version-based invalidation
- Transaction-aware invalidation
- LRU eviction policies
- Cache statistics and performance monitoring

**Run:** `crystal simple_cache_demo.cr`

### 🔧 **simple_caching_demo.cr**

**Purpose:** Focused demonstration of core caching concepts
**Features:**

- Memory cache basics
- Tag-based invalidation patterns
- Fragment caching with custom keys
- Version and transaction-aware invalidation
- Cache key building
- Performance statistics

**Run:** `crystal simple_caching_demo.cr`

### 🔴 **simple_redis_demo.cr**

**Purpose:** Basic Redis cache integration
**Features:**

- Environment-based Redis configuration
- Basic Redis operations
- Cache with block execution
- Memory vs Redis performance comparison
- Batch operations
- Cache statistics

**Run:** `crystal simple_redis_demo.cr`
**Prerequisites:** Redis server running on localhost:6379

## 🚀 Getting Started

### 1. Start with the Basic Cache Demo

```bash
crystal simple_cache_demo.cr
```

This provides a comprehensive overview of all caching features.

### 2. Explore Specific Concepts

```bash
crystal simple_caching_demo.cr
```

Focuses on core caching patterns and strategies.

### 3. Try Redis Integration

```bash
# Start Redis server first
redis-server

# Then run the Redis demo
crystal simple_redis_demo.cr
```

## 🎓 Learning Path

### Beginners

1. **simple_cache_demo.cr** - Start here for a complete overview
2. **simple_caching_demo.cr** - Dive deeper into specific patterns
3. **simple_redis_demo.cr** - Learn Redis integration

### Key Concepts Covered

- **Memory Caching** - In-memory storage for fast access
- **TTL Management** - Automatic expiration of cached data
- **Tag-based Invalidation** - Group and invalidate related cache entries
- **Fragment Caching** - Cache expensive computations and blocks
- **LRU Eviction** - Automatic cleanup when cache is full
- **Performance Monitoring** - Track cache hit rates and efficiency

## 💡 Tips for Beginners

1. **Start Simple:** Run `simple_cache_demo.cr` first to see all features in action
2. **Read the Output:** Each example provides detailed console output explaining what's happening
3. **Modify and Experiment:** Try changing cache sizes, TTL values, and see the effects
4. **Check Statistics:** Pay attention to cache hit rates and performance metrics

## 🔗 Next Steps

After mastering these basic examples, explore:

- **[../caching/](../caching/)** - Advanced caching patterns and strategies
- **[../blog/](../blog/)** - Real-world application with caching integration
- **[../performance/](../performance/)** - Performance monitoring and optimization

## 🛠️ Troubleshooting

### Common Issues

**Redis Connection Errors:**

```bash
# Make sure Redis is running
redis-server

# Test Redis connection
redis-cli ping
```

**Missing Dependencies:**

```bash
# Install required shards
shards install
```

**Performance Issues:**

- Check your system's available memory
- Monitor cache hit rates (aim for >80%)
- Adjust cache sizes based on your application needs

---

**Ready to dive into CQL caching?** Start with `simple_cache_demo.cr` and work your way through each example! 🚀
