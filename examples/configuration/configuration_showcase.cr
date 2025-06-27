# 🚀 CQL Configuration Showcase - Developer-Friendly Setup
#
# This example shows how to configure CQL using the new optimized,
# developer-friendly configuration system.

require "../../src/cql"

# === 🎯 QUICK DEVELOPMENT SETUP ===
puts "=== 🎯 Quick Development Setup ==="

CQL.configure do |c|
  # Short, memorable database connection
  c.db = "postgresql://localhost/myapp"

  # Easy log level control
  c.log_level = :debug

  # Schema auto-sync (great for development)
  c.auto_sync = true
end

# === 📊 PRODUCTION CONFIGURATION ===
puts "=== 📊 Production Configuration ==="

CQL.configure do |c|
  # Environment detection
  c.env = "production"

  # Database from environment
  c.db = ENV["DATABASE_URL"]

  # Performance tuning
  c.pool_size = 25
  c.monitor_performance = true

  # Security first
  c.auto_sync = false
  c.verify_schema = true

  # Caching for performance
  c.cache.on = true
  c.cache.ttl = 1.hour
  c.cache.memory_size = 5000
end

# === 💾 CACHE-FOCUSED SETUP ===
puts "=== 💾 Cache-Focused Setup ==="

CQL.configure do |c|
  c.db = "postgresql://localhost/myapp"

  # Quick cache enablement
  c.cache.on = true
  c.cache.ttl = 30.minutes
  c.cache.memory_size = 2000

  # Request-scoped caching (great for web apps)
  c.cache.request_cache = true
  c.cache.request_size = 1000

  # Fragment caching for complex queries
  c.cache.fragments = true
  c.cache.fragment_versions = true

  # Smart invalidation
  c.cache.invalidation = "transaction_aware"
end

# === 🧪 TEST CONFIGURATION ===
puts "=== 🧪 Test Configuration ==="

CQL.configure do |c|
  c.env = "test"
  c.db = "sqlite3://:memory:"
  c.pool_size = 1
  c.auto_sync = true
  c.log_level = :error

  # Disable cache in tests
  c.cache.on = false
end

# === 📈 PERFORMANCE MONITORING ===
puts "=== 📈 Performance Monitoring ==="

CQL.configure do |c|
  c.db = "postgresql://localhost/myapp"

  # Enable monitoring
  c.monitor_performance = true

  # Performance config
  c.performance.query_profiling_enabled = true
  c.performance.n_plus_one_detection_enabled = true
  c.performance.plan_analysis_enabled = true
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
CQL.configure do |c|
  c.db = "postgresql://localhost/myapp"
  c.monitor_performance = true
  c.auto_load = true
  c.auto_sync = true
  c.verify_schema = true
  c.bootstrap = false
  c.migrations_table = :schema_migrations
  c.schema_file = "app_schema.cr"
  c.schema_class = :AppSchema
  c.timezone = :utc
  c.pool_size = 10

  c.cache.on = true
  c.cache.ttl = 30.minutes
  c.cache.memory = true
  c.cache.memory_size = 2000
  c.cache.request_cache = true
  c.cache.invalidation = "timestamp"
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
