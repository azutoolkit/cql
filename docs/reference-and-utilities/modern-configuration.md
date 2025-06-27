# 🎯 CQL Configuration - Developer Guide

Get CQL configured quickly with the modern, intuitive API. This guide focuses on practical examples and common use cases.

## Quick Start

```crystal
# Minimal setup
CQL.configure do |c|
  c.db = "postgresql://localhost/myapp"
end

# Development setup
CQL.configure do |c|
  c.db = "postgresql://localhost/myapp"
  c.log_level = :debug
  c.auto_sync = true
  c.cache.on = true
end

# Production setup
CQL.configure do |c|
  c.db = ENV["DATABASE_URL"]
  c.env = "production"
  c.pool_size = 25
  c.monitor_performance = true
  c.cache.on = true
  c.cache.ttl = 1.hour
end
```

## Core Settings

### Database Connection

```crystal
CQL.configure do |c|
  c.db = "postgresql://localhost/myapp"     # Connection URL
  c.env = "development"                     # Environment
  c.timezone = :utc                         # Timezone (:utc or :local)
  c.pool_size = 10                          # Connection pool size
end
```

**Supported databases:**

- PostgreSQL: `postgresql://localhost/myapp`
- MySQL: `mysql://localhost/myapp`
- SQLite: `sqlite3://./db/app.db`

### Logging

```crystal
CQL.configure do |c|
  c.log_level = :debug              # :debug, :info, :warn, :error
  c.logger = Log.for("myapp")       # Custom logger
end
```

### Schema & Migrations

```crystal
CQL.configure do |c|
  c.schema_dir = "src/schemas"              # Schema directory
  c.schema_file = "app_schema.cr"           # Schema file name
  c.schema_class = :AppSchema               # Class name
  c.schema_name = :app_schema               # Instance name
  c.migrations_table = :schema_migrations   # Migration tracking table
end
```

### Behavior Flags

```crystal
CQL.configure do |c|
  c.auto_load = true        # Auto-load model files
  c.auto_sync = true        # Keep schema in sync
  c.bootstrap = false       # Create schema from existing DB
  c.verify_schema = false   # Verify schema matches DB
end
```

## Environment Configuration

CQL automatically applies smart defaults based on your environment:

### Development

```crystal
CQL.configure do |c|
  c.env = "development"
  # Defaults: debug logging, auto_sync = true, small pool
end
```

### Test

```crystal
CQL.configure do |c|
  c.env = "test"
  c.db = "sqlite3://:memory:"
  # Defaults: error logging, auto_sync = true, minimal pool
end
```

### Production

```crystal
CQL.configure do |c|
  c.env = "production"
  c.db = ENV["DATABASE_URL"]
  c.pool_size = 25
  c.auto_sync = false       # Don't auto-modify schema in production
end
```

## Cache Configuration

### Basic Caching

```crystal
CQL.configure do |c|
  c.cache.on = true                 # Enable caching
  c.cache.ttl = 30.minutes         # Default cache time
  c.cache.memory_size = 2000       # Max entries in memory
end
```

### Advanced Caching

```crystal
CQL.configure do |c|
  c.cache.on = true
  c.cache.ttl = 1.hour
  c.cache.memory_size = 5000

  # Request-scoped caching (for web apps)
  c.cache.request_cache = true
  c.cache.request_size = 1000

  # Fragment caching
  c.cache.fragments = true
  c.cache.invalidation = "transaction_aware"
end
```

### Redis Caching

```crystal
CQL.configure do |c|
  c.cache.on = true
  c.cache.store = "redis"
  c.cache.redis_url = "redis://localhost:6379/0"
  c.cache.redis_pool_size = 25
end
```

## Performance Monitoring

```crystal
CQL.configure do |c|
  c.monitor_performance = true

  # Fine-tune monitoring
  c.performance.query_profiling_enabled = true
  c.performance.n_plus_one_detection_enabled = true
  c.performance.plan_analysis_enabled = true
end
```

## Connection Pool

```crystal
CQL.configure do |c|
  c.pool_size = 20                          # Main setting

  # Advanced pool settings
  c.pool.initial_size = 5
  c.pool.max_idle_size = 10
  c.pool.checkout_timeout = 15.seconds
end
```

## SSL Configuration

```crystal
CQL.configure do |c|
  c.ssl.mode = :require
  c.ssl.cert_file = "client.crt"
  c.ssl.key_file = "client.key"
  c.ssl.ca_file = "ca.crt"
end
```

## Helpful Methods

```crystal
config = CQL.config

# Check settings
config.auto_sync?           # true/false
config.monitor_performance? # true/false
config.cache.on?           # true/false

# Get computed values
config.adapter             # :postgres, :mysql, :sqlite
config.full_db_url        # Complete URL with settings
config.schema_path         # Full path to schema file
```

## Complete Example

```crystal
CQL.configure do |c|
  # Database
  c.db = ENV["DATABASE_URL"] || "postgresql://localhost/myapp"
  c.env = ENV["CRYSTAL_ENV"] || "development"
  c.pool_size = ENV["DB_POOL_SIZE"]?.try(&.to_i) || 10

  # Schema
  c.auto_sync = c.env != "production"
  c.verify_schema = true

  # Logging
  c.log_level = c.env == "production" ? :info : :debug

  # Performance
  c.monitor_performance = c.env != "test"

  # Caching
  c.cache.on = true
  c.cache.ttl = c.env == "production" ? 1.hour : 5.minutes
  c.cache.memory_size = c.env == "production" ? 10000 : 1000
  c.cache.request_cache = true

  # Redis in production
  if c.env == "production" && ENV["REDIS_URL"]?
    c.cache.store = "redis"
    c.cache.redis_url = ENV["REDIS_URL"]
  end
end
```

## Schema & Migration Helpers

```crystal
# Create schema with current configuration
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
dev_migrator = CQL.migrator_config_for("development")
```

## Cache Management

```crystal
# Control cache
CQL.cache_on(true)          # Enable
CQL.cache_on?               # Check status
CQL.reset_cache!            # Clear stats

# Get performance info
puts CQL.cache_stats        # Detailed stats
puts CQL.cache_summary      # Human-readable summary

# Request-scoped caching (for web apps)
CQL.with_request_cache do
  # Database queries here are cached per-request
  User.all
  Post.recent
end
```

## Best Practices

1. **Use environment variables** for sensitive settings like database URLs
2. **Different settings per environment** - development vs production
3. **Enable caching early** - it's safe and improves performance
4. **Monitor in development** - disable monitoring in test
5. **Auto-sync in development only** - never in production
6. **Use request caching** for web applications
7. **Start with memory cache** - upgrade to Redis when needed

## Migration from Old API

**Old:**

```crystal
CQL.configure do |config|
  config.database_url = "postgresql://localhost/myapp"
  config.enable_performance_monitoring = true
  config.cache.enabled = true
  config.cache.default_ttl = 30.minutes
end
```

**New:**

```crystal
CQL.configure do |c|
  c.db = "postgresql://localhost/myapp"
  c.monitor_performance = true
  c.cache.on = true
  c.cache.ttl = 30.minutes
end
```

The new API is shorter, more memorable, and easier to type!
