# Performance Metrics

The `PerformanceMetrics` class provides a comprehensive, unified interface for collecting and analyzing performance data from all CQL performance monitoring modules.

## Overview

The `PerformanceMetrics` class consolidates metrics from:

- **Query Profiler** - Query execution times, slow queries, error rates
- **N+1 Detector** - Query pattern detection, repetition counts
- **Cache System** - Hit rates, miss rates, evictions
- **System Monitoring** - Uptime, memory usage, connection pools
- **Health Scoring** - Overall performance health assessment

## Quick Start

```crystal
# Get comprehensive metrics
metrics = CQL::Performance.metrics

# Check if performance is healthy
if metrics.healthy?
  puts "✅ Performance is good!"
else
  puts "❌ Performance issues detected!"
end

# Get summary metrics
summary = metrics.summary
puts "Total queries: #{summary["total_queries"]}"
puts "Health score: #{summary["health_score"]}%"
```

## Metrics Structure

### Query Metrics

```crystal
query_metrics = metrics.query_metrics

puts "Total Queries: #{query_metrics.total_queries}"
puts "Slow Queries: #{query_metrics.slow_queries}"
puts "Very Slow Queries: #{query_metrics.very_slow_queries}"
puts "Average Execution Time: #{query_metrics.avg_execution_time.total_milliseconds}ms"
puts "Queries per Second: #{query_metrics.queries_per_second}"
puts "Slow Query Rate: #{query_metrics.slow_query_rate}%"
```

**Available Properties:**

- `total_queries` - Total number of queries executed
- `slow_queries` - Queries exceeding slow threshold
- `very_slow_queries` - Queries exceeding very slow threshold
- `error_queries` - Queries that resulted in errors
- `total_execution_time` - Cumulative execution time
- `avg_execution_time` - Average execution time per query
- `min_execution_time` - Fastest query execution time
- `max_execution_time` - Slowest query execution time
- `error_rate` - Percentage of queries with errors
- `queries_per_second` - Query throughput
- `slow_query_rate` - Percentage of slow queries

### N+1 Detection Metrics

```crystal
n_plus_one_metrics = metrics.n_plus_one_metrics

puts "Total Patterns: #{n_plus_one_metrics.total_patterns}"
puts "Critical Patterns: #{n_plus_one_metrics.critical_patterns}"
puts "High Patterns: #{n_plus_one_metrics.high_patterns}"
puts "Medium Patterns: #{n_plus_one_metrics.medium_patterns}"
puts "Low Patterns: #{n_plus_one_metrics.low_patterns}"
puts "Total Repetitions: #{n_plus_one_metrics.total_repetitions}"
puts "Average Repetitions: #{n_plus_one_metrics.avg_repetitions_per_pattern}"
```

**Severity Levels:**

- **Critical**: > 50 repetitions
- **High**: 21-50 repetitions
- **Medium**: 6-20 repetitions
- **Low**: 2-5 repetitions

### Health Metrics

```crystal
health_metrics = metrics.health_metrics

puts "Overall Health Score: #{health_metrics.overall_health_score}/100"
puts "Query Health Score: #{health_metrics.query_health_score}/100"
puts "N+1 Health Score: #{health_metrics.n_plus_one_health_score}/100"
puts "Cache Health Score: #{health_metrics.cache_health_score}/100"
puts "System Health Score: #{health_metrics.system_health_score}/100"
puts "Total Issues: #{health_metrics.total_issues}"
```

**Health Score Ranges:**

- **90-100**: Excellent performance
- **80-89**: Good performance
- **70-79**: Fair performance
- **60-69**: Poor performance
- **< 60**: Critical performance issues

### System Metrics

```crystal
system_metrics = metrics.system_metrics

puts "Uptime: #{system_metrics.uptime.total_seconds}s"
puts "Memory Usage: #{system_metrics.memory_usage_mb}MB"
puts "CPU Usage: #{system_metrics.cpu_usage_percent}%"
puts "Active Connections: #{system_metrics.active_connections}"
puts "Connection Pool Utilization: #{system_metrics.connection_pool_utilization}%"
```

## Top Queries Analysis

### Slowest Queries

```crystal
slowest_queries = metrics.slowest_queries(5)
slowest_queries.each_with_index do |query, i|
  puts "#{i + 1}. #{query.execution_time.total_milliseconds}ms - #{query.sql[0..50]}..."
end
```

### Most Frequent Queries

```crystal
frequent_queries = metrics.most_frequent_queries(5)
frequent_queries.each_with_index do |query, i|
  puts "#{i + 1}. #{query[:count]} times - #{query[:sql][0..50]}..."
end
```

### Most Expensive Queries

```crystal
expensive_queries = metrics.top_queries.most_expensive_queries
expensive_queries.each_with_index do |query, i|
  puts "#{i + 1}. #{query[:total_time].total_milliseconds}ms total - #{query[:sql][0..50]}..."
end
```

## Performance Issues

### Get All Issues

```crystal
issues = metrics.issues
issues.each do |issue|
  puts "[#{issue.severity.to_s.upcase}] #{issue.type}: #{issue.message}"
end
```

### Filter Issues by Severity

```crystal
critical_issues = metrics.critical_issues
high_priority_issues = metrics.high_priority_issues
medium_issues = metrics.issues_by_severity(:medium)
low_issues = metrics.issues_by_severity(:low)
```

### Filter Issues by Type

```crystal
n_plus_one_issues = metrics.issues_by_type(:n_plus_one)
slow_query_issues = metrics.issues_by_type(:very_slow_queries)
```

## N+1 Pattern Analysis

### Get Patterns by Severity

```crystal
critical_patterns = metrics.n_plus_one_patterns_by_severity(:critical)
high_patterns = metrics.n_plus_one_patterns_by_severity(:high)
medium_patterns = metrics.n_plus_one_patterns_by_severity(:medium)
low_patterns = metrics.n_plus_one_patterns_by_severity(:low)
```

### Pattern Details

```crystal
patterns = metrics.patterns.n_plus_one_patterns
patterns.each do |pattern|
  puts "Parent: #{pattern.parent_query[0..50]}..."
  puts "Repeated: #{pattern.repeated_query[0..50]}..."
  puts "Repetitions: #{pattern.repetition_count}"
  puts "Timestamp: #{pattern.timestamp}"
end
```

## Data Export

### JSON Export

```crystal
# Export all metrics as JSON
json_data = metrics.to_json
File.write("performance_metrics.json", json_data)

# Export summary only
summary_json = metrics.summary.to_json
```

### Hash Export

```crystal
# Get complete metrics as hash
metrics_hash = metrics.to_h

# Get specific metric sections
query_hash = metrics.query_metrics.to_h
health_hash = metrics.health_metrics.to_h
```

## Integration with Monitor

The `PerformanceMetrics` class is automatically integrated with the `Monitor` class:

```crystal
# Get metrics from monitor
monitor = CQL::Performance.monitor
metrics = monitor.metrics

# Check health status
if monitor.healthy?
  puts "System is healthy!"
end

# Get critical issues
critical_issues = monitor.critical_issues
```

## Module-Level Convenience Methods

```crystal
# Quick access to metrics
metrics = CQL::Performance.get_metrics
summary = CQL::Performance.get_metrics_summary

# Health checks
if CQL::Performance.is_healthy?
  puts "Performance is good!"
end

# Issue access
critical_issues = CQL::Performance.get_critical_issues
high_priority_issues = CQL::Performance.get_high_priority_issues

# JSON export
json_metrics = CQL::Performance.export_metrics_as_json
```

## Advanced Usage

### Custom Metrics Collection

```crystal
# Create metrics from specific components
profiler = CQL::Performance.create_profiler
detector = CQL::Performance.create_detector

# Record some data
profiler.record_query("SELECT * FROM users", [] of DB::Any, 100.milliseconds)
detector.record_query("SELECT * FROM posts WHERE user_id = ?")

# Create metrics
metrics = CQL::Performance::PerformanceMetrics.from_components(
  profiler: profiler,
  detector: detector,
  start_time: Time.utc - 1.hour
)
```

### Performance Monitoring in Web Applications

```crystal
# In your web framework (e.g., Kemal, Lucky, etc.)
class PerformanceMiddleware
  def call(context)
    start_time = Time.utc

    # Process request
    call_next(context)

    # Collect metrics after request
    metrics = CQL::Performance.metrics

    # Log performance summary
    context.response.headers["X-Performance-Score"] = metrics.health_metrics.overall_health_score.to_s
    context.response.headers["X-Query-Count"] = metrics.query_metrics.total_queries.to_s
  end
end
```

### Scheduled Metrics Collection

```crystal
# Collect metrics every 5 minutes
spawn do
  loop do
    metrics = CQL::Performance.metrics

    # Send to monitoring service
    send_to_monitoring_service(metrics.to_json)

    # Alert on critical issues
    if metrics.critical_issues.any?
      send_alert("Critical performance issues detected!")
    end

    sleep(5.minutes)
  end
end
```

## Configuration

The `PerformanceMetrics` class respects the configuration from the `Monitor`:

```crystal
CQL::Performance.configure do |config|
  config.profiling.slow_query_threshold = 100.milliseconds
  config.profiling.very_slow_threshold = 1.second
  config.detection.threshold = 3
  config.monitoring.enabled = true
end
```

## Best Practices

1. **Regular Health Checks**: Use `metrics.healthy?` for automated health monitoring
2. **Issue Prioritization**: Focus on critical and high-priority issues first
3. **Trend Analysis**: Collect metrics over time to identify performance trends
4. **Alerting**: Set up alerts for critical performance issues
5. **Data Retention**: Export metrics regularly for historical analysis

## Performance Considerations

- The `PerformanceMetrics` class is designed to be lightweight and efficient
- Metrics collection has minimal overhead on query execution
- Large datasets are automatically managed with cleanup mechanisms
- JSON export is optimized for large metric collections

## Troubleshooting

### No Metrics Available

```crystal
# Ensure monitoring is enabled
CQL::Performance.configure do |config|
  config.monitoring.enabled = true
  config.profiling.enabled = true
  config.detection.enabled = true
end

# Check if components are active
monitor = CQL::Performance.monitor
puts "Profiler enabled: #{!monitor.profiler.nil?}"
puts "Detector enabled: #{!monitor.detector.nil?}"
```

### Missing Data

```crystal
# Verify data collection
metrics = CQL::Performance.metrics
puts "Collection duration: #{metrics.collection_duration.total_seconds}s"
puts "Timestamp: #{metrics.timestamp}"
```

The `PerformanceMetrics` class provides a comprehensive view of your application's performance, making it easy to identify issues, track improvements, and maintain optimal database performance.
