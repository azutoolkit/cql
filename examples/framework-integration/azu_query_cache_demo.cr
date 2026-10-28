require "../../src/cql"
require "../../src/cache/middleware"
require "sqlite3"

# Helper classes for simulation
class MockRequest
  property headers : Hash(String, String)

  def initialize(@headers = {} of String => String)
  end
end

class MockContext
  property request : MockRequest

  def initialize(@request)
  end
end

# Example demonstrating per-request query caching integration with Azu framework
# This shows multiple ways to integrate the caching with Azu applications

# The middleware tracks only with cache.on and cache.request_cache (true by default)
CQL.configure { |c| c.cache.on = true }

# Set up a simple database schema for the demo
schema = CQL::Schema.define(:azu_demo, "sqlite3://azu_demo.db", CQL::Adapter::SQLite) do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String
    column :email, String
    column :role, String
    timestamps
  end

  table :articles do
    primary :id, Int64, auto_increment: true
    column :title, String
    column :content, String
    column :author_id, Int64
    column :published, Bool, default: false
    foreign_key :author_id, :users, :id
    timestamps
  end
end

# Create tables and insert demo data
schema.build

# Insert demo users
users_insert = schema.insert.into(:users)
users_insert.values([
  {:name => "Alice Johnson".as(DB::Any), :email => "alice@example.com".as(DB::Any), :role => "admin".as(DB::Any)},
  {:name => "Bob Smith".as(DB::Any), :email => "bob@example.com".as(DB::Any), :role => "editor".as(DB::Any)},
  {:name => "Carol Davis".as(DB::Any), :email => "carol@example.com".as(DB::Any), :role => "author".as(DB::Any)},
])
users_insert.commit

# Insert demo articles
articles_insert = schema.insert.into(:articles)
articles_insert.values([
  {:title => "Getting Started with Azu".as(DB::Any), :content => "Azu is a powerful toolkit...".as(DB::Any), :author_id => 1.as(DB::Any), :published => true.as(DB::Any)},
  {:title => "Advanced Azu Features".as(DB::Any), :content => "This article covers...".as(DB::Any), :author_id => 2.as(DB::Any), :published => true.as(DB::Any)},
  {:title => "Azu Performance Tips".as(DB::Any), :content => "To optimize your Azu app...".as(DB::Any), :author_id => 3.as(DB::Any), :published => false.as(DB::Any)},
])
articles_insert.commit

puts "=== Azu Framework Per-Request Query Caching Demo ==="
puts "Repository: https://github.com/azutoolkit/azu"
puts ""

# Example 1: HTTP Handler Integration
puts "=== Example 1: HTTP Handler Integration ==="
puts ""
puts "# In your Azu application setup:"
puts "require \"cql/cache/middleware\""
puts ""
puts "# An Azu::App takes its handlers as an array: add the handler after Azu's defaults (RequestId first)"
puts "app = Azu::App.default"
puts "app.start(app.default_handlers + [CQL::Cache::Middleware::HTTP.new] of HTTP::Handler)"
puts ""

# Simulate the handler behavior
puts "Simulating HTTP Handler behavior:"
puts ""

# Simulate multiple requests with the handler
3.times do |i|
  puts "--- Request #{i + 1} ---"

  # Start request (like the handler would do)
  CQL::Cache::Middleware::Azu.before_request(
    MockContext.new(MockRequest.new({"X-Request-ID" => "azu-req-#{i + 1}"}))
  )

  # Simulate queries in an Azu request
  puts "Query 1: Loading user data"
  users_query = schema.query.from(:users).where(role: "admin")
  result1 = users_query.all(as: {id: Int64, name: String, email: String, role: String})
  puts "Result: #{result1}"

  puts "Query 2: Same query - runs again, counted as a hit"
  result2 = users_query.all(as: {id: Int64, name: String, email: String, role: String})
  puts "Same rows: #{result1 == result2}"

  puts "Query 3: Different query - counted as a miss"
  articles_query = schema.query.from(:articles).where(published: true)
  result3 = articles_query.all(as: {id: Int64, title: String, content: String, author_id: Int64, published: Bool})
  puts "Articles: #{result3.size} published articles"

  # Show cache stats
  stats = CQL::Cache::RequestQueryCacheHelper.stats
  puts "Cache stats: #{stats["hits"]} hits, #{stats["misses"]} misses"

  # End request (like the handler would do)
  CQL::Cache::Middleware::Azu.after_request(nil)
  puts ""
end

# Example 2: Controller Integration
puts "=== Example 2: Controller Integration ==="
puts ""
puts "# Azu endpoints have no before_action/after_action, which the deprecated"
puts "# CQL::Cache::Middleware::Azu::Controller needs: mount the handler (Example 1),"
puts "# or start and end the request yourself, as this mock controller does."
puts ""

# Simulate controller behavior
puts "Simulating Controller behavior:"
puts ""

class MockAzuController
  # Note: In a controller-style class of another framework, you would include CQL::Cache::Middleware::Azu::Controller
  # include CQL::Cache::Middleware::Azu::Controller
  # We skip the include here to avoid dependency on Azu framework methods

  def request
    MockRequest.new({"X-Request-ID" => "controller-demo"})
  end

  def index(schema)
    # Manually start the query cache (a controller-style class would do this for you)
    CQL::Cache::RequestQueryCacheHelper.start_request("controller-demo")

    puts "Loading users in controller action..."
    users = schema.query.from(:users).all(as: {id: Int64, name: String, email: String, role: String})
    puts "Users loaded: #{users.size}"

    puts "Loading users again - runs again, counted as a hit..."
    users_cached = schema.query.from(:users).all(as: {id: Int64, name: String, email: String, role: String})
    puts "Same rows: #{users == users_cached}"

    stats = CQL::Cache::RequestQueryCacheHelper.stats
    puts "Controller cache stats: #{stats["hits"]} hits, #{stats["misses"]} misses"

    CQL::Cache::RequestQueryCacheHelper.end_request
  end
end

controller = MockAzuController.new
controller.index(schema)
puts ""

# Example 3: Manual Hook Integration
puts "=== Example 3: Manual Hook Integration ==="
puts ""
puts "# Azu has no before/after hooks: call them from a handler of your own in the app's handler array"
puts "class QueryCacheHooks"
puts "  include HTTP::Handler"
puts ""
puts "  def call(context)"
puts "    CQL::Cache::Middleware::Azu.before_request(context)"
puts "    call_next(context)"
puts "  ensure"
puts "    CQL::Cache::Middleware::Azu.after_request(context)"
puts "  end"
puts "end"
puts ""

# Example 4: Tracking overhead
puts "=== Example 4: Tracking overhead ==="
puts ""

# Disable cache for baseline
CQL::Cache::RequestQueryCacheHelper.enabled = false

puts "Measuring performance without tracking..."
start_time = Time.monotonic
50.times do
  schema.query.from(:users).all(as: {id: Int64, name: String, email: String, role: String})
end
no_cache_time = Time.monotonic - start_time

# Enable cache for comparison
CQL::Cache::RequestQueryCacheHelper.enabled = true
CQL::Cache::RequestQueryCacheHelper.start_request("perf-test")

puts "Measuring performance with tracking..."
start_time = Time.monotonic
50.times do
  schema.query.from(:users).all(as: {id: Int64, name: String, email: String, role: String})
end
with_cache_time = Time.monotonic - start_time

CQL::Cache::RequestQueryCacheHelper.end_request

speedup = no_cache_time / with_cache_time

puts ""
puts "Timing (50 identical queries; every one runs both times, so any difference is noise or tracking overhead):"
puts "Without tracking: #{no_cache_time.total_milliseconds.round(2)}ms"
puts "With tracking: #{with_cache_time.total_milliseconds.round(2)}ms"
puts "Ratio: #{speedup.round(2)}"
puts ""

# Example 5: Real-world Azu Application Pattern
puts "=== Example 5: Real-world Azu Application Pattern ==="
puts ""
puts "```crystal"
puts "require \"azu\""
puts "require \"cql\""
puts "require \"cql/cache/middleware\""
puts ""
puts "require \"./endpoints/*\" # your Azu::Endpoint types: a query repeated within one request is counted as a hit"
puts ""
puts "app = Azu::App.default"
puts "app.start(app.default_handlers + [CQL::Cache::Middleware::HTTP.new] of HTTP::Handler)"
puts "```"
puts ""

puts "=== What the tracker does ==="
puts "- Counts repeated identical statements within a request (an N+1 diagnostic)"
puts "- Works with any CQL select (all, get, find, counts, joins)"
puts "- Stores and serves no rows: every query still runs, so it makes nothing faster"
puts "- Each request fiber has its own id, statements and counters; fibers it spawns are not tracked"
puts "- Tracks only with cache.on and cache.request_cache set in CQL.configure"
puts ""

puts "=== Cache Statistics Summary ==="
final_stats = CQL::Cache::RequestQueryCache.instance.stats
puts "Total cache operations: #{final_stats["hits"].as(Int64) + final_stats["misses"].as(Int64)}"
puts "Cache hits: #{final_stats["hits"]}"
puts "Cache misses: #{final_stats["misses"]}"
if final_stats["hits"].as(Int64) + final_stats["misses"].as(Int64) > 0
  hit_rate = (final_stats["hits"].as(Int64).to_f / (final_stats["hits"].as(Int64) + final_stats["misses"].as(Int64)).to_f * 100).round(2)
  puts "Overall hit rate: #{hit_rate}%"
end
puts ""

puts "For more information about the Azu framework, visit:"
puts "https://github.com/azutoolkit/azu"
puts "https://azutopia.gitbook.io/azu/"

# Cleanup
File.delete("azu_demo.db") if File.exists?("azu_demo.db")
