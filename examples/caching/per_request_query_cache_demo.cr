require "sqlite3"
require "../../src/cql"
require "../../src/cache/middleware"
require "../utilities/beautify"

include Beautify

# Example demonstrating per-request query caching
header("CQL Per-Request Query Cache Demo")
info("Counting repeated queries within each request (an N+1 diagnostic: every query still runs)")
config_item("Started at", timestamp)

section("Setting up Database Schema")
info("Creating SQLite database with users and posts tables")

schema = CQL::Schema.define(:cache_demo, "sqlite3://cache_demo.db", CQL::Adapter::SQLite) do
  table :users do
    primary :id, Int32, auto_increment: true
    column :name, String
    column :email, String
    column :age, Int32
  end

  table :posts do
    primary :id, Int32, auto_increment: true
    column :title, String
    column :content, String
    column :user_id, Int32
    foreign_key :user_id, :users, :id
  end
end

# The middleware tracks only with cache.on and cache.request_cache (true by default)
CQL.configure { |c| c.cache.on = true }

# Create tables and insert test data
schema.build
success("Database schema created successfully")

# Insert some test data
info("Inserting sample data...")
insert_users = schema.insert.into(:users)
insert_users.values([
  {:name => "John Doe", :email => "john@example.com", :age => 30},
  {:name => "Jane Smith", :email => "jane@example.com", :age => 25},
  {:name => "Bob Johnson", :email => "bob@example.com", :age => 35},
])
insert_users.commit
success("Sample users inserted")

# Example 1: Manual request lifecycle management
step(1, "Manual Request Lifecycle")
info("Demonstrating manual cache management with start/end requests")

# Start a new request
CQL::Cache::Middleware::Manual.start_request("request-1")
info("🎯 Started request: request-1")

# First query - this will hit the database
record User, id : Int32, name : String, email : String, age : Int32 do
  include DB::Serializable
end

sub_header("Query #1: SELECT users WHERE age = 30")
query = schema.query.from(:users).where(age: 30)
start_time = Time.monotonic
result1 = query.all(User)
exec_time = Time.monotonic - start_time
query_result("First execution", result1, false)
performance("Execution time: #{execution_time(exec_time)}")

# Same query again - it runs again and is counted as a hit
sub_header("Query #2: SELECT users WHERE age = 30 (identical SQL)")
start_time = Time.monotonic
result2 = query.all(User)
exec_time = Time.monotonic - start_time
query_result("Second execution (counted as a hit)", result2, false)
performance("Execution time: #{execution_time(exec_time)}")

# Different query - counted as a miss
sub_header("Query #3: SELECT users WHERE age = 25 (different SQL)")
result3 = schema.query.from(:users).where(age: 25).all(User)
query_result("Third execution", result3, false)

# Check cache statistics
cache_stats = CQL::Cache::Middleware::Manual.query_cache_stats
stats(cache_stats)

# End the request (drops its tracked statements)
CQL::Cache::Middleware::Manual.end_request
info("🏁 Request ended - tracked statements dropped")

step(2, "Automatic Request Block Management")
info("Using with_request block for automatic cleanup")

record ShortUser, id : Int32, name : String do
  include DB::Serializable
end

# Using the with_request block for automatic cleanup
CQL::Cache::Middleware::Manual.with_request("request-2") do
  info("🎯 Auto-managed request: request-2")

  sub_header("Query #1: SELECT id, name FROM users WHERE name = 'John Doe'")
  start_time = Time.monotonic
  result1 = schema.query
    .from(:users)
    .select(:id, :name)
    .where(name: "John Doe")
    .all(ShortUser)
  exec_time = Time.monotonic - start_time

  query_result("Database query", result1, false)
  performance("Execution time: #{execution_time(exec_time)}")

  sub_header("Query #2: SELECT id, name FROM users WHERE name = 'John Doe' (identical)")
  start_time = Time.monotonic
  result2 = schema.query
    .from(:users)
    .select(:id, :name)
    .where(name: "John Doe")
    .all(ShortUser)
  exec_time = Time.monotonic - start_time

  query_result("Repeated query (counted as a hit)", result2, false)
  performance("Execution time: #{execution_time(exec_time)}")

  stats(CQL::Cache::RequestQueryCache.instance.stats)
end
info("🏁 Block exited - tracked statements dropped")

step(3, "Complex Queries with Joins")
info("Tracking JOIN operations and complex SQL")

record UserPost, id : Int32, name : String, title : String do
  include DB::Serializable
end

CQL::Cache::Middleware::Manual.with_request("request-3") do
  info("🎯 Complex query request: request-3")

  # Insert some posts
  info("Inserting sample posts...")
  insert_posts = schema.insert.into(:posts)
  insert_posts.values([
    {:title => "First Post", :content => "Content 1", :user_id => 1},
    {:title => "Second Post", :content => "Content 2", :user_id => 1},
    {:title => "Third Post", :content => "Content 3", :user_id => 2},
  ])
  insert_posts.commit
  success("Sample posts inserted")

  # Complex query with joins
  sub_header("Complex JOIN Query #1")
  sql_snippet("SELECT users.id, users.name, posts.title FROM users JOIN posts WHERE users.name = 'John Doe'")

  join_query = schema.query
    .from(:users)
    .join(:posts) { |fields| fields.users.id == fields.posts.user_id }
    .select(users: [:id, :name], posts: [:title])
    .where { users.name == "John Doe" }

  start_time = Time.monotonic
  result1 = join_query.all(UserPost)
  exec_time = Time.monotonic - start_time

  query_result("Complex JOIN (database)", result1, false)
  performance("Execution time: #{execution_time(exec_time)}")

  sub_header("Complex JOIN Query #2 (identical SQL)")
  start_time = Time.monotonic
  result2 = join_query.all(UserPost)
  exec_time = Time.monotonic - start_time

  query_result("Complex JOIN (counted as a hit)", result2, false)
  performance("Execution time: #{execution_time(exec_time)}")

  stats(CQL::Cache::RequestQueryCache.instance.stats)
end

step(4, "Web Framework Integration")
info("Simulating web request lifecycle (Kemal-style middleware)")

# Simulate a web request lifecycle
class MockKemalEnv
  property request = MockRequest.new

  class MockRequest
    property headers = {"X-Request-ID" => "web-request-123"}
  end
end

# Simulate multiple requests
3.times do |i|
  env = MockKemalEnv.new
  env.request.headers["X-Request-ID"] = "web-request-#{i + 1}"
  request_id = env.request.headers["X-Request-ID"]

  # Start request (like before_all middleware)
  CQL::Cache::Middleware::Kemal.before_request(env)

  section("Web Request #{i + 1}")
  info("🌐 Processing request: #{request_id}")

  # Simulate some queries in a web request
  user_query = schema.query.from(:users).where(age: 30)

  sub_header("API Endpoint Query #1")
  start_time = Time.monotonic
  result1 = user_query.all(User)
  exec_time = Time.monotonic - start_time
  query_result("First query", result1, false)
  performance("Response time: #{execution_time(exec_time)}")

  sub_header("API Endpoint Query #2 (same request)")
  start_time = Time.monotonic
  result2 = user_query.all(User)
  exec_time = Time.monotonic - start_time
  query_result("Same query (counted as a hit)", result2, false)
  performance("Response time: #{execution_time(exec_time)}")

  success("Results identical: #{result1 == result2}")
  stats(CQL::Cache::RequestQueryCache.instance.stats)

  # End request (like after_all middleware)
  CQL::Cache::Middleware::Kemal.after_request(env)
  info("🏁 Request #{request_id} completed - its tracked statements dropped")
  empty_line
end

step(5, "Tracking Overhead")
info("Timing 100 identical queries with and without tracking: every query runs both times")

# Disable cache to show performance difference
section("Benchmark: Without Tracking")
CQL::Cache::RequestQueryCacheHelper.enabled = false
warning("Tracking disabled for baseline measurement")

info("Running 100 identical queries without tracking...")
start_time = Time.monotonic
100.times do
  schema.query.from(:users).all(User)
end
no_cache_time = Time.monotonic - start_time
performance("Total time: #{execution_time(no_cache_time)}")
performance("Average per query: #{execution_time(no_cache_time / 100)}")

# Enable cache
section("Benchmark: With Tracking")
CQL::Cache::RequestQueryCacheHelper.enabled = true
CQL::Cache::RequestQueryCacheHelper.start_request("perf-test")
success("Tracking enabled")

info("Running 100 identical queries with tracking...")
start_time = Time.monotonic
100.times do
  schema.query.from(:users).all(User)
end
with_cache_time = Time.monotonic - start_time

CQL::Cache::RequestQueryCacheHelper.end_request

performance("Without tracking: #{execution_time(no_cache_time)}")
performance("With tracking: #{execution_time(with_cache_time)} (no rows are served from the tracker: any difference is noise or its overhead)")

stats(CQL::Cache::RequestQueryCache.instance.stats)

header("What the Request Query Tracker Does")
feature_list("Per-Request Query Tracker", [
  "Counts repeated identical selects within a request (an N+1 diagnostic)",
  "Stores and serves no rows: every query still runs",
  "Each request fiber has its own id, statements and counters",
  "Queries from fibers a request spawns are not tracked",
  "Tracks only with cache.on and cache.request_cache in CQL.configure",
  "Drops a request's statements when it ends",
  "Hooks for HTTP::Server, Kemal, Lucky, Amber and SpiderGazelle",
])

demo_complete("Per-Request Query Cache Demo")
config_item("Completed at", timestamp)

# Cleanup
cleanup_notice
File.delete("cache_demo.db") if File.exists?("cache_demo.db")
success("Demo database removed")
