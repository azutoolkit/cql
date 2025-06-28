# SQLLogEntry Integration with Query Execution

The `SQLLogEntry` from CQL's SQL log formatter integrates seamlessly with query execution through an event-driven architecture. This guide explains the integration mechanism and shows you how to use it effectively.

## 🔗 Integration Architecture

The integration follows this flow:

```
Query Execution → Performance Monitoring → Event System → SQL Log Formatter → Beautiful Output
```

### Key Components

1. **QueryExecutionEvent** - Carries query execution data
2. **EventListener** - Base interface for event handling
3. **SQLLogFormatter** - Processes events and creates formatted logs
4. **Performance.benchmark** - Wraps query execution with monitoring

## 📊 Event-Driven Integration

### QueryExecutionEvent Structure

```crystal
struct QueryExecutionEvent < MonitoringEvent
  getter sql : String
  getter params : Array(DB::Any)
  getter execution_time : Time::Span
  getter rows_affected : Int64?
  getter timestamp : Time
  getter context : String?
end
```

### SQLLogFormatter as EventListener

```crystal
class SQLLogFormatter < EventListener
  def handle_event(event : MonitoringEvent) : Void
    case event
    when QueryExecutionEvent
      handle_query_event(event)
    end
  end

  private def handle_query_event(event : QueryExecutionEvent) : Void
    log_sql(
      sql: event.sql,
      params: event.params,
      execution_time: event.execution_time,
      context: event.context,
      rows_affected: event.rows_affected
    )
  end
end
```

## 🚀 Automatic Integration

### Configuration-Based Setup

The easiest way to enable SQL logging is through configuration:

```crystal
CQL.configure do |config|
  # Enable performance monitoring (required for event system)
  config.monitor_performance = true

  # Enable SQL logging with formatting
  config.sql_logging.enabled = true
  config.sql_logging.colorize_output = true
  config.sql_logging.include_execution_time = true
  config.sql_logging.include_parameters = true
  config.sql_logging.pretty_format = true
  config.sql_logging.async_processing = true
  config.sql_logging.slow_query_threshold = 50.milliseconds
end
```

### Automatic Query Wrapping

When configured, all schema queries are automatically wrapped:

```crystal
# This query execution is automatically monitored
result = AcmeDB.exec("SELECT * FROM users WHERE active = true")

# Behind the scenes:
# 1. CQL::Performance.benchmark wraps the execution
# 2. Creates QueryExecutionEvent with timing and metadata
# 3. Publishes event to event bus
# 4. SQLLogFormatter receives event and logs beautifully formatted SQL
```

## 🎯 Integration Points

### 1. Schema-Level Integration

```crystal
# In src/schema.cr
def exec(sql : String)
  CQL::Performance.benchmark(sql, [] of DB::Any) do
    if conn = @active_connection
      conn.exec(sql)
    else
      @db.using_connection do |db_conn|
        db_conn.exec(sql)
      end
    end
  end
end
```

### 2. Performance Benchmark Wrapper

```crystal
# In src/performance/performance_monitor.cr
def self.benchmark(sql : String, params : Array(DB::Any) = [] of DB::Any, &)
  start_time = Time.monotonic
  result = yield
  execution_time = Time.monotonic - start_time

  # Create and publish event
  event = QueryExecutionEvent.new(
    sql: sql,
    params: params,
    execution_time: execution_time,
    rows_affected: get_rows_affected(result)
  )

  monitor.event_bus.publish(event)
  result
end
```

### 3. Event Bus Distribution

```crystal
# Events are distributed to all subscribers
event_bus = CQL::Performance.monitor.event_bus
event_bus.subscribe(sql_logger)      # Beautiful logging
event_bus.subscribe(query_profiler)  # Performance tracking
event_bus.subscribe(n_plus_detector) # N+1 detection
```

## 🔧 Manual Integration

For custom scenarios, you can manually create and log SQL entries:

### Direct SQL Logging

```crystal
# Log a custom operation
CQL::Performance.sql_logger.log_sql(
  sql: "CUSTOM BATCH OPERATION",
  params: ["param1", "param2"].map(&.as(DB::Any)),
  execution_time: 125.milliseconds,
  context: "batch_processor/migration",
  rows_affected: 1500_i64
)
```

### Error Logging

```crystal
begin
  AcmeDB.exec("SELECT * FROM invalid_table")
rescue ex : DB::Error
  CQL::Performance.sql_logger.log_sql(
    sql: "SELECT * FROM invalid_table",
    execution_time: 5.milliseconds,
    error: ex.message,
    context: "error_handler"
  )
end
```

### Custom SQLLogEntry Creation

```crystal
# Create custom entry with specific formatting
config = CQL::Performance::SQLLogConfig.new
config.colorize_output = true
config.pretty_format = true

entry = CQL::Performance::SQLLogEntry.new(
  sql: complex_sql,
  params: query_params,
  execution_time: execution_time,
  context: "custom_operation",
  rows_affected: result_count,
  config: config
)

puts entry.to_beautiful_string(config)
```

## 🎨 Output Examples

### Simple Query Log

```
✅ SQL 12.45ms (3 rows) [api/users]
SELECT id, name, email
  FROM users
  WHERE active = true
  ORDER BY created_at DESC
📊 Parameters: [true]
────────────────────────────────────────────────────────────
```

### Slow Query Warning

```
⚠️ SQL 156.78ms (1250 rows) [api/reports]
SELECT u.name, COUNT(p.id) as post_count
  FROM users u
  LEFT JOIN posts p ON u.id = p.user_id
  WHERE u.created_at > '2024-01-01'
  GROUP BY u.id, u.name
  ORDER BY post_count DESC
📊 Parameters: ['2024-01-01T00:00:00Z']
────────────────────────────────────────────────────────────
```

### Error Log

```
❌ SQL 5.23ms [error_handler]
SELECT * FROM non_existent_table
❌ Error: no such table: non_existent_table
────────────────────────────────────────────────────────────
```

## 🔄 Custom Event Listeners

You can create custom event listeners to handle SQL execution events:

```crystal
class CustomSQLTracker < CQL::Performance::EventListener
  def initialize
    @query_count = 0
    @total_time = Time::Span.zero
  end

  def handle_event(event : CQL::Performance::MonitoringEvent) : Void
    case event
    when CQL::Performance::QueryExecutionEvent
      @query_count += 1
      @total_time += event.execution_time

      # Custom processing
      if event.execution_time > 100.milliseconds
        puts "SLOW QUERY DETECTED: #{event.sql[0..50]}..."
      end

      # Create custom formatted entry
      entry = CQL::Performance::SQLLogEntry.new(
        sql: event.sql,
        params: event.params,
        execution_time: event.execution_time,
        context: "custom_tracker",
        config: CQL::Performance::SQLLogConfig.new
      )

      # Custom formatting or storage
      log_to_custom_system(entry)
    end
  end

  private def log_to_custom_system(entry)
    # Send to external monitoring, save to file, etc.
  end
end

# Subscribe to event bus
tracker = CustomSQLTracker.new
CQL::Performance.monitor.event_bus.subscribe(tracker)
```

## 📈 Performance Considerations

### Async Processing

Enable async processing for high-throughput applications:

```crystal
config.sql_logging.async_processing = true
config.sql_logging.batch_size = 100
config.sql_logging.batch_timeout = 5.seconds
```

### Selective Logging

Configure thresholds to only log interesting queries:

```crystal
config.sql_logging.slow_query_threshold = 100.milliseconds
config.sql_logging.very_slow_threshold = 1.second
config.sql_logging.max_sql_length = 1000
```

### Memory Management

Control memory usage with batch processing:

```crystal
config.sql_logging.batch_size = 50
config.sql_logging.max_param_length = 200
```

## 🛠️ Troubleshooting

### SQL Logging Not Working

1. Ensure performance monitoring is enabled: `config.monitor_performance = true`
2. Check SQL logging is enabled: `config.sql_logging.enabled = true`
3. Verify event bus subscription: `CQL::Performance.monitor.event_bus.subscribe(sql_logger)`

### Performance Impact

1. Enable async processing: `config.sql_logging.async_processing = true`
2. Increase batch size: `config.sql_logging.batch_size = 100`
3. Set appropriate thresholds: `config.sql_logging.slow_query_threshold = 50.milliseconds`

### Custom Integration Issues

1. Ensure custom listeners implement `EventListener` correctly
2. Subscribe listeners to the event bus: `event_bus.subscribe(listener)`
3. Handle all event types in `handle_event` method

## 📚 Related Documentation

- [Performance Optimization](../advanced-topics/performance-optimization.md)
- [Performance Tools](../advanced-topics/performance-tools.md)
- [Configuration Guide](../getting-started/configuration.md)
- [SQL Log Formatter](sql-log-formatter.md)
- [SQL Log Integration Quick Start](sql-log-integration-quick-start.md)
