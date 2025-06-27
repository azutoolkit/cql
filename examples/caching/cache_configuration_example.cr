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

puts "Cache system configured for production environment"

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

# Schema would be created here with caching enabled

# Cache usage examples
puts "\n=== 📊 Cache Statistics ==="
puts "Memory cache created with max size: #{CQL.config.cache.memory_size}"
puts "Cache system status: #{CQL.cache_on? ? "✅ Enabled" : "❌ Disabled"}"
puts "Cache statistics: #{CQL.cache_stats}"

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

puts "\n✅ Cache configuration example completed!"
