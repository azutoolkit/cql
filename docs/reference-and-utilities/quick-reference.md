# 🚀 CQL Quick Reference

Essential CQL configuration and caching patterns for quick copy-paste.

## Basic Setup

```crystal
# Minimal
CQL.configure do |c|
  c.db = "postgresql://localhost/myapp"
end

# Development
CQL.configure do |c|
  c.db = "postgresql://localhost/myapp"
  c.log_level = :debug
  c.auto_sync = true
  c.cache.on = true
end

# Production
CQL.configure do |c|
  c.db = ENV["DATABASE_URL"]
  c.env = "production"
  c.pool_size = 25
  c.monitor_performance = true
  c.auto_sync = false
  c.cache.on = true
  c.cache.store = "redis"
  c.cache.redis_url = ENV["REDIS_URL"]
end
```

## Configuration Properties

```crystal
CQL.configure do |c|
  # Database
  c.db = "postgresql://localhost/myapp"
  c.env = "development"
  c.timezone = :utc
  c.pool_size = 10

  # Schema
  c.schema_dir = "src/schemas"
  c.schema_file = "app_schema.cr"
  c.schema_class = :AppSchema
  c.auto_sync = true
  c.verify_schema = true

  # Logging
  c.log_level = :debug
  c.logger = Log.for("myapp")

  # Performance
  c.monitor_performance = true

  # Cache
  c.cache.on = true
  c.cache.ttl = 30.minutes
  c.cache.memory_size = 2000
  c.cache.request_cache = true
end
```

## Cache Configuration

```crystal
# Memory cache (default)
c.cache.on = true
c.cache.ttl = 1.hour
c.cache.memory_size = 5000

# Redis cache
c.cache.on = true
c.cache.store = "redis"
c.cache.redis_url = "redis://localhost:6379/0"
c.cache.redis_pool_size = 25

# Request caching
c.cache.request_cache = true
c.cache.request_size = 1000

# Fragment caching
c.cache.fragments = true
c.cache.invalidation = "transaction_aware"
```

## Environment Patterns

```crystal
# Environment-based configuration
CQL.configure do |c|
  c.db = ENV["DATABASE_URL"] || "postgresql://localhost/myapp"
  c.env = ENV["CRYSTAL_ENV"] || "development"
  c.pool_size = ENV["DB_POOL_SIZE"]?.try(&.to_i) || 10

  # Cache settings per environment
  c.cache.on = true
  c.cache.ttl = c.env == "production" ? 1.hour : 5.minutes
  c.cache.memory_size = c.env == "production" ? 10000 : 1000

  # Redis in production
  if c.env == "production" && ENV["REDIS_URL"]?
    c.cache.store = "redis"
    c.cache.redis_url = ENV["REDIS_URL"]
  end

  # Performance monitoring in development
  c.monitor_performance = c.env != "test"

  # Auto-sync except in production
  c.auto_sync = c.env != "production"
end
```

## Web Framework Integration

### Kemal

```crystal
require "cql/cache/middleware"

before_all do |env|
  CQL.start_request_cache
end

after_all do |env|
  CQL.end_request_cache
end
```

### Lucky

```crystal
abstract class ApplicationAction < Lucky::Action
  include CQL::Cache::Middleware::Lucky
end
```

### Manual Request Caching

```crystal
CQL.with_request_cache do
  # All queries here share per-request cache
  user = User.find(1)
  posts = user.posts
end
```

## Cache Management

```crystal
# Control
CQL.cache_on(true)              # Enable
CQL.cache_on(false)             # Disable
CQL.cache_on?                   # Check status

# Statistics
stats = CQL.cache_stats
puts "Hit rate: #{stats["hit_rate_percent"]}%"
puts CQL.cache_summary          # Human-readable summary

# Clear
CQL.reset_cache!                # Clear stats
CQL.memory_cache.clear          # Clear data
```

## Fragment Caching

```crystal
# Setup
c.cache.fragments = true

# Usage
fragment_cache = CQL.fragment_cache

result = fragment_cache.cache_fragment(
  fragment_name: "expensive_operation",
  params: {"user_id" => user.id.to_s},
  tags: ["user:#{user.id}"],
  ttl: 1.hour
) do
  # Expensive calculation here
  calculate_user_stats(user)
end

# Invalidate
fragment_cache.invalidate_tags(["user:#{user.id}"])
```

## Database URLs

```crystal
# PostgreSQL
c.db = "postgresql://localhost/myapp"
c.db = "postgresql://user:pass@localhost/myapp"
c.db = "postgresql://user:pass@localhost:5432/myapp"

# MySQL
c.db = "mysql://localhost/myapp"
c.db = "mysql://user:pass@localhost/myapp"

# SQLite
c.db = "sqlite3://./db/app.db"
c.db = "sqlite3://:memory:"
```

## Helper Methods

```crystal
config = CQL.config

# Boolean checks
config.auto_sync?
config.monitor_performance?
config.cache.on?

# Computed values
config.adapter              # :postgres, :mysql, :sqlite
config.full_db_url         # Complete URL
config.schema_path          # Full path to schema
```

## Schema Management

```crystal
# Create schema
schema = CQL.build_schema(:app) do
  table :users do
    primary_key :id
    text :name
    timestamps
  end
end

# Create migrator
migrator = CQL.build_migrator(schema)

# Environment-specific migrator
dev_config = CQL.migrator_config_for("development")
```

## Common Patterns

### Complete E-commerce Setup

```crystal
CQL.configure do |c|
  c.db = ENV["DATABASE_URL"]
  c.env = ENV["CRYSTAL_ENV"] || "production"
  c.pool_size = 25

  # Cache for product catalog
  c.cache.on = true
  c.cache.store = "redis"
  c.cache.redis_url = ENV["REDIS_URL"]
  c.cache.ttl = 15.minutes      # Products change frequently
  c.cache.memory_size = 50000   # Large catalog
  c.cache.request_cache = true  # Web app
  c.cache.fragments = true      # Category trees

  # Performance monitoring
  c.monitor_performance = true

  # Production safety
  c.auto_sync = false
  c.verify_schema = true
end
```

### Blog/CMS Setup

```crystal
CQL.configure do |c|
  c.db = ENV["DATABASE_URL"] || "postgresql://localhost/blog"
  c.env = ENV["CRYSTAL_ENV"] || "development"

  # Cache for content
  c.cache.on = true
  c.cache.ttl = 2.hours         # Content doesn't change often
  c.cache.request_cache = true
  c.cache.fragments = true
  c.cache.invalidation = "version"  # Precise invalidation

  # Environment-specific
  if c.env == "production"
    c.cache.store = "redis"
    c.cache.redis_url = ENV["REDIS_URL"]
    c.pool_size = 20
    c.auto_sync = false
  else
    c.auto_sync = true
    c.log_level = :debug
  end
end
```

### API Service Setup

```crystal
CQL.configure do |c|
  c.db = ENV["DATABASE_URL"]
  c.env = "production"
  c.pool_size = 30

  # Shared cache across instances
  c.cache.on = true
  c.cache.store = "redis"
  c.cache.redis_url = ENV["REDIS_URL"]
  c.cache.ttl = 10.minutes
  c.cache.request_cache = false  # No request lifecycle
  c.cache.key_prefix = "api"

  # API optimizations
  c.monitor_performance = true
  c.auto_sync = false
  c.log_level = :info
end
```

## Troubleshooting

```crystal
# Check cache status
puts "Cache enabled: #{CQL.cache_on?}"
puts "Config cache: #{CQL.config.cache.on?}"

# Check statistics
stats = CQL.cache_stats
puts "Requests: #{stats["total_requests"]}"
puts "Hit rate: #{stats["hit_rate_percent"]}%"
puts "Memory: #{stats["memory_usage_bytes"]} bytes"

# Test Redis connection
if redis = CQL.cache_store.as?(CQL::Cache::RedisCache)
  puts "Redis ping: #{redis.ping}"
end

# Validate configuration
begin
  CQL.config.validate!
  puts "Configuration is valid"
rescue ex
  puts "Configuration error: #{ex.message}"
end
```

## Performance Tips

- **Enable caching early** - it's safe and improves performance
- **Use request caching** for web apps - eliminates duplicate queries
- **Start with memory cache** - upgrade to Redis when needed
- **Set appropriate TTLs** - balance freshness vs performance
- **Monitor hit rates** - should be >60% for good cache usage
- **Use fragment caching** for expensive operations
- **Tag fragments properly** - enables precise invalidation

## Environment Variables

```bash
# Database
DATABASE_URL=postgresql://localhost/myapp
CRYSTAL_ENV=production
DB_POOL_SIZE=25

# Cache
REDIS_URL=redis://localhost:6379/0
CQL_CACHE_TTL=3600

# Performance
CQL_MONITOR_PERFORMANCE=true
```
