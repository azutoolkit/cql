# Monitor Performance

Track query performance and identify bottlenecks in your CQL application.

## Prerequisites

- Working CQL application
- Log or metrics infrastructure

## Enable Query Logging

CQL publishes every statement it runs (selects, inserts, updates, deletes, DDL) to `CQL::Telemetry`. Log one line per statement:

```crystal
require "log"

Log.setup do |c|
  c.bind("cql.*", :debug, Log::IOBackend.new)
end

# [select] 1.23ms SELECT ... (1 params)
CQL::Telemetry.log_queries
```

Bound parameter values are not part of the line and are not captured unless you set `CQL::Telemetry.capture_params = true`.

## Log Slow Queries

Only react to queries exceeding a threshold:

```crystal
CQL::Telemetry.alert_on_slow(100.milliseconds) do |event|
  Log.warn { "[SLOW QUERY] (#{event.duration.total_milliseconds.round(2)}ms) #{event.sql}" }
end
```

## Track Query Metrics

Collect metrics for monitoring systems by subscribing to events:

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

CQL::Telemetry.subscribe("query_metrics") do |event|
  QueryMetrics.record(event.duration)
end
```

Each event also carries `operation` (`:select`, `:insert`, `:update`, `:delete`, `:ddl`, `:explain`), `rows_affected`, `adapter`, `param_count` and `error`, so you can break metrics down by operation or count failures. Subscribers are isolated: one that raises does not affect queries or other subscribers. Remove one with `CQL::Telemetry.unsubscribe("query_metrics")`.

## Per-Request Tracking

Tag everything a request does with `CQL::Telemetry.with_context`, then group events by that tag:

```crystal
module RequestQueries
  @@events = Hash(String, Array(CQL::Telemetry::QueryEvent)).new
  @@mutex = Mutex.new

  def self.install
    CQL::Telemetry.subscribe("request_queries") do |event|
      if request_id = event.context
        @@mutex.synchronize { (@@events[request_id] ||= [] of CQL::Telemetry::QueryEvent) << event }
      end
    end
  end

  def self.finish(request_id : String)
    events = @@mutex.synchronize { @@events.delete(request_id) } || [] of CQL::Telemetry::QueryEvent
    {count: events.size, total_ms: events.sum(&.duration.total_milliseconds)}
  end
end

# In your request middleware
RequestQueries.install
CQL::Telemetry.with_context(request_id) do
  response = handle_request(request)
  summary = RequestQueries.finish(request_id)
  Log.info { "Request completed: #{summary[:count]} queries in #{summary[:total_ms].round(2)}ms" }
  response
end
```

The context is fiber-local, so work you `spawn` inside the block is not tagged.

## Query Analysis

Analyze query patterns:

```crystal
module QueryAnalyzer
  @@patterns = Hash(String, {count: Int32, total_time: Time::Span}).new

  def self.install
    CQL::Telemetry.subscribe("query_analyzer") { |event| record(event.sql, event.duration) }
  end

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

CQL binds values as `?` (or `$1` on PostgreSQL) placeholders, so `event.sql` is usually already normalized; the regexes only matter for raw SQL you executed with literals.

## Built-in Profiler and N+1 Detector

The `CQL::Performance` module profiles queries, detects N+1 patterns and produces reports:

```crystal
CQL::Performance.enable_development_mode!   # or enable_production_mode!

CQL::Performance.with_context("UsersController#index") do
  User.all
end

puts CQL::Performance.report                # formatted performance report
CQL::Performance.metrics_summary            # Hash of headline numbers
CQL::Performance.healthy?                   # => Bool
CQL::Performance.critical_issues            # => Array(CQL::Performance::Issue)
```

Use `CQL::Performance.enable_sql_logging` / `disable_sql_logging` for formatted SQL logging (bound values are left out unless `config.logging.include_params` is on; see [Log SQL](query-profiler.md#log-sql)), and `CQL::Performance.configure { |config| ... }` to tune thresholds. See [Telemetry](telemetry.md) for the event API.

## Database Statistics

Query database statistics directly on a pooled connection:

```crystal
# PostgreSQL
rows = MyDB.exec_query do |conn|
  conn.query_all(<<-SQL, as: {String, Int64, Int64, Int64})
    SELECT relname, seq_scan, COALESCE(idx_scan, 0), n_live_tup
    FROM pg_stat_user_tables
    ORDER BY seq_scan DESC
    LIMIT 10
  SQL
end

rows.each do |table, seq_scan, idx_scan, _live_rows|
  puts "#{table}: #{seq_scan} seq scans, #{idx_scan} idx scans"
end
```

## Connection Pool Monitoring

Monitor pool usage with `Schema#pool_stats` (it never checks out a connection):

```crystal
spawn do
  loop do
    stats = MyDB.pool_stats
    limit = stats.max == 0 ? "unlimited" : stats.max.to_s
    Log.info { "Pool: #{stats.in_flight} in use, #{stats.idle} idle, #{stats.open} open (max #{limit})" }
    sleep 30.seconds
  end
end
```

## Export to Prometheus

```crystal
require "prometheus"

query_counter = Prometheus.counter("cql_queries_total", "Total CQL queries")
query_duration = Prometheus.histogram("cql_query_duration_seconds", "Query duration")

CQL::Telemetry.subscribe("prometheus") do |event|
  query_counter.inc
  query_duration.observe(event.duration.total_seconds)
end
```

## Export From a Background Subscriber

An exporter that does I/O should not add to query latency. Subscribe it with `async: true` and read pool pressure from the event:

```crystal
CQL::Telemetry.subscribe("statsd", async: true) do |event|
  StatsD.timing("sql.#{event.operation}", event.duration)
  StatsD.timing("sql.pool_wait", event.pool_wait) # the part of duration spent waiting for a pooled connection
end

CQL::Telemetry.flush(5.seconds)    # at shutdown or in a spec: waits for delivery; the timeout keeps a stuck exporter from hanging it
CQL::Telemetry.dropped_events      # events a full queue discarded; alert when it grows
```

A rising `pool_wait` with a steady statement time means the pool, not the SQL, is the bottleneck. For headline numbers without a subscriber, read the profiler's p95 and the p95 wait for a pooled connection (the monitor must be on):

```crystal
summary = CQL::Performance.metrics_summary
StatsD.gauge("sql.p95_ms", summary["p95_query_time_ms"].as(Float64))
StatsD.gauge("sql.pool_wait_p95_ms", summary["p95_pool_wait_ms"].as(Float64))
```

Queue capacity, ordering and drops are in [Telemetry](telemetry.md); what the monitor measures and costs is in [Profile Queries](query-profiler.md#health-and-metrics) and [What monitoring costs](query-profiler.md#what-monitoring-costs).

## Verify Setup

Test your monitoring:

```crystal
# Run some queries
User.all
Post.where(published: true).all
User.find(1)

# Check your logs/metrics
QueryMetrics.stats  # => {count: 3, total_ms: 15.5, avg_ms: 5.17}  (counts every statement CQL ran)
```

## See Also

- [Optimize Queries](optimize-queries.md)
- [Avoid N+1 Queries](n-plus-one.md)
- [Telemetry](telemetry.md)
- [Performance Monitoring Tutorial](../../tutorials/real-world-examples/performance-monitoring.md)
