# 🎯 CQL Configuration Guide - Updated API

Welcome to the CQL configuration system! This guide covers the new developer-friendly configuration API that makes setting up CQL intuitive and memorable.

## 🚀 Quick Start

The simplest way to configure CQL:

```crystal
CQL.configure do |c|
  c.db = "postgresql://localhost/myapp"
  c.log_level = :debug
  c.auto_sync = true
end
```

## 📋 Core Configuration Properties

The configuration system is organized into logical sections for better developer experience:

### 🔌 Database Connection

| Property          | Type                   | Default                                   | Description                           |
| ----------------- | ---------------------- | ----------------------------------------- | ------------------------------------- |
| `db`              | `String`               | `"sqlite3://./db/development.db"`         | Database connection URL               |
| `env`             | `String`               | `ENV["CRYSTAL_ENV"]` \|\| `"development"` | Environment name                      |
| `timezone`        | `Symbol`               | `:utc`                                    | Default timezone (`:utc` or `:local`) |
| `adapter_options` | `Hash(String, String)` | `{}`                                      | Custom database adapter settings      |

### 📋 Logging

| Property    | Type            | Default            | Description                 |
| ----------- | --------------- | ------------------ | --------------------------- |
| `logger`    | `Log`           | `Log.for("cql.*")` | Application logger instance |
| `log_level` | `Log::Severity` | `:info`            | Log level shortcut          |

### 🗂️ Schema & Migrations

| Property           | Type     | Default              | Description                       |
| ------------------ | -------- | -------------------- | --------------------------------- |
| `schema_dir`       | `String` | `"src/schemas"`      | Directory containing schema files |
| `schema_file`      | `String` | `"app_schema.cr"`    | Main schema file name             |
| `schema_class`     | `Symbol` | `:AppSchema`         | Schema class name in Crystal code |
| `schema_name`      | `Symbol` | `:app_schema`        | Schema instance symbol            |
| `migrations_table` | `Symbol` | `:schema_migrations` | Migration tracking table          |

### ⚡ Behavior Flags

| Property        | Type   | Default | Description                                       |
| --------------- | ------ | ------- | ------------------------------------------------- |
| `auto_load`     | `Bool` | `true`  | Auto-load model files on startup                  |
| `auto_sync`     | `Bool` | `true`  | Keep schema file in sync with database            |
| `bootstrap`     | `Bool` | `false` | Create schema from existing database on first run |
| `verify_schema` | `Bool` | `false` | Verify schema matches database on startup         |

### 📊 Performance

| Property              | Type                | Default | Description                         |
| --------------------- | ------------------- | ------- | ----------------------------------- |
| `monitor_performance` | `Bool`              | `false` | Enable query performance monitoring |
| `performance`         | `PerformanceConfig` | -       | Detailed performance settings       |

### 🔗 Connection Pool

| Property    | Type                   | Default | Description                    |
| ----------- | ---------------------- | ------- | ------------------------------ |
| `pool_size` | `Int32`                | `10`    | Number of database connections |
| `pool`      | `ConnectionPoolConfig` | -       | Detailed pool settings         |

## 🌍 Environment-Specific Configuration

CQL automatically applies smart defaults based on your environment:

### Development

```crystal
CQL.configure do |c|
  c.env = "development"
  c.monitor_performance = true
  c.pool_size = 5
  c.auto_sync = true
  c.verify_schema = true
  c.log_level = :debug
end
```

### Test

```crystal
CQL.configure do |c|
  c.env = "test"
  c.db = "sqlite3://:memory:"
  c.migrations_table = :test_migrations
  c.pool_size = 1
  c.auto_sync = true
  c.log_level = :error
end
```

### Production

```crystal
CQL.configure do |c|
  c.env = "production"
  c.pool_size = 25
  c.auto_sync = false
  c.verify_schema = true
  c.log_level = :info
end
```

## 💾 Cache Configuration

Enable caching with the new simplified syntax:

```crystal
CQL.configure do |c|
  c.db = "postgresql://localhost/myapp"

  # Quick cache setup
  c.cache.on = true
  c.cache.ttl = 30.minutes
  c.cache.memory_size = 2000

  # Request-scoped caching
  c.cache.request_cache = true
  c.cache.request_size = 1000

  # Fragment caching
  c.cache.fragments = true
  c.cache.invalidation = "transaction_aware"
end
```

## 🔧 Advanced Configuration

### Custom Connection Pool

```crystal
CQL.configure do |c|
  c.pool_size = 20
  c.pool.initial_size = 5
  c.pool.max_idle_size = 10
  c.pool.checkout_timeout = 15.seconds
end
```

### Performance Monitoring

```crystal
CQL.configure do |c|
  c.monitor_performance = true
  c.performance.query_profiling_enabled = true
  c.performance.n_plus_one_detection_enabled = true
end
```

## 🔍 Helper Methods

The new configuration system provides intuitive boolean helpers:

```crystal
config = CQL.config

# Check configuration state
puts config.auto_sync?           # true/false
puts config.monitor_performance? # true/false
puts config.bootstrap?           # true/false
puts config.cache.on?            # true/false

# Get computed values
puts config.adapter              # :postgres, :mysql, :sqlite
puts config.full_db_url         # Complete URL with all settings
puts config.schema_path          # Full path to schema file
```

## 🌟 Migration from Old API

**Before (old verbose syntax):**

```crystal
CQL.configure do |config|
  config.database_url = "postgresql://localhost/myapp"
  config.enable_performance_monitoring = true
  config.auto_load_models = true
  config.enable_auto_schema_sync = true
  config.verify_schema_on_startup = true
  config.migration_table_name = :schema_migrations
  config.connection_pool.size = 10

  config.cache.enabled = true
  config.cache.default_ttl = 30.minutes
  config.cache.enable_memory_cache = true
end
```

**After (new developer-friendly syntax):**

```crystal
CQL.configure do |c|
  c.db = "postgresql://localhost/myapp"
  c.monitor_performance = true
  c.auto_load = true
  c.auto_sync = true
  c.verify_schema = true
  c.migrations_table = :schema_migrations
  c.pool_size = 10

  c.cache.on = true
  c.cache.ttl = 30.minutes
  c.cache.memory = true
end
```

## 🛠️ Configuration Methods

### Basic Configuration

```crystal
# Main configuration method
CQL.configure do |c|
  c.db = "postgresql://localhost/myapp"
  c.auto_sync = true
end

# Access current configuration
config = CQL.config
puts config.db
```

### Migrator Configuration

```crystal
# Create migrator config from current settings
migrator_config = CQL.migrator_config

# Environment-specific migrator config
dev_config = CQL.migrator_config_for("development")
prod_config = CQL.migrator_config_for("production")
```

### Cache Management

```crystal
# Quick cache control
CQL.cache_on(true)              # Enable cache
puts CQL.cache_on?              # Check if enabled
puts CQL.cache_stats            # Get statistics
puts CQL.cache_summary          # Performance summary
CQL.reset_cache!                # Reset stats
```

## ✅ Configuration Validation

CQL validates your configuration and provides helpful error messages:

```crystal
CQL.configure do |c|
  c.db = ""                     # Error: db cannot be empty
  c.pool_size = -1              # Error: pool_size must be positive
  c.schema_file = "invalid"     # Error: must end with .cr extension
  c.timezone = :invalid         # Error: must be :utc or :local
end
```

## 🎯 Best Practices

1. **Use short variable name**: `|c|` instead of `|config|` for cleaner code
2. **Group related settings**: Configure database, cache, and performance together
3. **Environment-aware defaults**: Let CQL apply smart defaults for your environment
4. **Use boolean helpers**: `c.auto_sync?` instead of checking raw values
5. **Leverage shortcuts**: `c.pool_size = 10` instead of `c.pool.size = 10`

The new configuration system makes CQL easier to use while maintaining all the power and flexibility you need!
