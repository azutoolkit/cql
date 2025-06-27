require "../../src/cql"

# Redis Cache Demo for CQL
# This example demonstrates how to configure and use Redis as the cache backend

puts "=== CQL Redis Cache Configuration Demo ==="

# Method 1: Configure using environment variables
puts "\n1. Configuring cache from environment variables:"
ENV["CQL_CACHE_TYPE"] = "redis"
ENV["CQL_REDIS_URL"] = "redis://localhost:6379/1"
ENV["CQL_CACHE_PREFIX"] = "myapp"
ENV["CQL_CACHE_TTL"] = "3600" # 1 hour in seconds

CQL::Cache::Cache.configure_from_env
puts "✓ Cache configured from environment variables"

# Test basic operations
puts "\n2. Testing basic cache operations:"
cache = CQL::Cache::Cache

# Store some data
cache.set("user:1", ["John", "Doe", 25])
cache.set("user:2", ["Jane", "Smith", 30])

# Retrieve data
user1 = cache.get("user:1")
puts "✓ Retrieved user:1: #{user1}"

# Check if key exists
exists = cache.has_key?("user:1")
puts "✓ Key 'user:1' exists: #{exists}"

# Method 2: Programmatic configuration
puts "\n3. Programmatic cache configuration:"
config = CQL::Cache::CacheStoreConfig.new(
  type: CQL::Cache::CacheStoreType::Redis,
  redis_url: "redis://localhost:6379/2",
  key_prefix: "demo",
  default_ttl: 30.minutes,
  redis_pool_size: 10
)

CQL::Cache::Cache.configure(config)
puts "✓ Cache reconfigured programmatically"

# Test with new configuration
cache.set("product:1", ["Laptop", 999.99, "Electronics"])
product = cache.get("product:1")
puts "✓ Retrieved product:1: #{product}"

# Method 3: Using CacheStore factory directly
puts "\n4. Using CacheStore factory:"

# Create a Redis cache instance
redis_cache = CQL::Cache::CacheStore.create("redis",
  redis_url: "redis://localhost:6379/3",
  key_prefix: "direct"
)

# Use the cache instance directly
redis_cache.set("session:abc123", "user_data_here", 15.minutes)
session_data = redis_cache.get("session:abc123")
puts "✓ Session data: #{session_data}"

# Test batch operations
puts "\n5. Testing batch operations:"
data = {
  "batch:1" => "value1",
  "batch:2" => "value2",
  "batch:3" => "value3",
}

redis_cache.set_multi(data, 10.minutes)
retrieved = redis_cache.get_multi(["batch:1", "batch:2", "batch:3"])
puts "✓ Batch retrieved: #{retrieved}"

# Test tag-based invalidation
puts "\n6. Testing tag-based cache invalidation:"
redis_cache.set("tagged:1", "data1")
redis_cache.set("tagged:2", "data2")
redis_cache.set("tagged:3", "data3")

# Tag the cache entries
redis_cache.tag_cache("tagged:1", ["user", "profile"])
redis_cache.tag_cache("tagged:2", ["user", "settings"])
redis_cache.tag_cache("tagged:3", ["admin", "settings"])

puts "✓ Tagged cache entries created"

# Invalidate by tag
invalidated = redis_cache.invalidate_tags(["user"])
puts "✓ Invalidated #{invalidated} entries with 'user' tag"

# Check what's left
remaining1 = redis_cache.exists?("tagged:1")
remaining2 = redis_cache.exists?("tagged:2")
remaining3 = redis_cache.exists?("tagged:3")
puts "  tagged:1 exists: #{remaining1}"
puts "  tagged:2 exists: #{remaining2}"
puts "  tagged:3 exists: #{remaining3}"

# Method 4: Using GlobalCache convenience methods
puts "\n7. Using GlobalCache convenience methods:"

# Configure the global cache
global_config = CQL::Cache::CacheStoreConfig.new(
  type: CQL::Cache::CacheStoreType::Redis,
  redis_url: "redis://localhost:6379/4",
  key_prefix: "global"
)
CQL::Cache::CacheStore.configure(global_config)

# Use convenience methods
CQL::Cache::GlobalCache.set("config:theme", "dark")
theme = CQL::Cache::GlobalCache.get("config:theme", String)
puts "✓ Theme setting: #{theme}"

# Cache with block
expensive_calculation = CQL::Cache::GlobalCache.cache("calculation:pi", 1.hour) do
  puts "  Performing expensive calculation..."
  Math::PI.to_s
end
puts "✓ Cached calculation result: #{expensive_calculation}"

# Second call should hit cache
cached_result = CQL::Cache::GlobalCache.cache("calculation:pi", 1.hour) do
  puts "  This shouldn't print - should hit cache"
  "not calculated"
end
puts "✓ Second call result (from cache): #{cached_result}"

# Method 5: Comparing Memory vs Redis performance
puts "\n8. Performance comparison:"

# Test with memory cache
memory_config = CQL::Cache::CacheStoreConfig.new(
  type: CQL::Cache::CacheStoreType::Memory,
  memory_max_size: 1000
)
memory_cache = CQL::Cache::CacheStore.create(memory_config)

# Test with Redis cache
redis_config = CQL::Cache::CacheStoreConfig.new(
  type: CQL::Cache::CacheStoreType::Redis,
  redis_url: "redis://localhost:6379/5"
)
redis_cache = CQL::Cache::CacheStore.create(redis_config)

# Benchmark both
operations = 100
test_data = "x" * 1000 # 1KB of data

puts "  Testing #{operations} operations with 1KB data..."

# Memory cache test
memory_start = Time.monotonic
operations.times do |i|
  memory_cache.set("test:#{i}", test_data)
  memory_cache.get("test:#{i}")
end
memory_time = Time.monotonic - memory_start

# Redis cache test
redis_start = Time.monotonic
operations.times do |i|
  redis_cache.set("test:#{i}", test_data)
  redis_cache.get("test:#{i}")
end
redis_time = Time.monotonic - redis_start

puts "  Memory cache: #{memory_time.total_milliseconds.round(2)}ms"
puts "  Redis cache: #{redis_time.total_milliseconds.round(2)}ms"

# Show statistics
puts "\n9. Cache statistics:"
memory_stats = memory_cache.stats
redis_stats = redis_cache.stats

puts "Memory Cache Stats:"
memory_stats.each { |k, v| puts "  #{k}: #{v}" }

puts "\nRedis Cache Stats:"
redis_stats.each { |k, v| puts "  #{k}: #{v}" }

# Test Redis-specific features
puts "\n10. Redis-specific features:"
begin
  if redis_cache.responds_to?(:ping)
    ping_result = redis_cache.as(CQL::Cache::RedisCache).ping
    puts "✓ Redis ping: #{ping_result}"
  end

  if redis_cache.responds_to?(:connection_info)
    connection_info = redis_cache.as(CQL::Cache::RedisCache).connection_info
    puts "✓ Redis connection info available: #{!connection_info.empty?}"
  end
rescue
  puts "✓ Redis-specific features not available for this cache type"
end

# Clean up
puts "\n11. Cleaning up:"
memory_cache.clear
redis_cache.clear
puts "✓ All caches cleared"

puts "\n=== Demo completed successfully! ==="
puts "\nTips for production use:"
puts "- Set CQL_CACHE_TYPE=redis in production"
puts "- Use REDIS_URL environment variable for connection"
puts "- Configure appropriate TTL values for your use case"
puts "- Monitor cache hit rates and memory usage"
puts "- Use tag-based invalidation for complex cache patterns"
