# Performance Monitoring

This tutorial shows you how to track and optimize query performance in your CQL application.

## What You'll Learn

- Setting up query logging
- Identifying slow queries
- Detecting N+1 query problems
- Building a performance dashboard
- Optimization strategies

## Prerequisites

- A working CQL application
- Basic understanding of database performance concepts

## Step 1: Enable Query Logging

Configure logging to capture all database queries:

```crystal
# src/database.cr
require "log"

# Configure logging
Log.setup do |c|
  backend = Log::IOBackend.new
  c.bind("cql.*", :debug, backend)
end

AppDB = CQL::Schema.define(
  :app_db,
  adapter: CQL::Adapter::Postgres,
  uri: DATABASE_URL
) do
end
```

## Step 2: Create a Query Monitor

Build a simple query monitor to track execution times:

```crystal
# src/monitoring/query_monitor.cr
module QueryMonitor
  @@queries = [] of QueryRecord
  @@enabled = true

  struct QueryRecord
    property sql : String
    property duration_ms : Float64
    property timestamp : Time
    property source : String

    def initialize(@sql, @duration_ms, @source = "")
      @timestamp = Time.utc
    end

    def slow?(threshold_ms = 100.0)
      duration_ms > threshold_ms
    end
  end

  def self.enable
    @@enabled = true
  end

  def self.disable
    @@enabled = false
  end

  def self.record(sql : String, duration_ms : Float64, source = "")
    return unless @@enabled
    @@queries << QueryRecord.new(sql, duration_ms, source)
  end

  def self.queries
    @@queries
  end

  def self.clear
    @@queries.clear
  end

  def self.slow_queries(threshold_ms = 100.0)
    @@queries.select(&.slow?(threshold_ms))
  end

  def self.total_time_ms
    @@queries.sum(&.duration_ms)
  end

  def self.report
    puts "Query Performance Report"
    puts "========================"
    puts "Total queries: #{@@queries.size}"
    puts "Total time: #{total_time_ms.round(2)}ms"
    puts ""

    if (slow = slow_queries).any?
      puts "Slow queries (>100ms):"
      slow.each do |q|
        puts "  #{q.duration_ms.round(2)}ms - #{q.sql[0, 80]}..."
      end
      puts ""
    end

    # Group by similar queries (potential N+1)
    grouped = @@queries.group_by { |q| normalize_query(q.sql) }
    repeated = grouped.select { |_, v| v.size > 1 }

    if repeated.any?
      puts "Repeated queries (potential N+1):"
      repeated.each do |pattern, instances|
        puts "  #{instances.size}x - #{pattern[0, 60]}..."
      end
    end
  end

  private def self.normalize_query(sql : String)
    # Replace specific values with placeholders
    sql.gsub(/= \d+/, "= ?")
       .gsub(/= '[^']*'/, "= ?")
       .gsub(/IN \([^)]+\)/, "IN (?)")
  end
end
```

## Step 3: Wrap Database Operations

Create a timing wrapper:

```crystal
# src/monitoring/timed_queries.cr
module TimedQueries
  def self.measure(source = "")
    start = Time.monotonic
    result = yield
    duration = (Time.monotonic - start).total_milliseconds
    QueryMonitor.record("query", duration, source)
    result
  end
end

# Usage in your code:
posts = TimedQueries.measure("load_posts") do
  Post.where(published: true).all
end
```

## Step 4: Detect N+1 Queries

N+1 queries happen when you load a list, then query for each item:

```crystal
# BAD: N+1 problem
posts = Post.where(published: true).all
posts.each do |post|
  author = post.user  # This triggers a query for EACH post!
  puts "#{post.title} by #{author.try(&.name)}"
end

# The monitor would show something like:
# 1x SELECT * FROM posts WHERE published = true
# 10x SELECT * FROM users WHERE id = ?
```

### Solution: Eager Loading

```crystal
# GOOD: Single query with join
posts = Post.where(published: true).all
user_ids = posts.map(&.user_id).uniq
users_by_id = User.where { id.in(user_ids) }.all.index_by(&.id)

posts.each do |post|
  author = users_by_id[post.user_id]?
  puts "#{post.title} by #{author.try(&.name)}"
end

# The monitor shows:
# 1x SELECT * FROM posts WHERE published = true
# 1x SELECT * FROM users WHERE id IN (?, ?, ...)
```

## Step 5: Create a Dashboard

Build a simple performance dashboard:

```crystal
# src/monitoring/dashboard.cr
require "./query_monitor"

module PerformanceDashboard
  def self.display
    puts ""
    puts "="*60
    puts "CQL Performance Dashboard"
    puts "="*60
    puts ""

    display_query_stats
    display_slow_queries
    display_n_plus_one_warnings
    display_recommendations
  end

  private def self.display_query_stats
    queries = QueryMonitor.queries
    return puts "No queries recorded" if queries.empty?

    puts "Query Statistics"
    puts "-"*40

    total = queries.size
    total_time = QueryMonitor.total_time_ms

    puts "Total queries: #{total}"
    puts "Total time: #{total_time.round(2)}ms"
    puts "Average time: #{(total_time / total).round(2)}ms"
    puts ""
  end

  private def self.display_slow_queries
    slow = QueryMonitor.slow_queries(50.0)
    return if slow.empty?

    puts "Slow Queries (>50ms)"
    puts "-"*40

    slow.sort_by(&.duration_ms).reverse.first(5).each do |q|
      puts "#{q.duration_ms.round(2)}ms"
      puts "  #{q.sql[0, 70]}..."
      puts ""
    end
  end

  private def self.display_n_plus_one_warnings
    grouped = QueryMonitor.queries.group_by { |q|
      q.sql.gsub(/= \d+/, "= ?").gsub(/= '[^']*'/, "= ?")
    }

    warnings = grouped.select { |_, v| v.size > 3 }
    return if warnings.empty?

    puts "Potential N+1 Queries"
    puts "-"*40

    warnings.each do |pattern, instances|
      puts "Executed #{instances.size} times:"
      puts "  #{pattern[0, 60]}..."
      puts ""
    end
  end

  private def self.display_recommendations
    queries = QueryMonitor.queries
    return if queries.empty?

    puts "Recommendations"
    puts "-"*40

    # Check for too many queries
    if queries.size > 50
      puts "- High query count (#{queries.size}). Consider:"
      puts "  * Caching frequently accessed data"
      puts "  * Combining queries with joins"
      puts ""
    end

    # Check for slow average
    avg = QueryMonitor.total_time_ms / queries.size
    if avg > 50
      puts "- Slow average query time (#{avg.round(2)}ms). Consider:"
      puts "  * Adding indexes to filtered columns"
      puts "  * Optimizing complex queries"
      puts ""
    end

    # Check for N+1
    grouped = queries.group_by { |q| q.sql.gsub(/= \d+/, "= ?") }
    repeated = grouped.count { |_, v| v.size > 3 }
    if repeated > 0
      puts "- Detected #{repeated} potential N+1 patterns. Consider:"
      puts "  * Using eager loading"
      puts "  * Batching related queries"
      puts ""
    end

    if queries.size <= 50 && avg <= 50 && repeated == 0
      puts "Performance looks good!"
    end
  end
end
```

## Step 6: Monitor in Tests

Add performance assertions to your tests:

```crystal
# spec/performance_spec.cr
describe "Performance" do
  before_each do
    QueryMonitor.clear
  end

  it "loads post list efficiently" do
    # Create test data
    10.times { create_post }

    # Load posts
    QueryMonitor.enable
    posts = Post.where(published: true).all
    posts.each { |p| p.user }

    # Assert query count
    QueryMonitor.queries.size.should be <= 2

    # Assert no slow queries
    QueryMonitor.slow_queries(100.0).should be_empty
  end
end
```

## Step 7: Production Monitoring

For production, integrate with your monitoring stack:

```crystal
# src/monitoring/metrics.cr
module Metrics
  def self.record_query(duration_ms : Float64, query_type : String)
    # Send to your metrics system (StatsD, Prometheus, etc.)
    # Example with a hypothetical metrics client:
    # MetricsClient.timing("cql.query.duration", duration_ms, tags: ["type:#{query_type}"])
  end

  def self.increment_query_count(query_type : String)
    # MetricsClient.increment("cql.query.count", tags: ["type:#{query_type}"])
  end

  def self.record_slow_query(sql : String, duration_ms : Float64)
    # Log slow queries for investigation
    Log.warn { "Slow query (#{duration_ms.round(2)}ms): #{sql}" }
  end
end
```

## Optimization Checklist

When you find performance issues:

### 1. Add Missing Indexes

```crystal
# Check if filtering on a column without an index
Post.where(status: "published").all  # Is status indexed?
```

### 2. Use Select to Limit Columns

```crystal
# Instead of loading entire records
titles = Post.where(published: true).select(:id, :title).all
```

### 3. Batch Large Operations

```crystal
# Instead of loading all records
Post.find_each(batch_size: 100) do |post|
  process(post)
end
```

### 4. Cache Expensive Queries

```crystal
# Cache results of expensive aggregations
def total_views
  @total_views ||= Post.where(published: true).sum(:views_count)
end
```

## Summary

You've learned:

1. How to enable query logging
2. Building a query monitor
3. Detecting N+1 queries
4. Creating a performance dashboard
5. Monitoring in tests and production

## Next Steps

- [Optimize Queries](../../how-to/performance/optimize-queries.md)
- [Avoid N+1 Queries](../../how-to/performance/n-plus-one.md)
- [Enable Query Caching](../../how-to/caching/query-cache.md)
