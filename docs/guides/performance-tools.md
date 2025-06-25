# CQL Performance Tools

CQL Performance Tools is a comprehensive suite of database performance monitoring and optimization utilities built into CQL. It provides three main capabilities:

1. **Query Plan Analysis** - Inspect and display database query execution plans
2. **N+1 Query Detection** - Detect inefficient repetitive queries in relation traversals
3. **Query Time Logging & Profiling** - Track execution times and generate performance reports

## Table of Contents

- [Quick Start](#quick-start)
- [Query Plan Analysis](#query-plan-analysis)
- [N+1 Query Detection](#n1-query-detection)
- [Query Profiling](#query-profiling)
- [Configuration](#configuration)
- [Integration](#integration)
- [Reports](#reports)
- [Best Practices](#best-practices)

## Quick Start

### Basic Setup

```crystal
require "cql"

# Define your schema
MySchema = CQL::Schema.define(:my_app, "postgresql://localhost/myapp", CQL::Adapter::Postgres) do
  # ... your tables
end

# Enable performance monitoring with default settings
CQL::Performance.setup(MySchema)
```

### Custom Configuration

```crystal
CQL::Performance.setup(MySchema) do |config|
  config.query_profiling = true
  config.n_plus_one_detection = true
  config.plan_analysis = true
  config.auto_analyze_slow_queries = true
  config.context_tracking = true
end
```

## Query Plan Analysis

Query Plan Analysis provides database-specific EXPLAIN functionality to help you understand how your queries are executed and identify potential performance issues.

### Supported Databases

- **PostgreSQL**: Full support with `EXPLAIN (ANALYZE, FORMAT JSON, BUFFERS, VERBOSE)`
- **MySQL**: Support with `EXPLAIN FORMAT=JSON`
- **SQLite**: Basic support with `EXPLAIN QUERY PLAN`

### Usage

```crystal
monitor = CQL::Performance.monitor

# Analyze query plan without execution
sql = "SELECT * FROM users WHERE email = 'user@example.com'"
if plan = monitor.analyze_query_plan(sql)
  puts plan.summary
  puts "Has performance issues: #{plan.has_performance_issues?}"
  puts "Warnings: #{plan.warnings.join(", ")}"
end

# Analyze with actual execution (more accurate)
if plan = monitor.analyze_query_plan_with_execution(sql)
  puts "Execution time: #{plan.execution_time}"
  puts "Estimated cost: #{plan.estimated_cost}"
  puts "Estimated rows: #{plan.estimated_rows}"
end
```

### Performance Warnings

The analyzer automatically detects common performance issues:

- Sequential scans on large tables
- Missing indexes
- High estimated costs
- Temporary table creation
- Expensive operations

## N+1 Query Detection

N+1 Query Detection monitors query patterns to identify cases where you're executing repeated queries in loops, typically when loading related data.

### How It Works

The detector tracks query execution patterns and identifies when the same (normalized) query is executed multiple times in succession, which often indicates an N+1 problem.

### Example N+1 Pattern

```crystal
# This creates an N+1 problem:
posts = Post.all
posts.each do |post|
  puts "#{post.title} by #{post.user.name}"  # Executes a query for each post
end

# Better approach:
posts = Post.includes(:user).all  # Single query with JOIN
posts.each do |post|
  puts "#{post.title} by #{post.user.name}"  # No additional queries
end
```

### Detection Severity Levels

- **Low**: 2-5 repetitions
- **Medium**: 6-20 repetitions
- **High**: 21-50 repetitions
- **Critical**: 50+ repetitions

### Strict Mode

Enable strict mode to raise exceptions for critical N+1 patterns:

```crystal
ENV["CQL_N_PLUS_ONE_STRICT"] = "true"
```

## Query Profiling

Query Profiling tracks execution times, groups queries by pattern, and provides detailed performance analytics.

### Features

- **Execution Time Tracking**: Monitor how long each query takes
- **Query Pattern Grouping**: Group similar queries to identify bottlenecks
- **Endpoint Tracking**: Track performance by application endpoint
- **Slow Query Detection**: Automatically identify and log slow queries
- **Memory Usage Tracking**: Optional memory usage monitoring

### Usage

```crystal
# Profiling happens automatically once enabled
# Set context to track by endpoint/user
CQL::Performance.set_context(endpoint: "/api/users", user_id: "user_123")

# Execute your queries normally
users = User.where(active: true).limit(10).all

# Access profiling data
profiler = CQL::Performance.monitor
puts "Total queries executed: #{profiler.statistics.size}"
puts "Slow queries: #{profiler.slow_queries.size}"

# Get endpoint performance summary
summary = profiler.endpoint_summary
summary.each do |endpoint, stats|
  puts "#{endpoint}: #{stats[:count]} queries, #{stats[:avg_time]}ms avg"
end
```

### Slow Query Thresholds

Configure thresholds for slow query detection:

```crystal
CQL::Performance.monitor.configure do |config|
  config.slow_query_threshold = 100.milliseconds
  config.very_slow_threshold = 1.second
  config.log_slow_queries = true
end
```

## Configuration

### PerformanceConfig Options

```crystal
class PerformanceConfig
  property plan_analysis : Bool = true               # Enable query plan analysis
  property n_plus_one_detection : Bool = true        # Enable N+1 detection
  property query_profiling : Bool = true             # Enable query profiling
  property auto_analyze_slow_queries : Bool = true   # Auto-analyze slow queries
  property context_tracking : Bool = true            # Track request context
  property endpoint_tracking : Bool = false          # Track by endpoint
end
```

### ProfilerConfig Options

```crystal
profiler.configure do |config|
  config.enabled = true
  config.slow_query_threshold = 100.milliseconds
  config.very_slow_threshold = 1.second
  config.log_all_queries = false
  config.log_slow_queries = true
  config.max_recorded_queries = 10_000
  config.enable_memory_tracking = false
  config.queries_to_ignore = ["COMMIT", "BEGIN", "ROLLBACK"]
end
```

## Integration

### Web Framework Integration

For web applications, integrate performance monitoring in your middleware:

```crystal
# Example with Kemal
class PerformanceMiddleware < HTTP::Handler
  def call(context)
    endpoint = "#{context.request.method} #{context.request.path}"
    user_id = extract_user_id(context)

    CQL::Performance.set_context(endpoint: endpoint, user_id: user_id)

    call_next(context)
  ensure
    # Context is automatically cleared between requests
  end

  private def extract_user_id(context)
    # Extract user ID from session, JWT, etc.
  end
end

add_handler PerformanceMiddleware.new
```

### Relation Loading Integration

For automatic N+1 detection in ActiveRecord relations, the monitoring hooks are automatically integrated into the relation loading process.

### Manual Integration

For custom query execution, manually add monitoring hooks:

```crystal
def execute_custom_query(sql, params = [] of DB::Any)
  CQL::Performance.before_query(sql, params)
  start_time = Time.monotonic

  result = # ... execute your query

  execution_time = Time.monotonic - start_time
  CQL::Performance.after_query(sql, params, execution_time)

  result
end
```

## Reports

### Text Reports

```crystal
# Comprehensive report
puts CQL::Performance.monitor.comprehensive_report

# Individual reports
puts CQL::Performance.monitor.n_plus_one_report
puts CQL::Performance.monitor.profiling_report
```

### HTML Reports

```crystal
# Generate HTML report
html_report = CQL::Performance.monitor.comprehensive_report("html")
File.write("performance_report.html", html_report)
```

### JSON Reports

```crystal
# Generate JSON report for programmatic analysis
json_report = CQL::Performance.monitor.comprehensive_report("json")
data = JSON.parse(json_report)
```

### Metrics Summary

Get a quick overview of performance metrics:

```crystal
metrics = CQL::Performance.monitor.metrics_summary

puts "Total Queries: #{metrics[:total_queries]}"
puts "Slow Queries: #{metrics[:slow_queries]}"
puts "N+1 Patterns: #{metrics[:n_plus_one_patterns]}"
puts "Average Query Time: #{metrics[:avg_query_time]}ms"
```

## Best Practices

### Development Environment

- Enable all monitoring features
- Set strict mode for N+1 detection
- Use auto-analysis for slow queries
- Generate regular performance reports

```crystal
# Development configuration
CQL::Performance.setup(MySchema) do |config|
  config.query_profiling = true
  config.n_plus_one_detection = true
  config.plan_analysis = true
  config.auto_analyze_slow_queries = true
end

ENV["CQL_N_PLUS_ONE_STRICT"] = "true"
```

### Production Environment

- Enable query profiling and N+1 detection
- Disable or limit plan analysis (performance overhead)
- Set appropriate thresholds
- Implement automated alerting

```crystal
# Production configuration
CQL::Performance.setup(MySchema) do |config|
  config.query_profiling = true
  config.n_plus_one_detection = true
  config.plan_analysis = false  # Disable for performance
  config.auto_analyze_slow_queries = false
end

CQL::Performance.monitor.configure do |config|
  config.slow_query_threshold = 500.milliseconds
  config.very_slow_threshold = 2.seconds
  config.max_recorded_queries = 5_000
end
```

### Performance Impact

The monitoring tools are designed to have minimal performance impact:

- **Query Profiling**: ~1-5% overhead
- **N+1 Detection**: ~2-8% overhead
- **Plan Analysis**: ~10-20% overhead (only when analyzing)

### Memory Management

```crystal
# Periodically clear old data in long-running applications
CQL::Performance.monitor.clear_data

# Configure maximum stored queries
CQL::Performance.monitor.configure do |config|
  config.max_recorded_queries = 5_000
end
```

### Monitoring Integration

Consider integrating with external monitoring services:

```crystal
# Example: Send metrics to monitoring service
metrics = CQL::Performance.monitor.metrics_summary
if metrics[:slow_queries] > 10
  send_alert("High number of slow queries detected: #{metrics[:slow_queries]}")
end

# Send N+1 patterns to monitoring
n_plus_one_patterns = CQL::Performance.monitor.n_plus_one_detector.detected_patterns
if n_plus_one_patterns.any?(&.severity.critical?)
  send_alert("Critical N+1 query patterns detected")
end
```

## Advanced Usage

### Custom Query Plan Analysis

```crystal
analyzer = CQL::Performance::QueryPlanAnalyzer.new(MySchema)

# Analyze specific queries
complex_query = """
  SELECT u.name, COUNT(p.id) as post_count
  FROM users u
  LEFT JOIN posts p ON u.id = p.user_id
  WHERE u.created_at > $1
  GROUP BY u.id, u.name
  HAVING COUNT(p.id) > 5
  ORDER BY post_count DESC
"""

plan = analyzer.analyze_with_execution(complex_query, [Time.utc - 30.days])
if plan.has_performance_issues?
  puts "Query needs optimization:"
  plan.warnings.each { |warning| puts "- #{warning}" }
end
```

### Custom N+1 Detection

```crystal
detector = CQL::Performance::NPlusOneDetector.new(threshold: 3)

# Manual tracking
detector.start_relation_loading("User.posts")
# ... execute queries that might create N+1 pattern
detector.end_relation_loading

# Check for patterns
patterns = detector.detected_patterns
patterns.each do |pattern|
  puts "N+1 detected: #{pattern.summary}"
end
```

### Performance Testing

```crystal
# Test query performance
def benchmark_query(description, &block)
  CQL::Performance.set_context(endpoint: description)

  start_time = Time.monotonic
  result = yield
  execution_time = Time.monotonic - start_time

  puts "#{description}: #{execution_time.total_milliseconds}ms"
  result
end

# Usage
users = benchmark_query("User.all with includes") do
  User.includes(:posts, :comments).all
end
```

This comprehensive performance monitoring system helps you identify bottlenecks, optimize queries, and maintain high database performance as your CQL application scales.
