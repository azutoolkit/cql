# Configuration Example

A comprehensive demonstration of CQL's configuration system, showing how to set up database connections, environment-specific settings, and advanced configuration options.

## 🎯 What You'll Learn

This example teaches you how to:

- **Configure CQL** with different database adapters
- **Set environment-specific** configurations
- **Manage connection pooling** for optimal performance
- **Configure SSL/TLS** for secure connections
- **Set up performance monitoring** with custom settings
- **Validate configuration** with custom validators
- **Use configuration helpers** for common operations
- **Integrate configuration** with schema definitions

## 🚀 Quick Start

```bash
# Run the configuration example
crystal examples/configure_example.cr
```

## 📁 Code Structure

```
examples/
├── configure_example.cr          # Main configuration example
└── generated_schema.cr           # Auto-generated schema file
```

## 🔧 Key Features

### 1. Basic Configuration

```crystal
CQL.configure do |config|
  config.database_url = "postgresql://localhost/myapp_development"
  config.logger = Log.for("MyApp")
  config.default_timezone = :utc
  config.auto_load_models = true
end
```

### 2. Environment-Specific Configuration

```crystal
CQL.configure do |config|
  case ENV["CRYSTAL_ENV"]? || "development"
  when "production"
    config.database_url = ENV["DATABASE_URL"]
    config.connection_pool.size = 25
    config.enable_performance_monitoring = false
  when "test"
    config.database_url = "sqlite3://:memory:"
    config.connection_pool.size = 1
  else
    config.database_url = "sqlite3://./db/development.db"
    config.enable_performance_monitoring = true
  end
end
```

### 3. Advanced Configuration with Performance Monitoring

```crystal
CQL.configure do |config|
  config.database_url = "postgresql://localhost/myapp"
  config.connection_pool.size = 15
  config.connection_pool.initial_size = 5
  config.connection_pool.max_idle_size = 8
  config.connection_pool.checkout_timeout = 10.seconds
  config.enable_query_cache = true
  config.cache_ttl = 2.hours
  config.enable_performance_monitoring = true

  # Configure performance monitoring
  perf_config = CQL::Performance::PerformanceConfig.new
  perf_config.query_profiling_enabled = true
  perf_config.n_plus_one_detection_enabled = true
  config.performance_config = perf_config
end
```

## 📊 Configuration Examples

### Database-Specific Configuration

#### PostgreSQL with SSL

```crystal
CQL.configure do |config|
  config.database_url = "postgresql://user:pass@localhost/production_db"
  config.ssl.mode = "verify-full"
  config.ssl.cert_path = "/path/to/client.crt"
  config.ssl.key_path = "/path/to/client.key"
  config.ssl.ca_path = "/path/to/ca.crt"
  config.postgresql.auth_methods = "scram-sha-256"
  config.connection_pool.use_prepared_statements = true
end
```

#### SQLite Performance Configuration

```crystal
CQL.configure do |config|
  config.database_url = "sqlite3://./db/performance.db"
  config.sqlite.journal_mode = "wal"
  config.sqlite.synchronous = "normal"
  config.sqlite.cache_size = -16000 # 16MB cache
  config.sqlite.foreign_keys = true
  config.sqlite.busy_timeout = 10000 # 10 seconds
end
```

#### MySQL Configuration

```crystal
CQL.configure do |config|
  config.database_url = "mysql://user:pass@localhost/myapp"
  config.mysql.encoding = "utf8mb4_unicode_ci"
  config.ssl.mode = "required"
  config.connection_pool.size = 20
  config.connection_pool.initial_size = 5
end
```

### Connection Pooling Configuration

```crystal
CQL.configure do |config|
  config.connection_pool.size = 20
  config.connection_pool.initial_size = 5
  config.connection_pool.max_idle_size = 10
  config.connection_pool.checkout_timeout = 10.seconds
  config.connection_pool.query_timeout = 30.seconds
  config.connection_pool.max_retry_attempts = 3
  config.connection_pool.retry_delay = 1.second
  config.connection_pool.use_prepared_statements = true
end
```

### Custom Validation

```crystal
class CustomValidator < CQL::Configure::ConfigValidator
  def validate!(config : CQL::Configure::Config) : Nil
    if config.database_url.includes?("password123")
      raise ArgumentError.new("Weak password detected in database URL!")
    end
  end
end

CQL.configure do |config|
  config.database_url = "mysql://user:password123@localhost/test"
  config.add_validator(CustomValidator.new)
end
```

## 🏗️ Configuration Architecture

```mermaid
graph TB
    subgraph "Configuration System"
        A[CQL.configure] --> B[Config Object]
        B --> C[Validation]
        C --> D[Environment Detection]
        D --> E[Default Application]
    end

    subgraph "Composed Objects"
        F[Connection Pool Config]
        G[SSL Config]
        H[Database Config]
        I[Performance Config]
    end

    B --> F
    B --> G
    B --> H
    B --> I

    subgraph "Database Adapters"
        J[PostgreSQL]
        K[MySQL]
        L[SQLite]
    end

    H --> J
    H --> K
    H --> L
```

## 🔧 Configuration Options

### Core Settings

| Option             | Type   | Default                           | Description             |
| ------------------ | ------ | --------------------------------- | ----------------------- |
| `database_url`     | String | `"sqlite3://./db/development.db"` | Database connection URL |
| `logger`           | Log    | Environment-based                 | Logger instance         |
| `default_timezone` | Symbol | `:utc`                            | Default timezone        |
| `environment`      | String | `ENV["CRYSTAL_ENV"]`              | Application environment |

### Migration Settings

| Option                    | Type   | Default                  | Description                 |
| ------------------------- | ------ | ------------------------ | --------------------------- |
| `migration_table_name`    | Symbol | `:cql_schema_migrations` | Migration tracking table    |
| `schema_path`             | String | `"src/schemas"`          | Schema file path            |
| `schema_file_name`        | String | `"app_schema.cr"`        | Schema file name            |
| `enable_auto_schema_sync` | Bool   | `true`                   | Auto schema synchronization |

### Performance Settings

| Option                          | Type       | Default  | Description                   |
| ------------------------------- | ---------- | -------- | ----------------------------- |
| `enable_query_cache`            | Bool       | `false`  | Enable query caching          |
| `cache_ttl`                     | Time::Span | `1.hour` | Cache time-to-live            |
| `enable_performance_monitoring` | Bool       | `false`  | Enable performance monitoring |

### Connection Pool Settings

| Option             | Type       | Default      | Description                 |
| ------------------ | ---------- | ------------ | --------------------------- |
| `size`             | Int32      | `10`         | Maximum pool size           |
| `initial_size`     | Int32      | `1`          | Initial pool size           |
| `max_idle_size`    | Int32      | `1`          | Maximum idle connections    |
| `checkout_timeout` | Time::Span | `10.seconds` | Connection checkout timeout |

## 🎯 Environment-Specific Patterns

### Development Environment

```crystal
CQL.configure do |config|
  config.environment = "development"
  config.database_url = "sqlite3://./db/development.db"
  config.enable_performance_monitoring = true
  config.connection_pool.size = 5
  config.auto_load_models = true
  config.enable_auto_schema_sync = true
  config.verify_schema_on_startup = true
end
```

### Test Environment

```crystal
CQL.configure do |config|
  config.environment = "test"
  config.database_url = "sqlite3://:memory:"
  config.migration_table_name = :test_schema_migrations
  config.auto_load_models = false
  config.connection_pool.size = 1
  config.schema_file_name = "test_schema.cr"
  config.schema_constant_name = :TestSchema
end
```

### Production Environment

```crystal
CQL.configure do |config|
  config.environment = "production"
  config.database_url = ENV["DATABASE_URL"]
  config.auto_load_models = false
  config.connection_pool.size = 25
  config.connection_pool.initial_size = 5
  config.connection_pool.max_idle_size = 10
  config.connection_pool.checkout_timeout = 15.seconds
  config.ssl.mode = "require"
  config.enable_auto_schema_sync = false
  config.verify_schema_on_startup = true
end
```

## 🔧 Configuration Helpers

### Using Configuration Helpers

```crystal
# Access configuration through helpers
puts "Database URL: #{CQL::ConfigHelpers.database_url}"
puts "Logger: #{CQL::ConfigHelpers.logger}"
puts "Timezone: #{CQL::ConfigHelpers.timezone}"
puts "Environment: #{CQL::ConfigHelpers.environment}"
puts "Auto load models: #{CQL::ConfigHelpers.auto_load_models?}"
```

### Schema Integration

```crystal
# Use configuration in schema definition
MyAppDB = CQL::Schema.define(
  :myapp_db,
  adapter: CQL.config.database_adapter,
  uri: CQL.config.database_url
) do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String, null: false
    column :email, String, null: false
    timestamps
  end
end
```

## 🧪 Testing Configuration

### Reset Configuration for Testing

```crystal
# Reset configuration to defaults
CQL.reset_config!

# Configure for testing
CQL.configure do |config|
  config.database_url = "sqlite3://:memory:"
  config.migration_table_name = :test_schema_migrations
  config.auto_load_models = false
end
```

### Thread-Safe Configuration Access

```crystal
# Multiple threads can safely access configuration
channel = Channel(String).new

10.times do |i|
  spawn do
    url = CQL.config.database_url
    logger = CQL.config.effective_logger
    channel.send("Thread #{i}: configured")
  end
end

# All threads will receive consistent configuration
10.times do
  puts channel.receive
end
```

## 📊 Configuration Validation

### Built-in Validation

```crystal
begin
  CQL.configure do |config|
    config.database_url = ""      # Invalid: empty URL
    config.connection_pool.size = -1  # Invalid: negative pool size
    config.default_timezone = :invalid # Invalid: unsupported timezone
  end
rescue ArgumentError => ex
  puts "Configuration error: #{ex.message}"
end
```

### Custom Validation

```crystal
class ProductionValidator < CQL::Configure::ConfigValidator
  def validate!(config : CQL::Configure::Config) : Nil
    if config.environment == "production"
      raise ArgumentError.new("DATABASE_URL required in production") if config.database_url.empty?
      raise ArgumentError.new("Pool size too small for production") if config.connection_pool.size < 10
      raise ArgumentError.new("Performance monitoring should be disabled in production") if config.enable_performance_monitoring?
    end
  end
end

CQL.configure do |config|
  config.environment = "production"
  config.add_validator(ProductionValidator.new)
end
```

## 🎯 Best Practices

### 1. Configure Early

```crystal
# ✅ Good: Configure first
CQL.configure do |config|
  config.database_url = "postgresql://localhost/myapp"
end

MyAppDB = CQL::Schema.define(:app, adapter: CQL.config.database_adapter, uri: CQL.config.database_url)

# ❌ Bad: Configure after schema definition
MyAppDB = CQL::Schema.define(:app, adapter: CQL::Adapter::Postgres, uri: "postgresql://localhost/myapp")

CQL.configure do |config|
  config.database_url = "postgresql://localhost/myapp"  # Won't affect already defined schema
end
```

### 2. Use Environment Variables

```crystal
CQL.configure do |config|
  config.database_url = ENV["DATABASE_URL"]? || "sqlite3://./db/development.db"
  config.connection_pool.size = ENV["DB_POOL_SIZE"]?.try(&.to_i) || 10
  config.enable_performance_monitoring = ENV["PERFORMANCE_MONITORING"]? == "true"
end
```

### 3. Separate Configuration by Environment

```crystal
# config/database.cr
case ENV["CRYSTAL_ENV"]? || "development"
when "production"
  require "./production"
when "test"
  require "./test"
else
  require "./development"
end

# config/production.cr
CQL.configure do |config|
  config.database_url = ENV["DATABASE_URL"]
  config.connection_pool.size = 25
  config.auto_load_models = false
  config.enable_performance_monitoring = false
end
```

## 📚 Next Steps

### Related Examples

- **[Migration Configuration](migration-configuration-example.md)** - Learn migration workflow integration
- **[Blog Engine](blog-engine.md)** - See configuration in a complete application
- **[Performance Monitoring](performance-monitoring-example.md)** - Advanced performance configuration

### Advanced Topics

- **[Configuration Guide](../guides/configuration.md)** - Detailed configuration documentation
- **[Performance Guide](../guides/performance-optimization.md)** - Performance optimization techniques
- **[Testing Strategies](../guides/testing-strategies.md)** - Testing with different configurations

### Production Considerations

- **Environment Variables** - Secure configuration management
- **Connection Pooling** - Optimize for production load
- **SSL Configuration** - Secure database connections
- **Performance Monitoring** - Production performance tracking
- **Validation** - Ensure configuration correctness

## 🔧 Troubleshooting

### Common Issues

1. **Configuration not applied** - Ensure configuration happens before schema definition
2. **Environment detection issues** - Check `CRYSTAL_ENV` environment variable
3. **Validation errors** - Review configuration values and custom validators
4. **Thread safety issues** - Configuration is thread-safe by default

### Debug Configuration

```crystal
# Print current configuration
puts "Database URL: #{CQL.config.database_url}"
puts "Environment: #{CQL.config.environment}"
puts "Pool size: #{CQL.config.connection_pool.size}"
puts "Performance monitoring: #{CQL.config.enable_performance_monitoring?}"
```

---

## 🏁 Summary

This configuration example demonstrates:

- ✅ **Comprehensive configuration options** for all CQL features
- ✅ **Environment-specific settings** for different deployment stages
- ✅ **Database-specific optimizations** for PostgreSQL, MySQL, and SQLite
- ✅ **Performance monitoring setup** with custom configurations
- ✅ **Validation patterns** for ensuring configuration correctness
- ✅ **Thread-safe configuration access** for concurrent applications
- ✅ **Integration with schema definitions** for seamless setup

Ready to configure your own CQL application? Start with the basic configuration and gradually add advanced features as needed! 🚀
