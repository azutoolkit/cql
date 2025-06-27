require "../../src/cql"

# Simple Redis Cache Demo for CQL
puts "=== Simple Redis Cache Demo ==="

# Configure using environment variables
puts "\n1. Configuring Redis cache:"
ENV["CQL_CACHE_TYPE"] = "redis"
ENV["CQL_REDIS_URL"] = "redis://localhost:6379/1"
ENV["CQL_CACHE_PREFIX"] = "simple_demo"

CQL::Cache::Cache.configure_from_env
puts "✓ Redis cache configured"

# Test basic operations using string values only
puts "\n2. Testing basic cache operations:"

# Store simple string data
puts "Setting values..."
CQL::Cache::GlobalCache.set("user:name", "John Doe")
CQL::Cache::GlobalCache.set("user:email", "john@example.com")
CQL::Cache::GlobalCache.set("config:theme", "dark")

# Retrieve data
puts "Getting values..."
name = CQL::Cache::GlobalCache.get("user:name", String)
email = CQL::Cache::GlobalCache.get("user:email", String)
theme = CQL::Cache::GlobalCache.get("config:theme", String)

puts "✓ Name: #{name}"
puts "✓ Email: #{email}"
puts "✓ Theme: #{theme}"

# Test cache with block execution
puts "\n3. Testing cache with block execution:"
result = CQL::Cache::GlobalCache.cache("expensive_calculation", 1.hour) do
  puts "  Executing expensive operation..."
  "calculated_result_#{Time.utc.to_unix}"
end
puts "✓ First calculation: #{result}"

# Second call should hit cache
cached_result = CQL::Cache::GlobalCache.cache("expensive_calculation", 1.hour) do
  puts "  This should not print - hitting cache"
  "new_calculation"
end
puts "✓ Cached result (should be same): #{cached_result}"

# Test exists and delete
puts "\n4. Testing exists and delete:"
exists_before = CQL::Cache::GlobalCache.exists?("user:name")
puts "✓ 'user:name' exists before delete: #{exists_before}"

deleted = CQL::Cache::GlobalCache.delete("user:name")
puts "✓ Delete operation successful: #{deleted}"

exists_after = CQL::Cache::GlobalCache.exists?("user:name")
puts "✓ 'user:name' exists after delete: #{exists_after}"

# Show cache statistics
puts "\n5. Cache statistics:"
stats = CQL::Cache::GlobalCache.stats
puts "✓ Cache type: #{stats["type"]? || "unknown"}"
puts "✓ Cache size: #{CQL::Cache::GlobalCache.size} entries"
puts "✓ Hit rate: #{stats["hit_rate_percent"]? || 0}%"

# Test memory vs redis comparison
puts "\n6. Comparing cache types:"

# Create memory cache
memory_cache = CQL::Cache::CacheStore.create("memory", max_size: 100)
memory_cache.set("test:memory", "memory_value")
memory_result = memory_cache.get("test:memory")
puts "✓ Memory cache result: #{memory_result}"

# Create redis cache
redis_cache = CQL::Cache::CacheStore.create("redis",
  redis_url: "redis://localhost:6379/2",
  key_prefix: "test")
redis_cache.set("test:redis", "redis_value")
redis_result = redis_cache.get("test:redis")
puts "✓ Redis cache result: #{redis_result}"

# Test batch operations
puts "\n7. Testing batch operations:"
batch_data = {
  "batch:1" => "value1",
  "batch:2" => "value2",
  "batch:3" => "value3",
}

success = redis_cache.set_multi(batch_data)
puts "✓ Batch set successful: #{success}"

retrieved = redis_cache.get_multi(["batch:1", "batch:2", "batch:3"])
puts "✓ Batch get results:"
retrieved.each { |k, v| puts "  #{k}: #{v}" }

# Clean up
puts "\n8. Cleaning up:"
CQL::Cache::GlobalCache.clear
memory_cache.clear
redis_cache.clear
puts "✓ All caches cleared"

puts "\n=== Simple demo completed successfully! ==="
puts "\nKey features demonstrated:"
puts "- Environment-based configuration"
puts "- Basic cache operations (get/set/delete/exists)"
puts "- Cache with block execution and automatic invalidation"
puts "- Memory vs Redis cache comparison"
puts "- Batch operations"
puts "- Cache statistics"
