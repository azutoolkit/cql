# CQL Configuration Guide

CQL provides a centralized, developer-friendly configuration system that works out of the box in development and scales to production.

## Quick Start

### Zero Configuration (Development)

```crystal
# That's it! In development, you get everything auto-configured:
CQL.configure do |c|
  c.db = "postgresql://localhost/myapp"
end

# ✅ SQL logging with beautiful formatting
# ✅ Performance monitoring with auto-reporting
# ✅ N+1 query detection
# ✅ Slow query analysis
# ✅ Smart defaults for connection pooling
```

### Production Configuration

```crystal
CQL.configure do |c|
  c.db = ENV["DATABASE_URL"]
  c.env = "production"
  c.pool_size = 25

  # Performance features are opt-in for production
  c.monitor_performance = true    # Enable monitoring
  c.sql_logging = false          # Disable SQL logs
end
```

## Configuration Properties

### Core Settings

| Property    | Type            | Default                           | Description                 |
| ----------- | --------------- | --------------------------------- | --------------------------- |
| `db`        | `String`        | `"sqlite3://./db/development.db"` | Database connection URL     |
| `env`       | `String`        | `"development"`                   | Environment (auto-detected) |
| `pool_size` | `Int32`         | `10`                              | Connection pool size        |
| `log_level` | `Log::Severity` | `:debug` (dev), `:info` (prod)    | Logging level               |

### Performance Monitoring

| Property                      | Type         | Default     | Description                   |
| ----------------------------- | ------------ | ----------- | ----------------------------- |
| `monitor_performance`         | `Bool`       | `false`\*   | Enable performance monitoring |
| `performance_auto_report`     | `Bool`       | `true`      | Auto-report in development    |
| `performance_report_interval` | `Time::Span` | `5.minutes` | How often to generate reports |

\*Auto-enabled in development unless `CQL_NO_PERF_MONITOR=1` is set

### SQL Logging

| Property               | Type   | Default   | Description                                 |
| ---------------------- | ------ | --------- | ------------------------------------------- |
| `sql_logging`          | `Bool` | `false`\* | Enable SQL query logging                    |
| `sql_logging_colorize` | `Bool` | `true`    | Colorize SQL output                         |
| `sql_logging_async`    | `Bool` | `false`   | Use async logging (not recommended for dev) |

\*Auto-enabled in development unless `CQL_NO_SQL_LOG=1` is set

## Examples

### Development with Custom Settings

```crystal
CQL.configure do |c|
  c.db = "postgresql://localhost/myapp"

  # Customize performance monitoring
  c.performance_report_interval = 1.minute  # More frequent reports

  # Customize SQL logging
  c.sql_logging_colorize = false  # Disable colors (for file logs)
end
```

### Testing Configuration

```crystal
CQL.configure do |c|
  c.db = "sqlite3://./db/test.db"
  c.env = "test"

  # Performance features are automatically disabled in test
  # No SQL logging or performance reports during tests
end
```

### Production with Monitoring

```crystal
CQL.configure do |c|
  c.db = ENV["DATABASE_URL"]
  c.env = "production"
  c.pool_size = 25

  # Explicitly enable performance monitoring
  c.monitor_performance = true
  c.performance_auto_report = false  # No auto-reports in production

  # Keep SQL logging off for performance
  c.sql_logging = false

  # Enable caching
  c.cache.on = true
  c.cache.ttl = 1.hour
end
```

## Environment Variables

Control auto-features with environment variables:

- `CRYSTAL_ENV` or `CQL_ENV` - Set the environment (development/test/production)
- `CQL_NO_SQL_LOG=1` - Disable automatic SQL logging in development
- `CQL_NO_PERF_MONITOR=1` - Disable automatic performance monitoring in development

## Cache Configuration

```crystal
CQL.configure do |c|
  c.db = "postgresql://localhost/myapp"

  # Quick cache setup
  c.cache.on = true
  c.cache.ttl = 30.minutes
  c.cache.memory_size = 2000
end
```

## Migration Settings

```crystal
CQL.configure do |c|
  c.db = "postgresql://localhost/myapp"

  # Migration settings
  c.schema_dir = "src/schemas"
  c.schema_file = "app_schema.cr"
  c.auto_sync = true  # Keep schema file in sync with DB
  c.bootstrap = true  # Create schema from existing DB
end
```

## Helper Methods

```crystal
# Check configuration
CQL.config.monitor_performance? # true in dev, false in prod (unless enabled)
CQL.config.sql_logging?        # true in dev, false in prod (unless enabled)

# Get effective logger
logger = CQL.config.effective_logger

# Get database adapter
adapter = CQL.config.adapter # :postgres, :mysql, :sqlite

# Build components
migrator = CQL.config.build_migrator(schema)
```

## Best Practices

1. **Use Zero Configuration in Development** - Just set your database URL
2. **Be Explicit in Production** - Opt-in to features you need
3. **Use Environment Variables** - For deployment flexibility
4. **Keep It Simple** - Only configure what differs from defaults

## Philosophy

The configuration system follows these principles:

- **Zero Configuration** - Works perfectly out of the box for development
- **Smart Defaults** - Sensible settings based on environment
- **Progressive Disclosure** - Simple things are simple, complex things are possible
- **Developer Experience** - Optimized for fast feedback and debugging in development
