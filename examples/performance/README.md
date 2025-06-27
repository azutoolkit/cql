# Performance Monitoring Examples

This directory contains examples demonstrating CQL's advanced performance monitoring and optimization capabilities. Learn how to identify, analyze, and resolve performance issues in your Crystal applications.

## 📝 Examples Overview

### 📊 **performance_monitoring_example.cr**

**Purpose:** Comprehensive demonstration of CQL's performance monitoring system
**Features:**

- Query Plan Analysis for database optimization
- N+1 Query Detection with automatic pattern recognition
- Query Profiling with detailed performance metrics
- Event-driven performance monitoring with Observer pattern
- Context tracking for endpoint and user-specific analysis
- Multi-format report generation (HTML, JSON, Logger)
- Real-time performance metrics and statistics
- Advanced component access for custom monitoring

**Run:** `crystal performance_monitoring_example.cr`

### 🖥️ **logger_report_example.cr**

**Purpose:** Development-focused performance debugging with beautiful console output
**Features:**

- LoggerReportGenerator for real-time development debugging
- Colorful console output with emojis and clear formatting
- Developer-friendly performance issue categorization
- Intelligent performance recommendations
- Integration examples for development workflow
- Zero overhead when debug logging is disabled
- Perfect for CI/CD performance validation

**Run:** `crystal logger_report_example.cr`

## 🚀 Getting Started

### Prerequisites

- Crystal 1.16.3+
- SQLite3 (examples use SQLite for simplicity)
- Development environment with console output support

### Quick Start

```bash
# Start with comprehensive monitoring
crystal performance_monitoring_example.cr

# Then explore development debugging
crystal logger_report_example.cr
```

## 🎯 Key Performance Features

### Real-time Query Analysis

- **Query Plan Analysis** - Understand database execution strategies
- **Execution Time Tracking** - Monitor query performance in real-time
- **Result Set Analysis** - Track query result sizes and patterns
- **Context Tracking** - Associate queries with endpoints and users

### Intelligent Issue Detection

- **N+1 Query Detection** - Automatic identification of inefficient query patterns
- **Slow Query Identification** - Flag queries exceeding performance thresholds
- **Memory Usage Monitoring** - Track database connection and cache usage
- **Pattern Recognition** - Identify recurring performance anti-patterns

### Developer-Friendly Reporting

- **Beautiful Console Output** - Colorful, emoji-rich development reports
- **HTML Reports** - Detailed web-based performance analysis
- **JSON Reports** - Machine-readable data for monitoring systems
- **Logger Integration** - Seamless integration with Crystal's logging system

## 📊 Performance Monitoring Architecture

### Event-Driven System

```crystal
# Set up performance monitoring
monitor = CQL::Performance::PerformanceMonitor.new(config)

# Monitor queries automatically
monitor.after_query(sql, params, execution_time, result_count)

# Track context for better analysis
monitor.set_context(endpoint: "/api/users", user_id: "user_123")
```

### Component Architecture

- **Query Profiler** - Detailed query analysis and statistics
- **N+1 Detector** - Pattern recognition for N+1 queries
- **Query Plan Analyzer** - Database-specific execution plan analysis
- **Report Generators** - Multiple output formats for different use cases

## 🔍 Analyzing Performance Issues

### N+1 Query Detection

```crystal
# This will trigger N+1 detection
posts = Post.all
posts.each do |post|
  puts post.user.name  # Separate query for each post
end

# Monitor detects the pattern and suggests solutions:
# "Consider using includes(:user) or preloading"
```

### Slow Query Analysis

```crystal
# Monitor automatically flags slow queries
slow_results = execute_complex_join_query  # Takes >100ms

# Report includes:
# - Query execution time
# - Optimization suggestions
# - Query plan analysis (PostgreSQL)
```

### Context-Aware Monitoring

```crystal
# Track performance by endpoint
monitor.set_context(
  endpoint: "/api/dashboard",
  user_id: "admin_user",
  request_id: "req_123"
)

# All subsequent queries are tracked with this context
dashboard_data = load_dashboard_data
```

## 🎨 Report Types

### Development Logger Reports

Perfect for real-time development debugging:

```crystal
# Enable debug logging
::Log.setup(:debug)

# Generate beautiful console report
monitor.generate_comprehensive_report("logger")
```

**Features:**

- 🎨 Colorful output with emojis
- 🔍 Issue categorization by severity
- 💡 Intelligent recommendations
- 📊 Performance statistics
- ⚡ Only runs when LOG_LEVEL=debug (zero overhead in production)

### HTML Reports

Detailed web-based analysis:

```crystal
html_report = monitor.generate_comprehensive_report("html")
File.write("performance_report.html", html_report)
```

**Features:**

- Interactive web interface
- Detailed query breakdowns
- Performance graphs and charts
- Exportable and shareable

### JSON Reports

Machine-readable for monitoring systems:

```crystal
json_report = monitor.generate_comprehensive_report("json")
# Send to monitoring system, store in database, etc.
```

## 🛠️ Integration Patterns

### Web Framework Middleware

```crystal
# Kemal integration
before_all do |env|
  CQL::Performance.monitor.set_context(
    endpoint: env.request.path,
    user_id: current_user_id(env)
  )
end

after_all do |env|
  if debug_mode?
    CQL::Performance.monitor.generate_comprehensive_report("logger")
  end
end
```

### Development Workflow

```crystal
# In your test suite
describe "Performance Tests" do
  it "should not have N+1 queries" do
    Log.setup(:debug)  # Enable performance reporting

    # Your test code here...

    # Generate report for debugging
    CQL::Performance.monitor.generate_comprehensive_report("logger")
  end
end
```

### CI/CD Integration

```crystal
# Performance validation in CI
class PerformanceValidator
  def validate!
    metrics = CQL::Performance.monitor.metrics_summary

    # Fail CI if performance issues detected
    if metrics.n_plus_one_patterns > 0
      raise "N+1 queries detected: #{metrics.n_plus_one_patterns}"
    end

    if metrics.slow_queries > acceptable_slow_queries
      raise "Too many slow queries: #{metrics.slow_queries}"
    end
  end
end
```

## 📈 Performance Metrics

### Key Metrics Tracked

- **Total Queries** - Overall query volume
- **Slow Queries** - Queries exceeding thresholds
- **N+1 Patterns** - Inefficient query patterns
- **Average Query Time** - Performance baseline
- **Cache Hit Rates** - Caching effectiveness
- **Memory Usage** - Resource consumption

### Performance Thresholds

```crystal
config = CQL::Performance::PerformanceConfig.new
config.slow_query_threshold = 100.milliseconds
config.n_plus_one_threshold = 5  # queries
config.memory_usage_warning = 100.megabytes
```

## 🎯 Optimization Strategies

### Query Optimization

- **Use Includes** - Preload associations to avoid N+1
- **Batch Loading** - Load related data in batches
- **Index Optimization** - Ensure proper database indexes
- **Query Rewriting** - Optimize complex queries

### Caching Strategies

- **Query Caching** - Cache expensive query results
- **Fragment Caching** - Cache computed values
- **Request Caching** - Deduplicate queries within requests

### Database Optimization

- **Connection Pooling** - Optimize database connections
- **Query Plan Analysis** - Understand database execution
- **Index Analysis** - Ensure optimal indexing strategy

## 🚨 Common Performance Issues

### N+1 Query Problem

```crystal
# Problem: N+1 queries
users = User.all
users.each { |user| puts user.posts.count }

# Solution: Preload associations
users = User.includes(:posts).all
users.each { |user| puts user.posts.count }
```

### Slow Complex Queries

```crystal
# Problem: Complex unoptimized query
results = execute_complex_join_without_indexes

# Solution: Add indexes and optimize
create_index :posts, [:user_id, :published_at]
results = execute_optimized_query
```

### Memory Usage Issues

```crystal
# Problem: Loading too much data
all_users = User.all  # Loads entire table

# Solution: Use pagination and limits
users = User.limit(100).offset(page * 100)
```

## 🔗 Integration with Other Examples

- **[../caching/](../caching/)** - Implement caching based on performance insights
- **[../blog/](../blog/)** - See performance monitoring in a real application
- **[../basic/](../basic/)** - Apply performance monitoring to simple examples

## 🧪 Testing Performance

### Performance Test Example

```crystal
describe "API Performance" do
  it "should handle dashboard load efficiently" do
    # Clear performance data
    CQL::Performance.monitor.clear_data

    # Execute test
    get "/api/dashboard"

    # Validate performance
    metrics = CQL::Performance.monitor.metrics_summary
    expect(metrics.slow_queries).to eq(0)
    expect(metrics.n_plus_one_patterns).to eq(0)
  end
end
```

---

**Ready to optimize your application's performance?** Start with the comprehensive monitoring example and build performance awareness into your development workflow! 📊
