require "sqlite3"
require "../src/cql"

# Example 1: Basic Configuration
puts "=== Example 1: Basic Configuration ==="

CQL.configure do |config|
  config.database_url = "postgresql://localhost/myapp_development"
  config.logger = Log.for("MyApp")
  config.default_timezone = :utc
  config.migration_table_name = :schema_migrations
  config.schema_path = "src/schemas"
  config.auto_load_models = true
end

puts "Database URL: #{CQL.config.database_url}"
puts "Timezone: #{CQL.config.default_timezone}"
puts "Auto load models: #{CQL.config.auto_load_models?}"
puts "Pool size: #{CQL.config.connection_pool.size}"
puts

# Example 2: Environment-Specific Configuration
puts "=== Example 2: Environment-Specific Configuration ==="

CQL.configure do |config|
  case ENV["CRYSTAL_ENV"]? || "development"
  when "production"
    config.database_url = ENV["DATABASE_URL"]
    config.logger = Log.for("Production")
    config.auto_load_models = false
    config.connection_pool.size = 25
    config.enable_performance_monitoring = false
  when "test"
    config.database_url = "sqlite3://:memory:"
    config.logger = Log.for("Test")
    config.migration_table_name = :test_schema_migrations
    config.auto_load_models = false
    config.connection_pool.size = 1
  else
    config.database_url = "sqlite3://./db/development.db"
    config.logger = Log.for("Development")
    config.auto_load_models = true
    config.enable_performance_monitoring = true
  end
end

puts "Environment: #{CQL.config.environment}"
puts "Database URL: #{CQL.config.database_url}"
puts "Performance Monitoring: #{CQL.config.enable_performance_monitoring?}"
puts

# Example 3: Advanced Configuration with Performance Monitoring
puts "=== Example 3: Advanced Configuration ==="

CQL.configure do |config|
  config.database_url = "postgresql://localhost/myapp"
  config.connection_pool.size = 15
  config.connection_pool.initial_size = 5
  config.connection_pool.max_idle_size = 8
  config.connection_pool.checkout_timeout = 10.seconds
  config.connection_pool.query_timeout = 30.seconds
  config.enable_query_cache = true
  config.cache_ttl = 2.hours
  config.connection_pool.max_retry_attempts = 3
  config.connection_pool.retry_delay = 1.second
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
puts "Max retry attempts: #{CQL.config.connection_pool.max_retry_attempts}"
puts "Database adapter: #{CQL.config.database_adapter}"
puts

# Example 4: Database-Specific Configuration
puts "=== Example 4: Database-Specific Configuration ==="

# PostgreSQL with SSL configuration
CQL.configure do |config|
  config.database_url = "postgresql://user:pass@localhost/production_db"
  config.ssl.mode = "verify-full"
  config.ssl.cert_path = "/path/to/client.crt"
  config.ssl.key_path = "/path/to/client.key"
  config.ssl.ca_path = "/path/to/ca.crt"
  config.postgresql.auth_methods = "scram-sha-256"
  config.connection_pool.use_prepared_statements = true
end

puts "SSL Mode: #{CQL.config.ssl.mode}"
puts "PostgreSQL Auth Methods: #{CQL.config.postgresql.auth_methods}"
puts "Effective Database URL: #{CQL.config.effective_database_url[0..50]}..."
puts

# Example 5: SQLite Performance Configuration
puts "=== Example 5: SQLite Performance Configuration ==="

CQL.configure do |config|
  config.database_url = "sqlite3://./db/performance.db"
  config.sqlite.journal_mode = "wal"
  config.sqlite.synchronous = "normal"
  config.sqlite.cache_size = -16000 # 16MB cache
  config.sqlite.foreign_keys = true
  config.sqlite.busy_timeout = 10000 # 10 seconds
end

puts "SQLite Journal Mode: #{CQL.config.sqlite.journal_mode}"
puts "SQLite Cache Size: #{CQL.config.sqlite.cache_size} KB"
puts "SQLite Foreign Keys: #{CQL.config.sqlite.foreign_keys?}"
puts

# Example 6: MySQL Configuration with Charset
puts "=== Example 6: MySQL Configuration ==="

CQL.configure do |config|
  config.database_url = "mysql://user:pass@localhost/myapp"
  config.mysql.encoding = "utf8mb4_unicode_ci"
  config.ssl.mode = "required"
  config.connection_pool.size = 20
  config.connection_pool.initial_size = 5
end

puts "MySQL Encoding: #{CQL.config.mysql.encoding}"
puts "Connection Pool: #{CQL.config.connection_pool.initial_size}/#{CQL.config.connection_pool.size} (initial/max)"
puts

# Example 7: Custom Validation
puts "=== Example 7: Custom Validation ==="

class CustomValidator < CQL::Configure::ConfigValidator
  def validate!(config : CQL::Configure::Config) : Nil
    if config.database_url.includes?("password123")
      raise ArgumentError.new("Weak password detected in database URL!")
    end
  end
end

begin
  CQL.configure do |config|
    config.database_url = "mysql://user:password123@localhost/test"
    config.add_validator(CustomValidator.new)
  end
rescue ex : ArgumentError
  puts "Custom validation caught: #{ex.message}"
end
puts

# Example 8: Using Configuration Helpers
puts "=== Example 8: Configuration Helpers ==="

puts "Database URL (helper): #{CQL::ConfigHelpers.database_url}"
puts "Logger (helper): #{CQL::ConfigHelpers.logger}"
puts "Timezone (helper): #{CQL::ConfigHelpers.timezone}"
puts "Environment (helper): #{CQL::ConfigHelpers.environment}"
puts "Auto load models (helper): #{CQL::ConfigHelpers.auto_load_models?}"
puts

# Example 9: Database Schema Using Configuration
puts "=== Example 9: Using Configuration in Schema Definition ==="

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

# Example 10: Configuration Validation
puts "=== Example 10: Configuration Validation ==="

begin
  CQL.configure do |config|
    config.database_url = ""         # Invalid: empty URL
    config.connection_pool.size = -1 # Invalid: negative pool size
  end
rescue ex : ArgumentError
  puts "Configuration validation caught error: #{ex.message}"
end
puts

# Example 11: Resetting Configuration (useful for testing)
puts "=== Example 11: Resetting Configuration ==="

puts "Before reset - Database URL: #{CQL.config.database_url}"
CQL.reset_config!
puts "After reset - Database URL: #{CQL.config.database_url}"
puts

# Example 12: Thread-Safe Configuration Access
puts "=== Example 12: Thread-Safe Configuration ==="

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
