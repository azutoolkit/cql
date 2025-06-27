require "../../src/cql"

# 💾 Advanced Cache Configuration Example - Updated for New API
# Showcasing the new developer-friendly configuration syntax

puts "=== 💾 CQL Cache Configuration Example ==="

# Basic cache configuration with new syntax
CQL.configure do |config|
  config.db = "sqlite3://./db/cache_example.db"
  config.env = "development"

  # NEW: Simple cache enablement
  config.cache.on = true
  config.cache.ttl = 30.minutes
end

puts "✅ Basic cache configuration applied"

# Environment-specific cache configuration
puts "\n=== 🌍 Environment-Specific Cache Configuration ==="

CQL.configure do |config|
  config.db = "sqlite3://./db/cache_example.db"
  config.env = "production"

  # NEW: Updated cache configuration syntax
  config.cache.on = true
  config.cache.ttl = 45.minutes
  config.cache.memory = true
  config.cache.memory_size = 2000
end

puts "✅ Cache system configured for production environment"

# Test configuration with caching disabled
puts "\n=== 🧪 Test Configuration ==="

["production", "test", "development"].each do |env|
  puts "\n--- #{env.capitalize} Environment ---"

  CQL.configure do |config|
    config.db = "sqlite3://./db/#{env}_cache.db"
    config.env = env

    case env
    when "production"
      # NEW: Production cache settings
      config.cache.on = true # Override default (disabled in production)
      config.cache.ttl = 1.hour
      config.cache.memory_size = 10000
    when "test"
      # NEW: Test cache settings
      config.cache.on = true # Override default (disabled in test)
      config.cache.memory_size = 50
    end
  end

  # Display effective configuration
  puts "  Cache enabled: #{CQL.config.cache.on?}"
  puts "  Max memory cache size: #{CQL.config.cache.memory_size}"
end

# Usage example with new API
puts "\n=== 🚀 Usage Example ==="

CQL.configure do |config|
  config.db = "sqlite3://./db/usage_example.db"
  config.cache.on = true
  config.cache.ttl = 15.minutes
end

puts "✅ Usage example configured"

# Cache usage examples
puts "\n=== 📊 Cache Status ==="
puts "Memory cache created with max size: #{CQL.config.cache.memory_size}"
puts "Cache system status: #{CQL.cache_on? ? "✅ Enabled" : "❌ Disabled"}"

# Error handling example
puts "\n=== ⚠️ Error Handling ==="

begin
  CQL.configure do |config|
    config.cache.on = true
    config.cache.memory_size = -1 # Invalid: negative size
  end
rescue e : ArgumentError
  puts "Configuration error caught: #{e.message}"
end

# Demonstrate cache methods
puts "\n=== 🔧 Cache Management ==="

# Enable cache
CQL.cache_on(true)
puts "Cache enabled: #{CQL.cache_on?}"

# Advanced configuration example
puts "\n=== 🏗️ Advanced Configuration ==="

CQL.configure do |config|
  config.db = "sqlite3://./db/advanced_example.db"
  config.env = "development"

  # Core cache settings
  config.cache.on = true
  config.cache.ttl = 30.minutes
  config.cache.key_prefix = "advanced_demo"

  # Memory cache
  config.cache.memory = true
  config.cache.memory_size = 1000
  config.cache.memory_stats = true

  # Request cache (for web applications)
  config.cache.request_cache = true
  config.cache.request_size = 500
  config.cache.auto_clear = true

  # Fragment cache
  config.cache.fragments = true
  config.cache.fragment_versions = true
  config.cache.fragment_tags = true

  # Invalidation strategy
  config.cache.invalidation = "timestamp"
  config.cache.max_age = 1.hour

  # Monitoring
  config.cache.stats = true
  config.cache.logging = false
end

puts "✅ Advanced cache configuration applied successfully!"

# Display final configuration
puts "\n=== 📋 Final Configuration Summary ==="
final_config = CQL.config.cache
puts "Cache enabled: #{final_config.on?}"
puts "TTL: #{final_config.ttl.total_minutes.to_i} minutes"
puts "Memory cache: #{final_config.memory?}"
puts "Request cache: #{final_config.request_cache?}"
puts "Fragment cache: #{final_config.fragments?}"
puts "Statistics: #{final_config.stats?}"
puts "Invalidation strategy: #{final_config.invalidation}"

# Demonstrate configuration patterns
puts "\n=== 🎯 Common Configuration Patterns ==="

puts "\n1. Development Setup:"
puts "   CQL.configure do |c|"
puts "     c.db = \"postgresql://localhost/myapp\""
puts "     c.cache.on = true"
puts "     c.cache.ttl = 5.minutes"
puts "   end"

puts "\n2. Production Setup:"
puts "   CQL.configure do |c|"
puts "     c.db = ENV[\"DATABASE_URL\"]"
puts "     c.env = \"production\""
puts "     c.cache.on = true"
puts "     c.cache.ttl = 1.hour"
puts "     c.cache.memory_size = 5000"
puts "   end"

puts "\n3. Testing Setup:"
puts "   CQL.configure do |c|"
puts "     c.db = \"sqlite3://:memory:\""
puts "     c.env = \"test\""
puts "     c.cache.on = false  # Disable for tests"
puts "   end"

puts "\n✅ Cache configuration example completed!"
