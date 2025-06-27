require "../../src/cql"
require "../../src/cache/fragment_cache"
require "../../src/cache/invalidation_strategies"
require "../../src/cache/memory_cache"
require "../utilities/beautify"

include Beautify

# Database schema for examples
CacheExampleDB = CQL::Schema.define(
  :cache_example,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://examples/cache_example.db") do
  table :users do
    primary :id, Int32
    text :name
    text :email
    integer :age, null: true
    timestamps
  end

  table :posts do
    primary :id, Int32
    text :title
    text :content
    bigint :user_id
    integer :view_count, default: "0"
    timestamps
    foreign_key [:user_id], references: :users, references_columns: [:id], on_delete: :no_action, on_update: :no_action
  end
end

# User model (simplified for caching demo)
class User
  include CQL::ActiveRecord::Model(Int32)

  db_context CacheExampleDB, :users

  property id : Int32?
  property name : String
  property email : String
  property age : Int32?
  property created_at : Time?
  property updated_at : Time?

  def initialize(@name : String, @email : String, @age : Int32? = nil)
  end
end

# Post model (simplified for caching demo)
class Post
  include CQL::ActiveRecord::Model(Int32)

  db_context CacheExampleDB, :posts

  property id : Int32?
  property title : String
  property content : String
  property user_id : Int32
  property view_count : Int32 = 0
  property created_at : Time?
  property updated_at : Time?

  def initialize(@title : String, @content : String, @user_id : Int32)
  end
end

# Example demonstrating advanced caching features
class AdvancedCachingDemo
  def self.run
    # Initialize database
    CacheExampleDB.build

    # Set up caching for models
    setup_caching

    header("Advanced Caching Demo")

    # Demo 1: Basic fragment caching
    demo_fragment_caching

    # Demo 2: Timestamp-based invalidation
    demo_timestamp_invalidation

    # Demo 3: Version-based invalidation
    demo_version_invalidation

    # Demo 4: Transaction-aware invalidation
    demo_transaction_aware_invalidation

    # Demo 5: Tag-based invalidation
    demo_tag_based_invalidation

    # Demo 6: Complex query caching
    demo_complex_query_caching

    # Demo 8: Cache performance monitoring
    demo_cache_performance

    demo_complete("Advanced Caching Demo")
  end

  private def self.setup_caching
    section("Setting up Caching Systems")

    # Create cache backends
    memory_cache = CQL::Cache::MemoryCache.new(max_size: 1000)

    # Create invalidation strategies
    timestamp_strategy = CQL::Cache::TimestampInvalidation.new(max_age: 1.hour)
    version_strategy = CQL::Cache::VersionInvalidation.new

    success("Caching systems configured")
    configuration_block("Cache Configuration", {
      "Memory Cache"       => "Max 1000 entries",
      "Timestamp Strategy" => "1 hour max age",
      "Version Strategy"   => "Manual version control",
      "Max Size"           => "1000 entries",
    })
  end

  private def self.demo_fragment_caching
    step(1, "Fragment Caching")

    # Create fragment cache
    cache = CQL::Cache::MemoryCache.new
    strategy = CQL::Cache::TimestampInvalidation.new(max_age: 1.hour)
    fragment_cache = CQL::Cache::FragmentCache.new(cache, strategy)

    # Cache expensive computation
    cache_key = "expensive_computation"
    params = {"iterations" => 1000_i32.as(DB::Any)}
    tags = ["computation", "math"]

    info("Performing expensive computation (first call)...")
    start_time = Time.monotonic
    result = fragment_cache.cache_fragment(cache_key, params, tags) do
      sleep(0.1) # Simulate expensive operation
      sum = (1..1000).sum
      "Result: #{sum}"
    end
    first_call_time = Time.monotonic - start_time

    database_operation("First call result", result)
    performance("First call time: #{execution_time(first_call_time)}")

    # Second call should be cached
    start_time = Time.monotonic
    cached_result = fragment_cache.cache_fragment(cache_key, params, tags) do
      "This shouldn't execute"
    end
    second_call_time = Time.monotonic - start_time

    database_operation("Second call result", cached_result)
    performance("Second call time: #{execution_time(second_call_time)} (cached)")

    # Test cache invalidation by tags
    invalidated_count = fragment_cache.invalidate_tags(["computation"])
    status_indicator(:success, "Invalidated #{invalidated_count} cache entries by tag")
  end

  private def self.demo_timestamp_invalidation
    step(2, "Timestamp-based Invalidation")

    cache = CQL::Cache::MemoryCache.new
    strategy = CQL::Cache::TimestampInvalidation.new(max_age: 2.seconds)
    fragment_cache = CQL::Cache::FragmentCache.new(cache, strategy)

    # Cache a value
    cache_key = "timestamp_test"
    result1 = fragment_cache.cache_with_key(cache_key) do
      "Cached at #{Time.utc}"
    end
    database_operation("Cached value", result1)

    # Immediately try to get it (should be cached)
    result2 = fragment_cache.cache_with_key(cache_key) do
      "New value at #{Time.utc}"
    end
    database_operation("Immediate retrieval", result2)

    # Wait for cache to expire
    info("Waiting 3 seconds for cache to expire...")
    sleep(3)

    # Try again (should generate new value)
    result3 = fragment_cache.cache_with_key(cache_key) do
      "New value at #{Time.utc}"
    end
    database_operation("After expiration", result3)
  end

  private def self.demo_version_invalidation
    step(3, "Version-based Invalidation")

    cache = CQL::Cache::MemoryCache.new
    strategy = CQL::Cache::VersionInvalidation.new
    fragment_cache = CQL::Cache::FragmentCache.new(cache, strategy)

    cache_key = "version_test"

    # Cache initial value
    result1 = fragment_cache.cache_with_key(cache_key) do
      "Version 1 data"
    end
    database_operation("Initial cache", result1)

    # Increment version (simulating data change)
    new_version = strategy.increment_version(cache_key)
    status_indicator(:info, "Incremented version to: #{new_version}")

    # Try to get cached value (should be invalidated due to version mismatch)
    result2 = fragment_cache.cache_with_key(cache_key) do
      "Version 2 data"
    end
    database_operation("After version increment", result2)
  end

  private def self.demo_transaction_aware_invalidation
    step(4, "Transaction-aware Invalidation")

    cache = CQL::Cache::MemoryCache.new
    base_strategy = CQL::Cache::TimestampInvalidation.new
    tx_strategy = CQL::Cache::TransactionAwareInvalidation.new(base_strategy)

    # Cache some values
    cache.set("user:1", "John Doe")
    cache.set("user:2", "Jane Smith")
    success("Cached user data")

    # Mark for invalidation (would happen during transaction)
    tx_strategy.mark_for_invalidation(["user:1", "user:2"])
    status_indicator(:progress, "Marked cache entries for invalidation")

    # Values should still be available (not yet invalidated)
    database_operation("user:1 still cached", cache.get("user:1").to_s)
    database_operation("user:2 still cached", cache.get("user:2").to_s)

    # Simulate transaction commit
    tx_strategy.execute_pending_invalidations(cache)
    status_indicator(:success, "Executed pending invalidations (transaction committed)")

    # Values should now be invalidated
    database_operation("user:1 after commit", cache.get("user:1") || "INVALIDATED")
    database_operation("user:2 after commit", cache.get("user:2") || "INVALIDATED")
  end

  private def self.demo_tag_based_invalidation
    step(5, "Tag-based Invalidation")

    cache = CQL::Cache::MemoryCache.new
    strategy = CQL::Cache::TimestampInvalidation.new
    fragment_cache = CQL::Cache::FragmentCache.new(cache, strategy)

    # Cache multiple related fragments
    fragments = [
      {key: "user_profile:1", tags: ["user:1", "profile"], data: "User 1 Profile"},
      {key: "user_posts:1", tags: ["user:1", "posts"], data: "User 1 Posts"},
      {key: "user_profile:2", tags: ["user:2", "profile"], data: "User 2 Profile"},
      {key: "user_posts:2", tags: ["user:2", "posts"], data: "User 2 Posts"},
    ]

    fragments.each do |fragment|
      fragment_cache.cache_with_key(fragment[:key], fragment[:tags]) do
        fragment[:data]
      end
    end

    success("Cached #{fragments.size} fragments with tags")

    # Invalidate all data for user:1
    invalidated = fragment_cache.invalidate_tags(["user:1"])
    status_indicator(:info, "Invalidated #{invalidated} entries for user:1")

    # Check what remains
    fragments.each do |fragment|
      cached = fragment_cache.cache_with_key(fragment[:key]) { "REGENERATED: #{fragment[:data]}" }
      status = cached.starts_with?("REGENERATED") ? "invalidated" : "cached"
      bullet_point("#{fragment[:key]}: #{status}")
    end
  end

  private def self.demo_complex_query_caching
    step(6, "Complex Query Caching")

    # Test query caching with custom key builder
    cache = CQL::Cache::MemoryCache.new
    key_builder = CQL::Cache::CacheKeyBuilder.new("custom")

    complex_key = key_builder
      .add_component("complex_query")
      .add_param("user_id", 123.as(DB::Any))
      .add_param("limit", 10.as(DB::Any))
      .build

    posts_key = key_builder.reset
      .add_component("posts")
      .add_param("category", "tech".as(DB::Any))
      .add_param("published", true.as(DB::Any))
      .build

    info("Generated cache keys:")
    bullet_point("Complex query key: #{complex_key}")
    bullet_point("Posts query key: #{posts_key}")

    # Use the keys for caching
    cache.set(complex_key, "Complex query result data")
    cache.set(posts_key, "Published tech posts")

    database_operation("Complex query", cache.get(complex_key).to_s)
    database_operation("Posts query", cache.get(posts_key).to_s)
  end

  private def self.demo_cache_performance
    step(7, "Cache Performance Monitoring")

    cache = CQL::Cache::MemoryCache.new(max_size: 100)

    # Generate some cache activity
    100.times do |i|
      cache.set("key_#{i}", "value_#{i}")
    end

    # Generate some hits and misses
    50.times do |i|
      cache.get("key_#{i}")         # Hit
      cache.get("nonexistent_#{i}") # Miss
    end

    # Add some tags and test tag invalidation
    25.times do |i|
      cache.tag_cache("key_#{i}", ["group_a"])
    end

    25.times do |i|
      cache.tag_cache("key_#{i + 25}", ["group_b"])
    end

    # Invalidate group_a
    invalidated = cache.invalidate_tags(["group_a"])

    # Display comprehensive statistics
    stats = cache.stats
    configuration_block("Cache Statistics", {
      "Type"         => stats["type"],
      "Size"         => "#{stats["size"]}/#{stats["max_size"]}",
      "Memory usage" => "#{stats["memory_usage_bytes"]} bytes",
      "Hits"         => "#{stats["hits"]} (#{stats["hit_rate_percent"]}%)",
      "Misses"       => stats["misses"],
      "Sets"         => stats["sets"],
      "Deletes"      => stats["deletes"],
      "Evictions"    => stats["evictions"],
      "Tags"         => stats["tags_count"],
      "Versions"     => stats["versions_count"],
    })

    status_indicator(:info, "Tag invalidation removed #{invalidated} entries")

    # Test LRU eviction
    info("Testing LRU eviction by adding more entries...")
    50.times do |i|
      cache.set("overflow_#{i}", "overflow_value_#{i}")
    end

    final_stats = cache.stats
    database_operation("After overflow", "Size: #{final_stats["size"]}, Evictions: #{final_stats["evictions"]}")
  end
end

# Run the demo
if ARGV.size > 0 && ARGV[0] == "run"
  AdvancedCachingDemo.run
end
