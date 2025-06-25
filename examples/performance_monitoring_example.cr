# CQL Performance Monitoring Example
# This example demonstrates how to use Query Plan Analysis, N+1 Detection, and Query Profiling

require "../src/cql"
require "../src/performance/interfaces"
require "../src/performance/event_system"
require "../src/performance/analyzers/query_plan_analyzer"
require "../src/performance/detectors/n_plus_one_detector"
require "../src/performance/profilers/query_profiler"
require "../src/performance/reports/report_generators"
require "../src/performance/performance_monitor"
require "sqlite3"

# 1. Define your schema
AcmeDB = CQL::Schema.define(:acme_db, "sqlite3://./examples/performance_example.db", CQL::Adapter::SQLite) do
  table :users do
    primary :id, Int32, auto_increment: true
    column :name, String
    column :email, String
    column :created_at, Time, default: Time.utc
  end

  table :posts do
    primary :id, Int32, auto_increment: true
    column :user_id, Int32
    column :title, String
    column :content, String
    column :created_at, Time, default: Time.utc
    foreign_key :user_id, :users, :id, on_delete: :cascade
  end

  table :comments do
    primary :id, Int32, auto_increment: true
    column :post_id, Int32
    column :user_id, Int32
    column :content, String
    column :created_at, Time, default: Time.utc
    foreign_key :post_id, :posts, :id, on_delete: :cascade
    foreign_key :user_id, :users, :id, on_delete: :cascade
  end
end

# 2. Define your models
struct User
  include CQL::ActiveRecord::Model(Int32)

  db_context AcmeDB, :users

  getter id : Int32?
  getter name : String
  getter email : String
  getter created_at : Time

  # Relationships
  has_many :posts, Post, foreign_key: :user_id
  has_many :comments, Comment, foreign_key: :user_id

  def initialize(@name : String, @email : String, @created_at : Time = Time.utc)
  end
end

struct Post
  include CQL::ActiveRecord::Model(Int32)

  db_context AcmeDB, :posts

  getter id : Int32?
  getter user_id : Int32
  getter title : String
  getter content : String
  getter created_at : Time

  # Relationships
  belongs_to :user, User, :user_id
  has_many :comments, Comment, foreign_key: :post_id

  def initialize(@user_id : Int32, @title : String, @content : String, @created_at : Time = Time.utc)
  end
end

struct Comment
  include CQL::ActiveRecord::Model(Int32)

  db_context AcmeDB, :comments

  getter id : Int32?
  getter post_id : Int32
  getter user_id : Int32
  getter content : String
  getter created_at : Time

  # Relationships
  belongs_to :post, Post, :post_id
  belongs_to :user, User, :user_id

  def initialize(@post_id : Int32, @user_id : Int32, @content : String, @created_at : Time = Time.utc)
  end
end

# 3. Setup Performance Monitoring
puts "Setting up CQL Performance Monitoring..."

# Create configuration
config = CQL::Performance::PerformanceConfig.new
config.query_profiling_enabled = true
config.n_plus_one_detection_enabled = true
config.plan_analysis_enabled = true
config.auto_analyze_slow_queries = true
config.context_tracking_enabled = true

# Initialize monitor with schema and configuration
monitor = CQL::Performance::PerformanceMonitor.new(config)
monitor.initialize_with_schema(AcmeDB, config)

# Set as global monitor
CQL::Performance.monitor = monitor

puts "Performance monitoring initialized!"

# 4. Create the database and sample data
puts "Creating database and sample data..."

begin
  AcmeDB.build

  # Create some sample users
  users = [
    User.new("Alice Smith", "alice@example.com"),
    User.new("Bob Johnson", "bob@example.com"),
    User.new("Carol Williams", "carol@example.com"),
  ]

  user_ids = [] of Int32
  users.each do |user|
    result = AcmeDB.insert.into(:users).values(
      name: user.name,
      email: user.email,
      created_at: user.created_at
    ).last_insert_id
    user_ids << result.to_i32
  end

  # Create some posts
  posts_data = [
    {user_id: user_ids[0], title: "First Post", content: "This is Alice's first post"},
    {user_id: user_ids[0], title: "Second Post", content: "This is Alice's second post"},
    {user_id: user_ids[1], title: "Bob's Thoughts", content: "This is Bob's post"},
    {user_id: user_ids[2], title: "Carol's Update", content: "This is Carol's post"},
  ]

  post_ids = [] of Int32
  posts_data.each do |post_data|
    result = AcmeDB.insert.into(:posts).values(
      user_id: post_data[:user_id],
      title: post_data[:title],
      content: post_data[:content],
      created_at: Time.utc
    ).last_insert_id
    post_ids << result.to_i32
  end

  # Create some comments
  comments_data = [
    {post_id: post_ids[0], user_id: user_ids[1], content: "Great post, Alice!"},
    {post_id: post_ids[0], user_id: user_ids[2], content: "I agree with Bob"},
    {post_id: post_ids[1], user_id: user_ids[2], content: "Nice follow-up"},
    {post_id: post_ids[2], user_id: user_ids[0], content: "Thanks for sharing, Bob"},
  ]

  comments_data.each do |comment_data|
    AcmeDB.insert.into(:comments).values(
      post_id: comment_data[:post_id],
      user_id: comment_data[:user_id],
      content: comment_data[:content],
      created_at: Time.utc
    ).commit
  end

  puts "Sample data created successfully!"
rescue ex
  puts "Database setup error: #{ex.message}"
end

# 5. Demonstrate Performance Monitoring Features

puts "\n" + "="*60
puts "DEMONSTRATING PERFORMANCE MONITORING FEATURES"
puts "="*60

# 5.1 Query Plan Analysis
puts "\n1. QUERY PLAN ANALYSIS"
puts "-" * 30

# Set context for tracking
monitor.set_context(endpoint: "/api/users", user_id: "demo_user")

# Analyze a query plan
simple_query = "SELECT * FROM users WHERE name = 'Alice Smith'"

if plan = monitor.analyze_query_plan(simple_query)
  puts "Query Plan for: #{simple_query}"
  puts plan.summary if plan.responds_to?(:summary)
else
  puts "Query plan analysis not available for SQLite"
end

# 5.2 Query Profiling - Execute some queries to generate data
puts "\n2. QUERY PROFILING"
puts "-" * 20

puts "Executing queries for profiling..."

# Set different contexts to demonstrate endpoint tracking
monitor.set_context(endpoint: "/api/users", user_id: "user_123")

# Execute various queries and monitor them
5.times do |i|
  start_time = Time.monotonic
  users = AcmeDB.query.from(:users).all({id: Int32, name: String, email: String})
  execution_time = Time.monotonic - start_time

  # Manually trigger monitoring for demo
  monitor.after_query("SELECT id, name, email FROM users", [] of DB::Any, execution_time, users.size.to_i64)

  puts "Fetched #{users.size} users (iteration #{i + 1})"
end

monitor.set_context(endpoint: "/api/posts", user_id: "user_456")

# Execute more complex queries
3.times do |i|
  start_time = Time.monotonic
  posts = AcmeDB.query
    .from(:posts)
    .join(:users) { |j| j.posts.user_id.eq(j.users.id) }
    .select(posts: [:id, :title], users: [:name])
    .all({id: Int32, title: String, name: String})
  execution_time = Time.monotonic - start_time

  # Manually trigger monitoring for demo
  monitor.after_query("SELECT posts.id, posts.title, users.name FROM posts JOIN users ON posts.user_id = users.id", [] of DB::Any, execution_time, posts.size.to_i64)

  puts "Fetched #{posts.size} posts with user names (iteration #{i + 1})"
end

# 5.3 N+1 Query Detection
puts "\n3. N+1 QUERY DETECTION"
puts "-" * 25

puts "Demonstrating N+1 query pattern..."

# This will trigger N+1 queries - one query to get posts, then one query per post to get user
monitor.set_context(endpoint: "/api/posts_with_users", user_id: "user_789")

start_time = Time.monotonic
posts = AcmeDB.query.from(:posts).all({id: Int32, user_id: Int32, title: String})
execution_time = Time.monotonic - start_time

# Trigger the parent query monitoring
monitor.after_query("SELECT id, user_id, title FROM posts", [] of DB::Any, execution_time, posts.size.to_i64)

puts "Fetched #{posts.size} posts"

# Start relation loading to track N+1 pattern
monitor.start_relation_loading("user", "Post")

# This loop will trigger N+1 pattern detection
posts.each do |post|
  # This will execute a separate query for each post
  start_time = Time.monotonic
  user = AcmeDB.query.from(:users).where(id: post[:user_id]).first({id: Int32, name: String})
  execution_time = Time.monotonic - start_time

  # Trigger monitoring for the repeated query
  monitor.after_query("SELECT id, name FROM users WHERE id = ?", [post[:user_id].as(DB::Any)], execution_time, 1_i64)

  puts "Post '#{post[:title]}' by #{user.try(&.[:name]) || "Unknown"}"
end

# End relation loading
monitor.end_relation_loading

# 5.4 Generate Performance Reports
puts "\n" + "="*60
puts "PERFORMANCE REPORTS"
puts "="*60

# Comprehensive report
puts "\n--- COMPREHENSIVE PERFORMANCE REPORT ---"
puts monitor.generate_comprehensive_report

# Individual reports
puts "\n--- N+1 DETECTION REPORT ---"
puts monitor.n_plus_one_report

puts "\n--- QUERY PROFILING REPORT ---"
puts monitor.profiling_report

# 5.5 Performance Metrics Summary
puts "\n--- PERFORMANCE METRICS SUMMARY ---"
metrics = monitor.metrics_summary
puts "Total Queries: #{metrics.total_queries}"
puts "Slow Queries: #{metrics.slow_queries}"
puts "N+1 Patterns: #{metrics.n_plus_one_patterns}"
puts "Average Query Time: #{metrics.avg_query_time.round(2)}ms"
puts "Monitoring Enabled: #{metrics.monitoring_enabled}"
puts "Uptime: #{metrics.uptime.total_seconds.round(2)} seconds"

# 6. Advanced Features
puts "\n" + "="*60
puts "ADVANCED FEATURES"
puts "="*60

# Generate HTML report
puts "\nGenerating HTML performance report..."
html_report = monitor.generate_comprehensive_report("html")
File.write("performance_report.html", html_report)
puts "HTML report saved to 'performance_report.html'"

# Generate JSON report
puts "\nGenerating JSON performance report..."
json_report = monitor.generate_comprehensive_report("json")
File.write("performance_report.json", json_report)
puts "JSON report saved to 'performance_report.json'"

# Configuration management
puts "\nDemonstrating configuration management..."
monitor.configure do |config|
  config.query_profiling_enabled = false # Temporarily disable profiling
  puts "Query profiling disabled"
end

# Test a query with profiling disabled
start_time = Time.monotonic
users = AcmeDB.query.from(:users).all({id: Int32, name: String})
execution_time = Time.monotonic - start_time
monitor.after_query("SELECT id, name FROM users", [] of DB::Any, execution_time, users.size.to_i64)

monitor.configure do |config|
  config.query_profiling_enabled = true # Re-enable profiling
  puts "Query profiling re-enabled"
end

# Demonstrate component access for advanced usage
puts "\nDemonstrating advanced component access..."
puts "Event bus type: #{monitor.event_bus.class}"
puts "Query profiler stats: #{monitor.query_profiler.statistics.size} patterns tracked"
puts "N+1 detector issues: #{monitor.n_plus_one_detector.get_issues.size} issues detected"

puts "\n" + "="*60
puts "PERFORMANCE MONITORING DEMO COMPLETE"
puts "="*60
puts "Check the generated HTML and JSON reports for detailed analysis."
puts "In a real application, you would integrate this into your web framework"
puts "to track performance across different endpoints and users."
puts "\nNew Architecture Benefits Demonstrated:"
puts "- Event-driven processing with Observer pattern"
puts "- Strategy pattern for database-specific analysis"
puts "- Factory pattern for report generation"
puts "- Dependency injection for testability"
puts "- SOLID principles for maintainability"
