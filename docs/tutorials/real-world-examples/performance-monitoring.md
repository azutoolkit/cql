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

CQL publishes every statement it runs (selects, inserts, DDL, transactions) to `CQL::Telemetry`. Turn on one log line per statement:

```crystal
# src/database.cr
require "cql"
require "log"

DATABASE_URL = ENV["DATABASE_URL"]

AppDB = CQL::Schema.define(
  :app_db,
  adapter: CQL::Adapter::Postgres,
  uri: DATABASE_URL
) do
end

# Send the query log to STDOUT at debug level
Log.setup do |c|
  c.bind("cql.*", :debug, Log::IOBackend.new)
end

# One line per statement: [select] 1.23ms SELECT ... (1 params)
CQL::Telemetry.log_queries
```

Bound parameter values are not part of the log line (and are not captured at all unless you set `CQL::Telemetry.capture_params = true`), so the log stays safe to ship.

## Step 2: Create a Query Monitor

Subscribe to telemetry events and keep them in memory to analyse execution times:

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

  # Feed the monitor from CQL's telemetry events
  def self.install
    CQL::Telemetry.subscribe("query_monitor") do |event|
      record(event.sql, event.duration.total_milliseconds, event.context || "")
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

## Step 3: Tag Database Operations

Call `QueryMonitor.install` once at startup. To see where queries come from, wrap code in `CQL::Telemetry.with_context`; every statement run inside the block carries the context, which the monitor stores as the query's source:

```crystal
QueryMonitor.install

posts = CQL::Telemetry.with_context("load_posts") do
  Post.where(published: true).all
end
```

To be told about slow statements as they happen, use `alert_on_slow`:

```crystal
CQL::Telemetry.alert_on_slow(100.milliseconds) do |event|
  Log.warn { "Slow query (#{event.duration.total_milliseconds.round(2)}ms): #{event.sql}" }
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
# 1x SELECT ... FROM posts WHERE posts.published = ?
# 10x SELECT ... FROM users WHERE users.id = ?
```

### Solution: Eager Loading

For `has_many` and `belongs_to` associations, `preload` loads the related records in one extra query:

```crystal
users = User.where(active: true).preload(:posts).all # 2 queries, however many users
users.each { |user| puts "#{user.username}: #{user.posts.size} posts" }
```

For a `belongs_to` association, load the parents in one query and look them up in memory:

```crystal
# GOOD: two queries in total
posts = Post.where(published: true).all
user_ids = posts.map(&.user_id).uniq
users_by_id = User.where { id.in(user_ids) }.all.index_by(&.id)

posts.each do |post|
  author = users_by_id[post.user_id]?
  puts "#{post.title} by #{author.try(&.name)}"
end

# The monitor shows:
# 1x SELECT ... FROM posts WHERE posts.published = ?
# 1x SELECT ... FROM users WHERE users.id IN (?, ?, ...)
```

CQL also ships an automatic detector, `CQL::Performance::NPlusOneDetector`, which flags repeated queries (see Step 7).

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

    # Load posts and their authors
    QueryMonitor.install # once per test run, e.g. in spec_helper.cr
    QueryMonitor.clear
    posts = Post.where(published: true).all
    users_by_id = User.where { id.in(posts.map(&.user_id).uniq) }.all.index_by(&.id)
    posts.each { |p| users_by_id[p.user_id]? }

    # Assert query count
    QueryMonitor.queries.size.should be <= 2

    # Assert no slow queries
    QueryMonitor.slow_queries(100.0).should be_empty
  end
end
```

## Step 7: Production Monitoring

`CQL::Performance` profiles every query, detects N+1 patterns and produces reports. Configure it once at startup:

```crystal
CQL::Performance.configure do |config|
  config.monitoring.enabled = true
  config.profiling.slow_query_threshold = 50.milliseconds
  config.detection.threshold = 3 # repeats of one query before it counts as N+1
end

# Later, e.g. from a health endpoint or a scheduled job
puts CQL::Performance.report("console") # also "text", "json" and "html"
pp CQL::Performance.metrics_summary
Log.warn { "Performance issues found" } unless CQL::Performance.healthy?
```

To forward timings to your metrics stack (StatsD, Prometheus, OpenTelemetry), subscribe to telemetry events:

```crystal
CQL::Telemetry.subscribe("metrics") do |event|
  # MetricsClient.timing("cql.query.duration", event.duration.total_milliseconds,
  #   tags: ["operation:#{event.operation}", "ok:#{event.success?}"])
end
```

For OpenTelemetry-style tracing, implement `CQL::Telemetry::Tracer` and assign it to `CQL::Telemetry.tracer`. See the [telemetry how-to](../../how-to/performance/telemetry.md).

## Optimization Checklist

When you find performance issues:

### 1. Add Missing Indexes

```crystal
# Check if filtering on a column without an index
Post.where(published: true).all  # Is published indexed?
```

### 2. Use Select to Limit Columns

```crystal
# Instead of loading entire records
titles = Post.where(published: true).select(:id, :title).to_a # rows with only id and title filled in
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

1. How to enable query logging with `CQL::Telemetry`
2. Building a query monitor on telemetry events
3. Detecting N+1 queries
4. Creating a performance dashboard
5. Monitoring in tests and production with `CQL::Performance`

## Next Steps

- [Optimize Queries](../../how-to/performance/optimize-queries.md)
- [Avoid N+1 Queries](../../how-to/performance/n-plus-one.md)
- [Enable Query Caching](../../how-to/caching/query-cache.md)
