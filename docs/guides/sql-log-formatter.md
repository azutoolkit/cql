\*\*\*\*# 🎨 Beautiful SQL Log Formatter

The CQL Beautiful SQL Log Formatter provides a developer-friendly way to log and monitor SQL queries with beautiful, colorized output and powerful features including async processing, batch handling, and background error reporting.

## ✨ Key Features

- **🌈 Beautiful colorized output** - Syntax highlighting and performance indicators
- **⚡ Async pipeline processing** - Non-blocking SQL logging with batching
- **🚀 Environment-aware** - Auto-enables in development, manual control in production
- **📊 Batch processing** - Efficient handling of high-volume query logging
- **🚨 Background error reporting** - Aggregates and reports logging errors
- **🔗 CQL integration** - Seamlessly integrates with existing CQL configuration
- **📈 Performance monitoring** - Tracks slow queries with configurable thresholds

## 🚀 Quick Start

### Auto-Enable in Development

The SQL log formatter automatically enables itself in development mode:

```crystal
# No configuration needed! Just use CQL normally
# SQL logging will automatically be enabled in development

users = User.where(active: true).limit(10).all
# ✅ SQL 25.45ms (10 rows) [UserController#index]
# SELECT *
#   FROM users
#   WHERE active = $1
#   LIMIT $2
# 📊 Parameters: [true, 10]
```

### Manual Configuration

For production or custom settings:

```crystal
CQL.configure do |c|
  c.db = "postgresql://localhost/myapp"

  # Enable SQL logging
  c.sql_logging.enabled = true
  c.sql_logging.colorize_output = true
  c.sql_logging.include_parameters = true
  c.sql_logging.async_processing = true
  c.sql_logging.batch_size = 50
end
```

## 📋 Configuration Options

### SQLLogConfig Properties

| Property                     | Type         | Default      | Description                                 |
| ---------------------------- | ------------ | ------------ | ------------------------------------------- |
| `enabled`                    | `Bool`       | `false`      | Enable/disable SQL logging                  |
| `auto_enable_in_development` | `Bool`       | `true`       | Auto-enable when CRYSTAL_ENV=development    |
| `colorize_output`            | `Bool`       | `true`       | Use colors and emojis in output             |
| `include_parameters`         | `Bool`       | `true`       | Show query parameters                       |
| `include_execution_time`     | `Bool`       | `true`       | Show query execution time                   |
| `include_row_count`          | `Bool`       | `true`       | Show affected/returned row count            |
| `include_stack_trace`        | `Bool`       | `false`      | Include stack trace for errors              |
| `pretty_format`              | `Bool`       | `true`       | Format SQL with indentation and line breaks |
| `async_processing`           | `Bool`       | `true`       | Use async pipeline for logging              |
| `batch_size`                 | `Int32`      | `50`         | Number of queries per batch                 |
| `batch_timeout`              | `Time::Span` | `2.seconds`  | Max time to wait before flushing batch      |
| `slow_query_threshold`       | `Time::Span` | `100.ms`     | Threshold for slow query warnings           |
| `very_slow_threshold`        | `Time::Span` | `1.second`   | Threshold for very slow query alerts        |
| `max_sql_length`             | `Int32`      | `2000`       | Maximum SQL length before truncation        |
| `max_param_length`           | `Int32`      | `500`        | Maximum parameter length before truncation  |
| `background_error_reporting` | `Bool`       | `true`       | Enable background error aggregation         |
| `error_report_interval`      | `Time::Span` | `30.seconds` | How often to report aggregated errors       |

## 🎯 Usage Examples

### Basic Configuration

```crystal
# Through CQL configuration
CQL.configure do |c|
  c.sql_logging.enabled = true
  c.sql_logging.slow_query_threshold = 50.milliseconds
end

# Direct configuration
CQL::Performance.enable_sql_logging do |config|
  config.enabled = true
  config.colorize_output = true
  config.async_processing = false # Sync for immediate output
end
```

### Production Setup

```crystal
CQL.configure do |c|
  c.env = "production"
  c.db = ENV["DATABASE_URL"]

  # Enable SQL logging for production monitoring
  c.sql_logging.enabled = true
  c.sql_logging.colorize_output = false # Disable colors for log files
  c.sql_logging.async_processing = true
  c.sql_logging.batch_size = 100
  c.sql_logging.slow_query_threshold = 200.milliseconds
  c.sql_logging.background_error_reporting = true
end
```

### High-Performance Async Setup

```crystal
CQL.configure do |c|
  c.sql_logging.enabled = true
  c.sql_logging.async_processing = true
  c.sql_logging.batch_size = 100
  c.sql_logging.batch_timeout = 5.seconds
  c.sql_logging.background_error_reporting = true
  c.sql_logging.error_report_interval = 60.seconds
end
```

## 🎨 Output Examples

### Normal Query

```
✅ SQL 12.34ms (5 rows) [UserController#show]
SELECT u.id, u.name, u.email
  FROM users u
  WHERE u.active = $1
    AND u.id = $2
📊 Parameters: [true, 123]
────────────────────────────────────────────────────────────────────────────────
```

### Slow Query Warning

```
⚠️ SQL 156.78ms (1 row) [ReportController#analytics]
SELECT COUNT(*)
  FROM events e
  WHERE e.created_at BETWEEN $1 AND $2
    AND e.user_id IN (SELECT id FROM users WHERE premium = true)
📊 Parameters: [2024-01-01, 2024-01-31]
────────────────────────────────────────────────────────────────────────────────
```

### Very Slow Query Alert

```
🐌 SQL 2.45s (1000 rows) [ExportController#generate]
SELECT e.*, u.name, u.email
  FROM events e
  JOIN users u ON e.user_id = u.id
  WHERE e.created_at > $1
  ORDER BY e.created_at DESC
📊 Parameters: [2024-01-01 00:00:00 UTC]
────────────────────────────────────────────────────────────────────────────────
```

### Error Logging

```
❌ SQL 0.0ms (0 rows) [TestController#error]
SELECT * FROM non_existent_table WHERE id = $1
📊 Parameters: [123]
❌ Error: Table 'non_existent_table' doesn't exist
📍 Stack Trace:
  src/test.cr:42:in 'query'
  src/controller.cr:15:in 'action'
  src/handler.cr:8:in 'call'
────────────────────────────────────────────────────────────────────────────────
```

## 🔗 Integration with Performance Monitoring

The SQL log formatter integrates seamlessly with CQL's existing performance monitoring:

```crystal
CQL.configure do |c|
  # Enable both performance monitoring and SQL logging
  c.monitor_performance = true
  c.sql_logging.enabled = true

  # They will share the same event bus for efficiency
end

# The SQL logger will automatically receive events from the performance monitor
# This provides comprehensive query monitoring with beautiful logging
```

## ⚡ Async Pipeline Architecture

The async pipeline provides several benefits:

1. **Non-blocking**: SQL logging doesn't slow down your application
2. **Batching**: Multiple queries are processed together for efficiency
3. **Error resilience**: Logging errors don't affect your application
4. **Background reporting**: Aggregated error reports help identify issues

```crystal
# Configure async processing
CQL.configure do |c|
  c.sql_logging.async_processing = true
  c.sql_logging.batch_size = 50        # Process 50 queries at once
  c.sql_logging.batch_timeout = 2.seconds # Or process every 2 seconds
end
```

## 🚨 Background Error Reporting

When enabled, the SQL logger aggregates errors and reports them periodically:

```
🚨 SQL Logger Error Report
══════════════════════════════════════════════════════════════════════════════
Report Period: 30s
Total Errors: 15
Unique Errors: 3

• Failed to log SQL: Channel closed (8 times)
• Batch processing error: Memory allocation failed (4 times)
• Failed to log entry: Invalid UTF-8 sequence (3 times)
══════════════════════════════════════════════════════════════════════════════
```

## 📊 Monitoring and Statistics

Get insights into your SQL logging performance:

```crystal
# Get current statistics
stats = CQL::Performance.sql_logger.stats

puts "Processed: #{stats["processed"]} queries"
puts "Errors: #{stats["errors"]}"
puts "Batches: #{stats["batches"]}"
puts "Uptime: #{stats["uptime_seconds"]} seconds"
puts "Queue size: #{stats["queue_size"]}"

# Check if logging is enabled
if CQL.config.sql_logging?
  puts "SQL logging is active"
end
```

## 🛠️ Direct API Usage

For advanced use cases, you can use the SQL logger directly:

```crystal
# Create a custom SQL logger
formatter = CQL::Performance::SQLLogFormatter.new

# Configure it
formatter.configure do |config|
  config.enabled = true
  config.colorize_output = true
  config.async_processing = false
end

# Log SQL directly
formatter.log_sql(
  "SELECT * FROM users WHERE id = $1",
  [123],
  45.milliseconds,
  "MyController#action",
  rows_affected: 1_i64
)

# Log SQL with error
formatter.log_sql(
  "INVALID SQL",
  [] of DB::Any,
  0.milliseconds,
  "ErrorTest",
  error: "Syntax error"
)

# Get statistics
puts formatter.stats

# Shutdown gracefully
formatter.shutdown
```

## 🎯 Best Practices

### Development

```crystal
CQL.configure do |c|
  c.env = "development"

  # Let SQL logging auto-enable
  c.sql_logging.colorize_output = true
  c.sql_logging.include_parameters = true
  c.sql_logging.pretty_format = true
  c.sql_logging.async_processing = false # Immediate feedback
  c.sql_logging.slow_query_threshold = 10.milliseconds # Catch slow queries early
end
```

### Production

```crystal
CQL.configure do |c|
  c.env = "production"

  # Enable selectively
  c.sql_logging.enabled = true
  c.sql_logging.colorize_output = false # No colors in log files
  c.sql_logging.async_processing = true # Don't block requests
  c.sql_logging.batch_size = 200 # Larger batches for efficiency
  c.sql_logging.slow_query_threshold = 500.milliseconds # Focus on real issues
  c.sql_logging.background_error_reporting = true
end
```

### Testing

```crystal
CQL.configure do |c|
  c.env = "test"

  # Usually disable to reduce noise
  c.sql_logging.enabled = false

  # Or enable for debugging specific tests
  # c.sql_logging.enabled = true
  # c.sql_logging.async_processing = false
  # c.sql_logging.colorize_output = false
end
```

## 🔧 Troubleshooting

### SQL Logging Not Working

1. Check if enabled:

   ```crystal
   puts CQL.config.sql_logging? # Should be true
   ```

2. Check environment:

   ```crystal
   puts ENV["CRYSTAL_ENV"]? # Should be "development" for auto-enable
   ```

3. Check log level:
   ```crystal
   CQL.config.log_level = :debug # Enable debug logging
   ```

### Performance Impact

- Use `async_processing = true` for production
- Increase `batch_size` for high-volume applications
- Adjust `batch_timeout` based on your needs
- Set appropriate `slow_query_threshold` values

### Memory Usage

- Monitor `max_sql_length` and `max_param_length` settings
- Use `background_error_reporting` to avoid memory leaks from errors
- Configure appropriate `batch_size` to balance memory vs. performance

The SQL log formatter is designed to be both powerful and lightweight, providing beautiful insights into your database queries without impacting application performance.

## 📚 Related Documentation

- [SQL Log Integration Quick Start](sql-log-integration-quick-start.md) - Get up and running quickly
- [SQL Log Formatter Integration](sql-log-formatter-integration.md) - Advanced integration patterns
- [Configuration Guide](../getting-started/configuration.md) - Complete CQL configuration reference
- [Performance Optimization](../advanced-topics/performance-optimization.md) - Performance tuning strategies
- [Performance Tools](../advanced-topics/performance-tools.md) - Additional performance monitoring tools
