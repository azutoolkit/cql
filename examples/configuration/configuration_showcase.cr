# 🚀 CQL Configuration Showcase - Developer-Friendly Setup
#
# This example shows how to configure CQL using the new optimized,
# developer-friendly configuration system.

require "../../src/cql"

# === 🎯 QUICK DEVELOPMENT SETUP ===
puts "=== 🎯 Quick Development Setup ==="

CQL.configure do |config|
  # Short, memorable database connection
  config.db = "postgresql://localhost/myapp"

  # Easy log level control
  config.log_level = :debug

  # Schema auto-sync (great for development)
  config.auto_sync = true
end

# === 📊 PRODUCTION CONFIGURATION ===
puts "=== 📊 Production Configuration ==="

CQL.configure do |config|
  # Environment detection
  config.env = "production"

  # Database from environment
  config.db = ENV["DATABASE_URL"]

  # Performance tuning
  config.pool_size = 25
  config.monitor_performance = true

  # Security first
  config.auto_sync = false
  config.verify_schema = true

  # Caching for performance
  config.cache.on = true
  config.cache.ttl = 1.hour
  config.cache.memory_size = 5000
end

# === 💾 CACHE-FOCUSED SETUP ===
puts "=== 💾 Cache-Focused Setup ==="

CQL.configure do |config|
  config.db = "postgresql://localhost/myapp"

  # Quick cache enablement
  config.cache.on = true
  config.cache.ttl = 30.minutes
  config.cache.memory_size = 2000

  # Request-scoped caching (great for web apps)
  config.cache.request_cache = true
  config.cache.request_size = 1000

  # Fragment caching for complex queries
  config.cache.fragments = true
  config.cache.fragment_versions = true

  # Smart invalidation
  config.cache.invalidation = "transaction_aware"
end

# === 🧪 TEST CONFIGURATION ===
puts "=== 🧪 Test Configuration ==="

CQL.configure do |config|
  config.env = "test"
  config.db = "sqlite3://:memory:"
  config.pool_size = 1
  config.auto_sync = true
  config.log_level = :error

  # Disable cache in tests
  config.cache.on = false
end

# === 📈 PERFORMANCE MONITORING ===
puts "=== 📈 Performance Monitoring ==="

CQL.configure do |config|
  config.db = "postgresql://localhost/myapp"

  # Enable monitoring and SQL logging
  config.monitor_performance = true
  config.sql_logging = true
  config.sql_logging_colorize = true
end

# === 🔧 BEFORE vs AFTER COMPARISON ===
puts "=== 🔧 Before vs After Comparison ==="

# BEFORE (old verbose syntax):
# ```
# CQL.configure do |config|
#   config.database_url = "postgresql://localhost/myapp"
#   config.enable_performance_monitoring = true
#   config.auto_load_models = true
#   config.enable_auto_schema_sync = true
#   config.verify_schema_on_startup = true
#   config.bootstrap_on_startup = false
#   config.migration_table_name = :schema_migrations
#   config.schema_file_name = "app_schema.cr"
#   config.schema_constant_name = :AppSchema
#   config.default_timezone = :utc
#   config.connection_pool.size = 10
#
#   config.cache.enabled = true
#   config.cache.default_ttl = 30.minutes
#   config.cache.enable_memory_cache = true
#   config.cache.memory_cache_max_size = 2000
#   config.cache.enable_request_cache = true
#   config.cache.invalidation_strategy = "timestamp"
# end
# ```

# AFTER (new developer-friendly syntax):
CQL.configure do |config|
  config.db = "postgresql://localhost/myapp"
  config.monitor_performance = true
  config.auto_load = true
  config.auto_sync = true
  config.verify_schema = true
  config.bootstrap = false
  config.migrations_table = :schema_migrations
  config.schema_file = "app_schema.cr"
  config.schema_class = :AppSchema
  config.timezone = :utc
  config.pool_size = 10

  config.cache.on = true
  config.cache.ttl = 30.minutes
  config.cache.memory = true
  config.cache.memory_size = 2000
  config.cache.request_cache = true
  config.cache.invalidation = "timestamp"
end

# === 🌟 BENEFITS OF NEW CONFIGURATION ===
puts <<-BENEFITS
=== 🌟 Benefits of the New Configuration ===

✅ Shorter property names (db vs database_url)
✅ Memorable syntax (on vs enabled)
✅ Better organization with emojis and sections
✅ Consistent naming patterns
✅ Intuitive boolean helpers (cache.on? vs cache.enabled?)
✅ Cleaner method names (build_schema vs create_schema)
✅ Smart defaults based on environment
✅ Better documentation with real-world examples

📏 Comparison:
   Old: config.enable_auto_schema_sync = true
   New: c.auto_sync = true

📦 Cache Configuration:
   Old: config.cache.enable_memory_cache = true
   New: c.cache.memory = true

🔍 Helper Methods:
   Old: config.enable_performance_monitoring?
   New: config.monitor_performance?

BENEFITS

puts "✅ Configuration showcase complete!"
