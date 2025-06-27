require "../../src/cache/cache_interface"
require "../../src/cache/memory_cache"
require "../../src/cache/fragment_cache"
require "../../src/cache/invalidation_strategies"
require "db"
require "../utilities/beautify"

include Beautify

# Simple demonstration of CQL Advanced Caching features
# This version focuses on core caching without database dependencies

header("CQL Advanced Caching Demo")

# 1. Basic Memory Cache Operations
step(1, "Basic Memory Cache Operations")

cache = CQL::Cache::MemoryCache.new(max_size: 100)

# Basic set/get operations
cache.set("user:1", "John Doe")
cache.set("user:2", "Jane Smith", ttl: 2.seconds)
cache.set("user:3", "Bob Wilson")

success("Stored 3 users in cache")
database_operation("user:1", cache.get("user:1").to_s)
database_operation("user:2", cache.get("user:2").to_s)
database_operation("user:3", cache.get("user:3").to_s)

# TTL demonstration
sub_header("TTL Demonstration (waiting 3 seconds)")
sleep(3)
database_operation("user:1", "#{cache.get("user:1")} (no TTL - still cached)")
database_operation("user:2", "#{cache.get("user:2") || "❌ EXPIRED"} (had 2s TTL)")
database_operation("user:3", "#{cache.get("user:3")} (no TTL - still cached)")

# 2. Tag-based Cache Invalidation
step(2, "Tag-based Cache Invalidation")

cache.clear # Start fresh

# Set up tagged cache entries
cache.set("profile:john", "John's detailed profile")
cache.set("posts:john", "John's recent posts")
cache.set("friends:john", "John's friend list")
cache.set("profile:jane", "Jane's detailed profile")
cache.set("posts:jane", "Jane's recent posts")

# Tag the entries
cache.tag_cache("profile:john", ["user:john", "profile"])
cache.tag_cache("posts:john", ["user:john", "content"])
cache.tag_cache("friends:john", ["user:john", "social"])
cache.tag_cache("profile:jane", ["user:jane", "profile"])
cache.tag_cache("posts:jane", ["user:jane", "content"])

success("Cached 5 items with user-specific tags")
sub_header("Before invalidation")
bullet_point("John's profile: #{cache.get("profile:john") ? "✓ cached" : "❌ missing"}")
bullet_point("John's posts: #{cache.get("posts:john") ? "✓ cached" : "❌ missing"}")
bullet_point("John's friends: #{cache.get("friends:john") ? "✓ cached" : "❌ missing"}")
bullet_point("Jane's profile: #{cache.get("profile:jane") ? "✓ cached" : "❌ missing"}")
bullet_point("Jane's posts: #{cache.get("posts:jane") ? "✓ cached" : "❌ missing"}")

# Invalidate all of John's data
invalidated = cache.invalidate_tags(["user:john"])
status_indicator(:info, "Invalidated #{invalidated} entries for user:john")

sub_header("After invalidation")
bullet_point("John's profile: #{cache.get("profile:john") ? "✓ cached" : "❌ invalidated"}")
bullet_point("John's posts: #{cache.get("posts:john") ? "✓ cached" : "❌ invalidated"}")
bullet_point("John's friends: #{cache.get("friends:john") ? "✓ cached" : "❌ invalidated"}")
bullet_point("Jane's profile: #{cache.get("profile:jane") ? "✓ cached" : "❌ missing"}")
bullet_point("Jane's posts: #{cache.get("posts:jane") ? "✓ cached" : "❌ missing"}")

# 3. Fragment Caching with Performance Measurement
step(3, "Fragment Caching with Performance")

# Set up fragment cache
strategy = CQL::Cache::TimestampInvalidation.new(max_age: 1.hour)
config = CQL::Cache::CacheConfig.new(default_ttl: 30.minutes, key_prefix: "demo")
fragment_cache = CQL::Cache::FragmentCache.new(cache, strategy, config)

# Simulate expensive computation
def expensive_fibonacci(n : Int32) : Int64
  return n.to_i64 if n <= 1
  expensive_fibonacci(n - 1) + expensive_fibonacci(n - 2)
end

cache_key = "fibonacci"
params = {"n" => 35.as(DB::Any)} # This will be slow without caching

info("First call (computing fibonacci(35)):")
start_time = Time.monotonic
result1 = fragment_cache.cache_fragment(cache_key, params) do
  fib_result = expensive_fibonacci(35)
  "Fibonacci(35) = #{fib_result}"
end
first_time = Time.monotonic - start_time
database_operation("Result", result1)
performance("Time: #{execution_time(first_time)}")

info("Second call (cached):")
start_time = Time.monotonic
result2 = fragment_cache.cache_fragment(cache_key, params) do
  # This block shouldn't execute
  "This shouldn't run!"
end
second_time = Time.monotonic - start_time
database_operation("Result", result2)
performance("Time: #{execution_time(second_time)}")

speedup = first_time / second_time
performance("Speedup: #{speedup.round(0)}x faster!")

# 4. Version-based Invalidation
step(4, "Version-based Cache Invalidation")

version_strategy = CQL::Cache::VersionInvalidation.new
version_cache = CQL::Cache::FragmentCache.new(cache, version_strategy)

# Cache some user data
user_data_key = "user_settings"
initial_data = version_cache.cache_with_key(user_data_key) do
  "User settings: theme=dark, lang=en, notifications=on"
end
success("Cached initial user settings")
database_operation("Initial data", initial_data)

# Retrieve from cache (should be instant)
cached_data = version_cache.cache_with_key(user_data_key) do
  "This shouldn't execute"
end
info("Retrieved from cache: #{cached_data == initial_data ? "same data" : "different data"}")

# Simulate data change by incrementing version
new_version = version_strategy.increment_version(user_data_key)
status_indicator(:progress, "Simulated data change (version incremented to #{new_version})")

# Now cache should be invalidated
updated_data = version_cache.cache_with_key(user_data_key) do
  "User settings: theme=light, lang=es, notifications=off"
end
success("Cache was invalidated, new data retrieved:")
database_operation("Updated data", updated_data)

# 5. Transaction-aware Invalidation Demo
step(5, "Transaction-aware Invalidation")

# Set up transaction-aware invalidation
base_strategy = CQL::Cache::TimestampInvalidation.new
tx_strategy = CQL::Cache::TransactionAwareInvalidation.new(base_strategy)

# Cache some session data
cache.set("session:user123", "active_session_data")
cache.set("session:user456", "another_session_data")

success("Cached 2 user sessions")
sub_header("Before transaction")
bullet_point("Session 123: #{cache.get("session:user123") ? "✓ active" : "❌ missing"}")
bullet_point("Session 456: #{cache.get("session:user456") ? "✓ active" : "❌ missing"}")

# Simulate transaction that marks sessions for invalidation
status_indicator(:progress, "Starting transaction (marking sessions for invalidation)...")
tx_strategy.mark_for_invalidation(["session:user123", "session:user456"])

sub_header("During transaction (invalidation pending)")
bullet_point("Session 123: #{cache.get("session:user123") ? "✓ still active" : "❌ missing"}")
bullet_point("Session 456: #{cache.get("session:user456") ? "✓ still active" : "❌ missing"}")

# Simulate transaction commit
status_indicator(:success, "Transaction committed - executing pending invalidations...")
tx_strategy.execute_pending_invalidations(cache)

sub_header("After transaction commit")
bullet_point("Session 123: #{cache.get("session:user123") ? "✓ active" : "❌ invalidated"}")
bullet_point("Session 456: #{cache.get("session:user456") ? "✓ active" : "❌ invalidated"}")

# 6. Cache Key Building and Statistics
step(6, "Cache Key Building & Statistics")

key_builder = CQL::Cache::CacheKeyBuilder.new("myapp")

# Build some complex cache keys
user_profile_key = key_builder
  .add_component("user")
  .add_component("profile")
  .add_param("user_id", 12345.as(DB::Any))
  .add_param("include_posts", true.as(DB::Any))
  .build

user_stats_key = key_builder.reset
  .add_component("user")
  .add_component("analytics")
  .add_param("user_id", 12345.as(DB::Any))
  .add_param("period", "monthly".as(DB::Any))
  .build

success("Generated cache keys:")
bullet_point("Profile key: #{user_profile_key}")
bullet_point("Stats key: #{user_stats_key}")

# Use the keys for caching
cache.set(user_profile_key, "Complex user profile data with posts")
cache.set(user_stats_key, "Monthly analytics: views=1000, clicks=50")

# Generate some additional cache activity for statistics
20.times do |i|
  cache.set("temp_key_#{i}", "temporary_value_#{i}")
end

10.times do |i|
  cache.get("temp_key_#{i}")    # Hits
  cache.get("nonexistent_#{i}") # Misses
end

# Display comprehensive statistics
stats = cache.stats
configuration_block("Cache Performance Statistics", {
  "Type"            => stats["type"],
  "Current Size"    => "#{stats["size"]} entries",
  "Max Size"        => "#{stats["max_size"] == -1 ? "unlimited" : stats["max_size"]}",
  "Memory Usage"    => "#{stats["memory_usage_bytes"]} bytes",
  "Cache Hits"      => stats["hits"],
  "Cache Misses"    => stats["misses"],
  "Hit Rate"        => "#{stats["hit_rate_percent"].as(Float64).round(1)}%",
  "Total Sets"      => stats["sets"],
  "Total Deletes"   => stats["deletes"],
  "Evictions"       => stats["evictions"],
  "Active Tags"     => stats["tags_count"],
  "Version Entries" => stats["versions_count"],
})

# 7. LRU Eviction Demonstration
step(7, "LRU Eviction Demonstration")

small_cache = CQL::Cache::MemoryCache.new(max_size: 4)

# Fill cache to capacity
["alpha", "beta", "gamma", "delta"].each_with_index do |key, i|
  small_cache.set(key, "value_#{i + 1}")
end

success("Filled cache to capacity (4/4 entries):")
["alpha", "beta", "gamma", "delta"].each do |key|
  bullet_point("#{key}: #{small_cache.get(key) ? "✓ cached" : "❌ missing"}")
end

# Access some entries to change LRU order
small_cache.get("alpha") # Make alpha recently used
small_cache.get("gamma") # Make gamma recently used

status_indicator(:progress, "Accessed 'alpha' and 'gamma' (making them recently used)")

# Add new entry - should evict least recently used
small_cache.set("epsilon", "value_5")
status_indicator(:info, "Added 'epsilon' (should trigger LRU eviction)")

sub_header("After LRU eviction")
["alpha", "beta", "gamma", "delta", "epsilon"].each do |key|
  status = small_cache.get(key) ? "✓ cached" : "❌ evicted"
  bullet_point("#{key}: #{status}")
end

eviction_stats = small_cache.stats
configuration_block("Eviction Statistics", {
  "Final Size"      => eviction_stats["size"],
  "Total Evictions" => eviction_stats["evictions"],
})

demo_complete("Advanced Caching Demo")

feature_list("Key Features Demonstrated", [
  "Basic cache operations with TTL support",
  "Tag-based cache invalidation",
  "High-performance fragment caching",
  "Version-based cache invalidation",
  "Transaction-aware invalidation",
  "Custom cache key building",
  "LRU eviction with size limits",
  "Comprehensive cache statistics",
])

summary_box("Enterprise-Grade Caching", [
  "This caching system provides enterprise-grade",
  "performance and consistency for Crystal applications! 🚀",
])
