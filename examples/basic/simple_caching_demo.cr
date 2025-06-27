require "../../src/cache/cache_interface"
require "../../src/cache/memory_cache"
require "../../src/cache/fragment_cache"
require "../../src/cache/invalidation_strategies"

# Simple demonstration of CQL Advanced Caching features
# Run with: crystal examples/simple_caching_demo.cr

puts "=== CQL Advanced Caching Demo ==="
puts

# 1. Basic Memory Cache
puts "1. Basic Memory Cache Operations"
puts "-------------------------------"

cache = CQL::Cache::MemoryCache.new(max_size: 100)

# Basic operations
cache.set("user:1", "John Doe")
cache.set("user:2", "Jane Smith", ttl: 2.seconds)

puts "user:1 = #{cache.get("user:1")}"
puts "user:2 = #{cache.get("user:2")}"

# TTL demonstration
puts "Waiting 3 seconds for user:2 to expire..."
sleep(3)
puts "user:1 = #{cache.get("user:1")} (no TTL)"
puts "user:2 = #{cache.get("user:2") || "EXPIRED"} (had TTL)"

puts

# 2. Tag-based Invalidation
puts "2. Tag-based Cache Invalidation"
puts "------------------------------"

cache.clear

# Set up tagged cache entries
cache.set("profile:1", "John's Profile")
cache.set("posts:1", "John's Posts")
cache.set("profile:2", "Jane's Profile")

# Tag them
cache.tag_cache("profile:1", ["user:1", "profile"])
cache.tag_cache("posts:1", ["user:1", "posts"])
cache.tag_cache("profile:2", ["user:2", "profile"])

puts "Before invalidation:"
puts "  profile:1 = #{cache.get("profile:1")}"
puts "  posts:1 = #{cache.get("posts:1")}"
puts "  profile:2 = #{cache.get("profile:2")}"

# Invalidate all data for user:1
invalidated = cache.invalidate_tags(["user:1"])
puts "\nInvalidated #{invalidated} entries for user:1"

puts "\nAfter invalidation:"
puts "  profile:1 = #{cache.get("profile:1") || "INVALIDATED"}"
puts "  posts:1 = #{cache.get("posts:1") || "INVALIDATED"}"
puts "  profile:2 = #{cache.get("profile:2")} (untouched)"

puts

# 3. Fragment Caching with Custom Keys
puts "3. Fragment Caching"
puts "------------------"

# Set up fragment cache
strategy = CQL::Cache::TimestampInvalidation.new(max_age: 1.hour)
config = CQL::Cache::CacheConfig.new(default_ttl: 30.minutes, key_prefix: "demo")
fragment_cache = CQL::Cache::FragmentCache.new(cache, strategy, config)

# Cache expensive computation
cache_key = "expensive_computation"
params = {"iterations" => 1000.as(DB::Any)}

puts "First call (expensive):"
start_time = Time.monotonic
result1 = fragment_cache.cache_fragment(cache_key, params) do
  puts "  Computing..."
  sleep(0.1) # Simulate expensive operation
  sum = (1..1000).sum
  "Result: #{sum}"
end
first_time = Time.monotonic - start_time
puts "  #{result1} (took #{(first_time.total_milliseconds).round(1)}ms)"

puts "\nSecond call (cached):"
start_time = Time.monotonic
result2 = fragment_cache.cache_fragment(cache_key, params) do
  puts "  This shouldn't execute!"
  "Different result"
end
second_time = Time.monotonic - start_time
puts "  #{result2} (took #{(second_time.total_milliseconds).round(1)}ms)"

speedup = first_time / second_time
puts "  Speedup: #{speedup.round(1)}x faster"

puts

# 4. Version-based Invalidation
puts "4. Version-based Invalidation"
puts "----------------------------"

version_strategy = CQL::Cache::VersionInvalidation.new
version_cache = CQL::Cache::FragmentCache.new(cache, version_strategy)

# Cache some data
version_cache.cache_with_key("user_data") do
  "Version 1 of user data"
end

puts "Initial data: #{version_cache.cache_with_key("user_data") { "This won't execute" }}"

# Simulate data change by incrementing version
new_version = version_strategy.increment_version("user_data")
puts "Incremented version to: #{new_version}"

# Cache should be invalidated now
puts "After version increment: #{version_cache.cache_with_key("user_data") { "Version 2 of user data" }}"

puts

# 5. Transaction-aware Invalidation
puts "5. Transaction-aware Invalidation"
puts "--------------------------------"

# Set up transaction-aware invalidation
base_strategy = CQL::Cache::TimestampInvalidation.new
tx_strategy = CQL::Cache::TransactionAwareInvalidation.new(base_strategy)

# Cache some values
cache.set("tx_key1", "Value 1")
cache.set("tx_key2", "Value 2")

puts "Before transaction:"
puts "  tx_key1 = #{cache.get("tx_key1")}"
puts "  tx_key2 = #{cache.get("tx_key2")}"

# Mark for invalidation (simulating transaction)
tx_strategy.mark_for_invalidation(["tx_key1", "tx_key2"])
puts "\nMarked keys for invalidation (transaction in progress)"

puts "During transaction (not yet invalidated):"
puts "  tx_key1 = #{cache.get("tx_key1")}"
puts "  tx_key2 = #{cache.get("tx_key2")}"

# Simulate transaction commit
tx_strategy.execute_pending_invalidations(cache)
puts "\nTransaction committed - invalidations executed"

puts "After transaction commit:"
puts "  tx_key1 = #{cache.get("tx_key1") || "INVALIDATED"}"
puts "  tx_key2 = #{cache.get("tx_key2") || "INVALIDATED"}"

puts

# 6. Cache Statistics and Performance
puts "6. Cache Statistics"
puts "------------------"

# Generate some activity
50.times do |i|
  cache.set("stat_key_#{i}", "value_#{i}")
end

# Generate hits and misses
25.times do |i|
  cache.get("stat_key_#{i}") # Hit
  cache.get("missing_#{i}")  # Miss
end

stats = cache.stats
puts "Cache Performance:"
puts "  Type: #{stats["type"]}"
puts "  Size: #{stats["size"]}"
puts "  Hits: #{stats["hits"]}"
puts "  Misses: #{stats["misses"]}"
puts "  Hit Rate: #{stats["hit_rate_percent"].as(Float64).round(1)}%"
puts "  Memory Usage: #{stats["memory_usage_bytes"]} bytes"

puts

# 7. Custom Cache Key Building
puts "7. Custom Cache Key Building"
puts "---------------------------"

key_builder = CQL::Cache::CacheKeyBuilder.new("app")

# Build hierarchical keys
user_key = key_builder
  .add_component("user")
  .add_param("id", 123.as(DB::Any))
  .add_param("action", "profile".as(DB::Any))
  .build

posts_key = key_builder.reset
  .add_component("posts")
  .add_param("user_id", 123.as(DB::Any))
  .add_param("limit", 10.as(DB::Any))
  .build

puts "Generated keys:"
puts "  User profile: #{user_key}"
puts "  User posts: #{posts_key}"

# Use the keys for caching
cache.set(user_key, "User 123 Profile Data")
cache.set(posts_key, "User 123 Posts Data")

puts "\nRetrieved data:"
puts "  Profile: #{cache.get(user_key)}"
puts "  Posts: #{cache.get(posts_key)}"

puts
puts "=== Demo completed successfully! ==="

# 8. LRU Eviction Demo
puts
puts "8. LRU Eviction Demo"
puts "-------------------"

small_cache = CQL::Cache::MemoryCache.new(max_size: 3)

# Fill cache to capacity
small_cache.set("a", "value_a")
small_cache.set("b", "value_b")
small_cache.set("c", "value_c")

puts "Cache filled to capacity (3/3):"
puts "  a = #{small_cache.get("a")}"
puts "  b = #{small_cache.get("b")}"
puts "  c = #{small_cache.get("c")}"

# Access 'a' to make it recently used
small_cache.get("a")

# Add new item - should evict 'b' (least recently used)
small_cache.set("d", "value_d")

puts "\nAfter adding 'd' (should evict 'b'):"
puts "  a = #{small_cache.get("a") || "EVICTED"} (recently accessed)"
puts "  b = #{small_cache.get("b") || "EVICTED"} (least recently used)"
puts "  c = #{small_cache.get("c") || "EVICTED"}"
puts "  d = #{small_cache.get("d") || "EVICTED"} (new entry)"

final_stats = small_cache.stats
puts "\nFinal cache stats:"
puts "  Size: #{final_stats["size"]}"
puts "  Evictions: #{final_stats["evictions"]}"
