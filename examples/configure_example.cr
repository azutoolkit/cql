require "sqlite3"
require "../src/cql"

# Example 1: Basic Configuration
puts "=== Example 1: Basic Configuration ==="

CQL.configure do |config|
  config.database_url = "postgresql://localhost/myapp_development"
  config.logger = Log.for("MyApp")
  config.default_timezone = :utc
  config.migration_table_name = "schema_migrations"
  config.schema_path = "src/schemas"
  config.auto_load_models = true
end

puts "Database URL: #{CQL.config.database_url}"
puts "Timezone: #{CQL.config.default_timezone}"
puts "Auto load models: #{CQL.config.auto_load_models?}"
puts "Pool size: #{CQL.config.pool_size}"
puts

# Example 2: Environment-Specific Configuration
puts "=== Example 2: Environment-Specific Configuration ==="

CQL.configure do |config|
  case ENV["CRYSTAL_ENV"]? || "development"
  when "production"
    config.database_url = ENV["DATABASE_URL"]
    config.logger = Log.for("Production")
    config.auto_load_models = false
    config.pool_size = 25
    config.enable_sql_logging = false
    config.enable_performance_monitoring = false
  when "test"
    config.database_url = "sqlite3://:memory:"
    config.logger = Log.for("Test")
    config.migration_table_name = "test_schema_migrations"
    config.auto_load_models = false
    config.pool_size = 1
  else
    config.database_url = "sqlite3://./db/development.db"
    config.logger = Log.for("Development")
    config.auto_load_models = true
    config.enable_sql_logging = true
    config.enable_performance_monitoring = true
  end
end

puts "Environment: #{CQL.config.environment}"
puts "Database URL: #{CQL.config.database_url}"
puts "SQL Logging: #{CQL.config.enable_sql_logging?}"
puts "Performance Monitoring: #{CQL.config.enable_performance_monitoring?}"
puts

# Example 3: Advanced Configuration with Performance Monitoring
puts "=== Example 3: Advanced Configuration ==="

CQL.configure do |config|
  config.database_url = "postgresql://localhost/myapp"
  config.pool_size = 15
  config.checkout_timeout = 10.seconds
  config.query_timeout = 30.seconds
  config.enable_query_cache = true
  config.cache_ttl = 2.hours
  config.max_retry_attempts = 3
  config.retry_delay = 1.second
  config.enable_performance_monitoring = true

  # Configure performance monitoring
  perf_config = CQL::Performance::PerformanceConfig.new
  perf_config.query_profiling_enabled = true
  perf_config.n_plus_one_detection_enabled = true
  perf_config.plan_analysis_enabled = true
  perf_config.auto_analyze_slow_queries = true
  config.performance_config = perf_config
end

puts "Query cache enabled: #{CQL.config.enable_query_cache?}"
puts "Cache TTL: #{CQL.config.cache_ttl}"
puts "Max retry attempts: #{CQL.config.max_retry_attempts}"
puts "Database adapter: #{CQL.config.database_adapter}"
puts

# Example 4: Using Configuration Helpers
puts "=== Example 4: Configuration Helpers ==="

puts "Database URL (helper): #{CQL::ConfigHelpers.database_url}"
puts "Logger (helper): #{CQL::ConfigHelpers.logger}"
puts "Timezone (helper): #{CQL::ConfigHelpers.timezone}"
puts "Environment (helper): #{CQL::ConfigHelpers.environment}"
puts "Auto load models (helper): #{CQL::ConfigHelpers.auto_load_models?}"
puts

# Example 5: Database Schema Using Configuration
puts "=== Example 5: Using Configuration in Schema Definition ==="

# Define schema using SQLite for compatibility (no external driver needed)
# Reset config to use SQLite for this example
CQL.configure do |config|
  config.database_url = "sqlite3://examples/demo.db"
end

MyAppDB = CQL::Schema.define(
  :myapp_db,
  adapter: CQL.config.database_adapter,
  uri: CQL.config.database_url
) do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String, null: false
    column :email, String, null: false
    column :created_at, Time, null: true
    column :updated_at, Time, null: true

    unique_constraint [:email]
  end

  table :posts do
    primary :id, Int64, auto_increment: true
    column :user_id, Int64, null: false
    column :title, String, null: false
    column :content, String
    column :published, Bool, default: false
    column :created_at, Time, null: true
    column :updated_at, Time, null: true

    foreign_key :user_id, references: :users, on_delete: :cascade
  end
end

puts "Schema created with:"
puts "  - Adapter: #{MyAppDB.adapter}"
puts "  - URI: #{MyAppDB.uri}"
puts "  - Tables: #{MyAppDB.tables.keys}"
puts

# Example 6: Configuration Validation
puts "=== Example 6: Configuration Validation ==="

begin
  CQL.configure do |config|
    config.database_url = "" # Invalid: empty URL
    config.pool_size = -1    # Invalid: negative pool size
  end
rescue ex : ArgumentError
  puts "Configuration validation caught error: #{ex.message}"
end
puts

# Example 7: Resetting Configuration (useful for testing)
puts "=== Example 7: Resetting Configuration ==="

puts "Before reset - Database URL: #{CQL.config.database_url}"
CQL.reset_config!
puts "After reset - Database URL: #{CQL.config.database_url}"
puts

# Example 8: Thread-Safe Configuration Access
puts "=== Example 8: Thread-Safe Configuration ==="

# Simulate multiple threads accessing configuration
channel = Channel(String).new

10.times do |i|
  spawn do
    # Each thread can safely access configuration
    url = CQL.config.database_url
    # Access logger to ensure thread-safe configuration access
    _ = CQL.config.effective_logger
    channel.send("Thread #{i}: #{url[0..20]}...")
  end
end

# Collect results from all threads
10.times do
  puts channel.receive
end

puts "\n✅ All configuration examples completed successfully!"
