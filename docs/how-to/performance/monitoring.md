# Monitor Performance

Track query performance and identify bottlenecks in your CQL application.

## Prerequisites

- Working CQL application
- Log or metrics infrastructure

## Enable Query Logging

Log all queries with execution time:

```crystal
MyDB.on_query do |sql, duration|
  Log.info { "[CQL] (#{duration.total_milliseconds.round(2)}ms) #{sql}" }
end
```

## Log Slow Queries

Only log queries exceeding a threshold:

```crystal
SLOW_QUERY_THRESHOLD = 100.milliseconds

MyDB.on_query do |sql, duration|
  if duration > SLOW_QUERY_THRESHOLD
    Log.warn { "[SLOW QUERY] (#{duration.total_milliseconds.round(2)}ms) #{sql}" }
  end
end
```

## Track Query Metrics

Collect metrics for monitoring systems:

```crystal
module QueryMetrics
  @@query_count = Atomic(Int64).new(0)
  @@total_time = Atomic(Int64).new(0)

  def self.record(duration : Time::Span)
    @@query_count.add(1)
    @@total_time.add(duration.total_microseconds.to_i64)
  end

  def self.stats
    {
      count: @@query_count.get,
      total_ms: @@total_time.get / 1000.0,
      avg_ms: @@total_time.get / [@@query_count.get, 1].max / 1000.0
    }
  end

  def self.reset
    @@query_count.set(0)
    @@total_time.set(0)
  end
end

MyDB.on_query do |sql, duration|
  QueryMetrics.record(duration)
end
```

## Per-Request Tracking

Track queries per HTTP request:

```crystal
class QueryTracker
  property queries = [] of {String, Time::Span}

  def record(sql : String, duration : Time::Span)
    @queries << {sql, duration}
  end

  def total_time
    @queries.sum(&.[1])
  end

  def count
    @queries.size
  end
end

# In your request middleware
tracker = QueryTracker.new
MyDB.with_query_callback(tracker.method(:record)) do
  # Handle request
  response = handle_request(request)

  Log.info { "Request completed: #{tracker.count} queries in #{tracker.total_time.total_milliseconds}ms" }
  response
end
```

## Query Analysis

Analyze query patterns:

```crystal
module QueryAnalyzer
  @@patterns = Hash(String, {count: Int32, total_time: Time::Span}).new

  def self.record(sql : String, duration : Time::Span)
    # Normalize query by removing specific values
    pattern = sql.gsub(/= \d+/, "= ?")
                 .gsub(/= '[^']*'/, "= ?")
                 .gsub(/IN \([^)]+\)/, "IN (?)")

    existing = @@patterns[pattern]? || {count: 0, total_time: Time::Span.zero}
    @@patterns[pattern] = {
      count: existing[:count] + 1,
      total_time: existing[:total_time] + duration
    }
  end

  def self.report
    @@patterns.to_a
      .sort_by { |_, stats| -stats[:total_time].total_milliseconds }
      .first(10)
      .each do |pattern, stats|
        puts "#{stats[:count]}x (#{stats[:total_time].total_milliseconds.round(2)}ms total): #{pattern[0..100]}"
      end
  end
end
```

## Database Statistics

Query database statistics directly:

```crystal
# PostgreSQL
stats = MyDB.exec(<<-SQL
  SELECT
    relname as table,
    seq_scan,
    idx_scan,
    n_live_tup as rows
  FROM pg_stat_user_tables
  ORDER BY seq_scan DESC
  LIMIT 10
SQL
)

stats.each do |row|
  puts "#{row["table"]}: #{row["seq_scan"]} seq scans, #{row["idx_scan"]} idx scans"
end
```

## Connection Pool Monitoring

Monitor pool usage:

```crystal
spawn do
  loop do
    stats = MyDB.pool_stats
    Log.info { "Pool: #{stats[:busy]}/#{stats[:size]} connections in use" }
    sleep 30.seconds
  end
end
```

## Export to Prometheus

```crystal
require "prometheus"

query_counter = Prometheus.counter("cql_queries_total", "Total CQL queries")
query_duration = Prometheus.histogram("cql_query_duration_seconds", "Query duration")

MyDB.on_query do |sql, duration|
  query_counter.inc
  query_duration.observe(duration.total_seconds)
end
```

## Verify Setup

Test your monitoring:

```crystal
# Run some queries
User.all
Post.where(published: true).all
User.find(1)

# Check your logs/metrics
QueryMetrics.stats  # => {count: 3, total_ms: 15.5, avg_ms: 5.17}
```

## See Also

- [Optimize Queries](optimize-queries.md)
- [Avoid N+1 Queries](n-plus-one.md)
- [Performance Monitoring Tutorial](../../tutorials/real-world-examples/performance-monitoring.md)
