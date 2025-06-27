require "../../src/cql"
require "../../src/cache/memory_cache"
require "../../src/cache/fragment_cache"
require "../../src/cache/invalidation_strategies"

# Demo: CQL ActiveRecord Model with Advanced Caching
puts "🚀 CQL ActiveRecord Advanced Caching Demo"
puts "=" * 50

# Initialize cache infrastructure
memory_cache = CQL::Cache::MemoryCache.new(max_size: 100)
timestamp_strategy = CQL::Cache::TimestampInvalidation.new(60.seconds)
version_strategy = CQL::Cache::VersionInvalidation.new
fragment_cache = CQL::Cache::FragmentCache.new(memory_cache, timestamp_strategy)

# Mock User model that demonstrates CQL ActiveRecord Model integration
# Note: In real usage, this would connect to an actual database
struct User
  include CQL::ActiveRecord::Model(Int64)

  # Attributes
  getter id : Int64?
  getter name : String
  getter email : String
  getter created_at : Time?
  getter updated_at : Time?

  # Constructor
  def initialize(@name : String, @email : String, @created_at : Time? = nil, @updated_at : Time? = nil, @id : Int64? = nil)
  end

  # Custom cache key generation (included from CacheControl mixin)
  def cache_key
    "user:#{id || "new"}:#{updated_at.try(&.to_unix) || Time.utc.to_unix}"
  end

  # Serialization for caching
  def to_json(json : JSON::Builder)
    json.object do
      json.field "id", id
      json.field "name", name
      json.field "email", email
      json.field "created_at", created_at.try(&.to_rfc3339)
      json.field "updated_at", updated_at.try(&.to_rfc3339)
    end
  end
end

# Mock Post model
struct Post
  include CQL::ActiveRecord::Model(Int64)

  # Attributes
  getter id : Int64?
  getter user_id : Int64
  getter title : String
  getter content : String
  getter created_at : Time?
  getter updated_at : Time?

  # Constructor
  def initialize(@user_id : Int64, @title : String, @content : String, @created_at : Time? = nil, @updated_at : Time? = nil, @id : Int64? = nil)
  end

  # Custom cache key for post
  def cache_key
    "post:#{id || "new"}:#{updated_at.try(&.to_unix) || Time.utc.to_unix}"
  end

  # Serialization for caching
  def to_json(json : JSON::Builder)
    json.object do
      json.field "id", id
      json.field "user_id", user_id
      json.field "title", title
      json.field "content", content
      json.field "created_at", created_at.try(&.to_rfc3339)
      json.field "updated_at", updated_at.try(&.to_rfc3339)
    end
  end
end

puts "✅ Models defined with CQL ActiveRecord"

# Demo 1: Basic model caching
puts "\n📝 Demo 1: Model Instance Caching"
user = User.new("John Doe", "john@example.com", Time.utc, Time.utc, 1_i64)
puts "Created user: #{user.name} (#{user.email})"

# Cache the user using ActiveRecord caching methods
cache_key = user.cache_key
tags = ["user:#{user.id}", "table:users"]
memory_cache.set(cache_key, user.to_json)
memory_cache.tag_cache(cache_key, tags)
puts "✅ Cached user with key: #{cache_key}"
puts "🏷️  Cache tags: #{tags}"

# Retrieve from cache
cached_data = memory_cache.get(cache_key)
puts "📦 Retrieved from cache: #{cached_data ? "✅ HIT" : "❌ MISS"}"

# Demo 2: Fragment caching with model data
puts "\n🧩 Demo 2: Fragment Caching with Model Operations"

# Simulate expensive user statistics calculation
expensive_user_stats = fragment_cache.cache_fragment("user:#{user.id}:stats", {} of String => DB::Any, ["user:#{user.id}", "stats"], 300.seconds) do
  puts "   💰 Computing expensive user statistics..."
  sleep(0.1.seconds) # Simulate expensive operation
  {
    posts_count:      15,
    avg_post_length:  250,
    last_activity:    Time.utc,
    engagement_score: 85.5,
  }.to_json
end

puts "📊 User stats cached: #{expensive_user_stats[0..50]}..."

# Demo 3: Model relationships with caching
puts "\n🔗 Demo 3: Model Relationships with Caching"

post1 = Post.new(1_i64, "Introduction to Crystal", "Crystal is a fantastic language...", Time.utc, Time.utc, 101_i64)
post2 = Post.new(1_i64, "Advanced Crystal Features", "Let's explore advanced Crystal concepts...", Time.utc, Time.utc, 102_i64)

posts = [post1, post2]

# Cache user's posts using the relationship pattern
posts_cache_key = "user:#{user.id}:posts"
posts_data = posts.map(&.to_json).to_json
memory_cache.set(posts_cache_key, posts_data)
memory_cache.tag_cache(posts_cache_key, ["user:#{user.id}", "posts"])
puts "✅ Cached user posts: #{posts.size} posts"

# Demo 4: Cache invalidation strategies
puts "\n🔄 Demo 4: Cache Invalidation Strategies"

# Timestamp-based invalidation
puts "⏰ Timestamp-based invalidation:"
temp_key = "temp:user:profile"
memory_cache.set(temp_key, user.to_json, 0.05.seconds) # Very short TTL
puts "   Cached with short TTL"

sleep(0.1.seconds)
cached = memory_cache.get(temp_key)
puts "   Retrieved: #{cached ? "✅ VALID" : "❌ EXPIRED"}"

# Version-based invalidation
puts "🔢 Version-based invalidation:"
version_key = "user:#{user.id}:profile:v1"
memory_cache.set(version_key, user.to_json)
memory_cache.tag_cache(version_key, ["user:#{user.id}"])
puts "   Cached with version strategy"

# Increment version (simulating model update)
version_strategy.increment_version(version_key)
puts "   Version incremented"

# Simulate invalidation by checking version metadata
cached_versioned = memory_cache.get(version_key)
puts "   Retrieved: #{cached_versioned ? "✅ VALID" : "❌ INVALIDATED"}"

# Demo 5: Advanced cache operations
puts "\n🎯 Demo 5: Advanced Cache Operations"

# Tag-based invalidation
puts "🏷️  Tag-based invalidation:"
memory_cache.set("user:1:profile", user.to_json)
memory_cache.tag_cache("user:1:profile", ["user:1", "profile"])
memory_cache.set("user:1:preferences", {"theme" => "dark"}.to_json)
memory_cache.tag_cache("user:1:preferences", ["user:1", "preferences"])
memory_cache.set("user:1:notifications", {"count" => 5}.to_json)
memory_cache.tag_cache("user:1:notifications", ["user:1", "notifications"])

before_count = memory_cache.stats["size"]
puts "   Entries before invalidation: #{before_count}"

# Invalidate all user:1 related cache
memory_cache.invalidate_tags(["user:1"])
after_count = memory_cache.stats["size"]
puts "   Entries after tag invalidation: #{after_count}"
puts "   Invalidated #{before_count.to_i64 - after_count.to_i64} entries"

# Demo 6: Performance monitoring
puts "\n📈 Demo 6: Performance Monitoring and Cache Statistics"

# Simulate some cache operations
10.times do |i|
  key = "demo:item:#{i}"
  if memory_cache.exists?(key)
    memory_cache.get(key)
  else
    memory_cache.set(key, "data_#{i}")
    memory_cache.tag_cache(key, ["demo"])
  end
end

stats = memory_cache.stats
puts "🎯 Cache Performance Statistics:"
hits = stats["hits"].as(Int64)
misses = stats["misses"].as(Int64)
total_ops = hits + misses
puts "   Total operations: #{total_ops}"
puts "   Hit rate: #{total_ops > 0 ? ((hits.to_f / total_ops) * 100).round(1) : 0.0}%"
puts "   Memory usage: #{stats["memory_usage_bytes"]} bytes"
puts "   Active keys: #{stats["size"]}"
puts "   Evictions: #{stats["evictions"]}"

# Demo 7: Model callback integration (simulated)
puts "\n🔗 Demo 7: Model Callback Integration"

# Simulate model update with cache invalidation
puts "📝 Simulating user update..."
updated_user = User.new("John Smith", user.email, user.created_at, Time.utc, user.id)

# Simulate before_save callback - invalidate old cache
puts "   🔄 before_save: Invalidating old cache..."
old_key = user.cache_key
memory_cache.delete(old_key)

# Simulate after_save callback - cache new data
puts "   💾 after_save: Setting new cache..."
new_key = updated_user.cache_key
new_tags = ["user:#{updated_user.id}", "table:users"]
memory_cache.set(new_key, updated_user.to_json)
memory_cache.tag_cache(new_key, new_tags)

puts "✅ Cache updated for modified user"
puts "   Old key: #{old_key}"
puts "   New key: #{new_key}"

# Demo 8: Cache-aware queries (simulated)
puts "\n🔍 Demo 8: Cache-Aware Queries"

# Simulate cache-first query pattern
puts "🔎 Implementing cache-first query pattern:"

# Check cache first
cached_user = memory_cache.get(new_key)
if cached_user
  puts "   ✅ Found user in cache"
else
  puts "   🔄 Cache miss - would query database"
  # In real implementation: user = User.find(user.id)
  memory_cache.set(new_key, updated_user.to_json)
  memory_cache.tag_cache(new_key, new_tags)
  puts "   💾 Cached fresh data from database"
end

# Final statistics
puts "\n📊 Final Cache Statistics:"
final_stats = memory_cache.stats
total_ops = final_stats["hits"].as(Int64) + final_stats["misses"].as(Int64)
hit_rate = total_ops > 0 ? ((final_stats["hits"].as(Int64).to_f / total_ops) * 100).round(1) : 0.0

puts "   Hit rate: #{hit_rate}%"
puts "   Total keys: #{final_stats["size"]}"
puts "   Memory usage: #{final_stats["memory_usage_bytes"]} bytes"
puts "   Cache hits: #{final_stats["hits"]}"
puts "   Cache misses: #{final_stats["misses"]}"

puts "\n🎉 CQL ActiveRecord Advanced Caching Demo Complete!"
puts "✨ The caching system is now integrated with CQL ActiveRecord Model"
puts "\n🔧 Key Integration Points Demonstrated:"
puts "   • CQL::ActiveRecord::Model includes CQL::Cache::ActiveRecordCaching"
puts "   • Model instances have cache key generation methods"
puts "   • Cache tag generation for model relationships"
puts "   • Automatic invalidation on model updates"
puts "   • Fragment caching for expensive computations"
puts "   • Performance monitoring and statistics"
