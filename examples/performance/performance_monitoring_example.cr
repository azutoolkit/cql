# CQL Performance Monitoring Example
# This example demonstrates how to use Query Plan Analysis, N+1 Detection, and Query Profiling

require "../../src/cql"
require "../../src/performance/interfaces"
require "../../src/performance/event_system"
require "../../src/performance/analyzers/query_plan_analyzer"
require "../../src/performance/detectors/n_plus_one_detector"
require "../../src/performance/profilers/query_profiler"
require "../../src/performance/reports/report_generators"
require "../../src/performance/performance_monitor"
require "sqlite3"
require "../utilities/beautify"

include Beautify

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
header("CQL Performance Monitoring Example")

section("Setting up Performance Monitoring")

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

success("Performance monitoring initialized!")

# 4. Create the database and sample data
section("Creating Database and Sample Data")

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

  success("Sample data created successfully!")
  configuration_block("Sample Data", {
    "Users"    => users.size,
    "Posts"    => posts_data.size,
    "Comments" => comments_data.size,
  })
rescue ex
  error("Database setup error: #{ex.message}")
end

# 5. Demonstrate Performance Monitoring Features
separator("═", 60)
header("DEMONSTRATING PERFORMANCE MONITORING FEATURES")
separator("═", 60)

# 5.1 Query Plan Analysis
step(1, "Query Plan Analysis")

# Set context for tracking
monitor.set_context(endpoint: "/api/users", user_id: "demo_user")

# Analyze a query plan
simple_query = "SELECT * FROM users WHERE name = 'Alice Smith'"

if plan = monitor.analyze_query_plan(simple_query)
  info("Query Plan for: #{simple_query}")
  puts plan.summary if plan.responds_to?(:summary)
else
  warning("Query plan analysis not available for SQLite")
end

# 5.2 Query Profiling - Execute some queries to generate data
step(2, "Query Profiling")

info("Executing queries for profiling...")

# Set different contexts to demonstrate endpoint tracking
monitor.set_context(endpoint: "/api/users", user_id: "user_123")

# Execute various queries and monitor them
5.times do |i|
  start_time = Time.monotonic
  users = AcmeDB.query.from(:users).all({id: Int32, name: String, email: String})
  execution_time = Time.monotonic - start_time

  # Manually trigger monitoring for demo
  monitor.after_query("SELECT id, name, email FROM users", [] of DB::Any, execution_time, users.size.to_i64)

  database_operation("Fetched users", "#{users.size} users (iteration #{i + 1})")
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

  database_operation("Fetched posts with user names", "#{posts.size} posts (iteration #{i + 1})")
end

# 5.3 N+1 Query Detection
step(3, "N+1 Query Detection")

info("Demonstrating N+1 query pattern...")

# This will trigger N+1 queries - one query to get posts, then one query per post to get user
monitor.set_context(endpoint: "/api/posts_with_users", user_id: "user_789")

start_time = Time.monotonic
posts = AcmeDB.query.from(:posts).all({id: Int32, user_id: Int32, title: String})
execution_time = Time.monotonic - start_time

# Trigger the parent query monitoring
monitor.after_query("SELECT id, user_id, title FROM posts", [] of DB::Any, execution_time, posts.size.to_i64)

database_operation("Fetched posts", "#{posts.size} posts")

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

  bullet_point("Post '#{post[:title]}' by #{user.try(&.[:name]) || "Unknown"}")
end

# End relation loading
monitor.end_relation_loading

# 5.4 Generate Performance Reports
separator("═", 60)
header("PERFORMANCE REPORTS")
separator("═", 60)

# Comprehensive report
sub_header("Comprehensive Performance Report")
puts monitor.generate_comprehensive_report

# Individual reports
sub_header("N+1 Detection Report")
puts monitor.n_plus_one_report

sub_header("Query Profiling Report")
puts monitor.profiling_report

# 5.5 Performance Metrics Summary
sub_header("Performance Metrics Summary")
metrics = monitor.metrics_summary
configuration_block("Performance Metrics", {
  "Total Queries"      => metrics.total_queries,
  "Slow Queries"       => metrics.slow_queries,
  "N+1 Patterns"       => metrics.n_plus_one_patterns,
  "Average Query Time" => "#{metrics.avg_query_time.round(2)}ms",
  "Monitoring Enabled" => metrics.monitoring_enabled?,
  "Uptime"             => "#{metrics.uptime.total_seconds.round(2)} seconds",
})

# 6. Advanced Features
separator("═", 60)
header("ADVANCED FEATURES")
separator("═", 60)

# Generate HTML report
info("Generating HTML performance report...")
html_report = monitor.generate_comprehensive_report("html")
File.write("performance_report.html", html_report)
file_operation("HTML report saved", "performance_report.html", :created)

# Generate JSON report
info("Generating JSON performance report...")
json_report = monitor.generate_comprehensive_report("json")
File.write("performance_report.json", json_report)
file_operation("JSON report saved", "performance_report.json", :created)

# Configuration management
info("Demonstrating configuration management...")
monitor.configure do |cfg|
  cfg.query_profiling_enabled = false # Temporarily disable profiling
  warning("Query profiling disabled")
end

# Test a query with profiling disabled
start_time = Time.monotonic
users = AcmeDB.query.from(:users).all({id: Int32, name: String})
execution_time = Time.monotonic - start_time
monitor.after_query("SELECT id, name FROM users", [] of DB::Any, execution_time, users.size.to_i64)

monitor.configure do |cfg|
  cfg.query_profiling_enabled = true # Re-enable profiling
  success("Query profiling re-enabled")
end

# Demonstrate component access for advanced usage
sub_header("Advanced Component Access")
database_operation("Event bus type", monitor.event_bus.class.to_s)
database_operation("Query profiler stats", "#{monitor.query_profiler.statistics.size} patterns tracked")
database_operation("N+1 detector issues", "#{monitor.n_plus_one_detector.issues.size} issues detected")

separator("═", 60)
header("PERFORMANCE MONITORING DEMO COMPLETE")
separator("═", 60)

feature_list("Demo Results", [
  "Check the generated HTML and JSON reports for detailed analysis",
  "In a real application, you would integrate this into your web framework",
  "to track performance across different endpoints and users",
])

feature_list("New Architecture Benefits Demonstrated", [
  "Event-driven processing with Observer pattern",
  "Strategy pattern for database-specific analysis",
  "Factory pattern for report generation",
  "Dependency injection for testability",
  "SOLID principles for maintainability",
])
