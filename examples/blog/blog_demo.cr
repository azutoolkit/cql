require "sqlite3"
require "../../src/cql"
require "../../src/performance"
require "../utilities/beautify"

include Beautify

# 📝 Blog Demo - Updated for New Configuration API
# Demonstrating the new developer-friendly configuration syntax

puts "=== 📝 CQL Blog Demo ==="

# Configure CQL with new syntax
CQL.configure do |config|
  config.db = "sqlite3://examples/blog/blog.db"
  config.env = "development"
  config.logger = Log.for("BlogDemo")
  config.migrations_table = :cql_schema_migrations
  config.schema_dir = "./examples/blog/schemas"
  config.schema_file = "app_schema.cr"
  config.schema_class = :BlogDB
  config.auto_load = true
  config.auto_sync = true
  config.bootstrap = true
  config.verify_schema = true
  config.monitor_performance = true
end

puts "✅ Blog demo configuration applied"

# Display effective configuration
puts "\n📊 Configuration Summary:"
config_summary = {
  "Database"               => CQL.config.db,
  "Environment"            => CQL.config.env,
  "Auto Load"              => CQL.config.auto_load?,
  "Auto Sync"              => CQL.config.auto_sync?,
  "Performance Monitoring" => CQL.config.monitor_performance?,
  "Bootstrap"              => CQL.config.bootstrap?,
  "Verify Schema"          => CQL.config.verify_schema?,
}
config_summary.each { |key, value| puts "  #{key}: #{value}" }

puts "\n🚀 Blog demo ready!"
puts "Schema directory: #{CQL.config.schema_dir}"
puts "Schema file: #{CQL.config.schema_file}"
puts "Schema class: #{CQL.config.schema_class}"
puts "Migrations table: #{CQL.config.migrations_table}"

module BlogDemo
  def self.run
    run_migrations
    seed_data = BlogDemo::Seeders.seed_data

    sleep 1.second
    CQL::Performance.monitor.generate_report("logger")
    sleep 1.second
    BlogDemo::Demos.crud_operations(seed_data)

    BlogDemo::Demos.complex_queries(BlogDB)
    BlogDemo::Demos.relationships(seed_data)
    BlogDemo::Demos.performance_features
    BlogDemo::Demos.statistics_and_reporting(BlogDB)

    demo_complete("Blog Application Demo")

    total_records = User.count + Category.count + Post.count + Comment.count

    summary_box("Demo Summary", [
      "Total records created: #{total_records}",
      "Database file: examples/blog/blog_demo.db",
      "Performance monitoring: enabled",
    ])

    feature_list("CQL Features Demonstrated", [
      "Configuration management",
      "Schema definition with relationships",
      "Database migrations",
      "Active Record models",
      "CRUD operations",
      "Complex queries and joins",
      "Aggregations and statistics",
      "Relationship navigation",
      "Performance optimizations",
      "Raw SQL capabilities",
      "Performance monitoring and reporting",
    ])

    feature_list("Performance Monitoring Features", [
      "Real-time query performance tracking",
      "N+1 query detection",
      "Slow query identification",
      "Beautiful developer-friendly reports",
      "Performance recommendations",
      "Query pattern analysis",
    ])

    status_indicator(:success, "This demonstrates CQL as a production-ready ORM with advanced performance monitoring!")
    separator()
  end

  def self.run_migrations
    step(1, "Running Migrations")
    migrator = BlogDB.migrator
    migrator.up
    success("Migrations applied successfully")
  end
end

# Require all demo components AFTER configuration
require "./schemas/*"
require "./migrations/*"
require "./seeders"
require "./models/*"
require "./demos/*"

# Run the demo
BlogDemo.run
