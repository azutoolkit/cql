# Profile Queries and Detect N+1

Turn on the `CQL::Performance` monitor to profile statements, find N+1 patterns, log SQL, and read health metrics and reports.

## Turn It On

```crystal
CQL::Performance.enable_development_mode!          # profiler, N+1 detector and SQL logging
CQL::Performance.enable_production_mode!           # profiler and strict N+1 detection, no SQL logging
CQL::Performance.enable_monitoring                 # switch on the current monitor
CQL.configure { |c| c.monitor_performance = true } # the same, when the block finishes
CQL::Performance.disable!                          # everything off

CQL::Performance.configure do |config|
  config.profiling.slow_query_threshold = 50.milliseconds # default 100 ms
  config.profiling.very_slow_threshold = 500.milliseconds # default 1 s
  config.detection.threshold = 3                          # default 2 repetitions
end

# Presets: development_config, test_config, production_config, minimal_config
CQL::Performance.monitor = CQL::Performance::Monitor.new(CQL::Performance.production_config)
```

Without setup, the monitor reads the environment:

```bash
CRYSTAL_ENV=development      # or CQL_ENV: monitoring and SQL logging on
CRYSTAL_ENV=test             # off; slow threshold 10 ms, 100 recorded queries
CRYSTAL_ENV=production       # off, as with any other value or none
CQL_MONITORING_ENABLED=true  # overrides monitoring
CQL_SQL_LOGGING=true         # overrides SQL logging, which logs only while monitoring is on
CQL_SLOW_QUERY_MS=200        # slow query threshold
```

The monitor records every select, insert, update and delete CQL runs, failed ones included, but not `Schema#exec`, `explain` or the native engine's `exec` and `pipeline` (wrap those in `track`). A component that raises while recording is logged and never fails the statement.

{% hint style="warning" %}
Enabling is one-way: `monitor_performance = false` and `CQL.reset_config!` leave a running monitor on. Use `CQL::Performance.disable!`.
{% endhint %}

```crystal
# Record on a background fiber instead (off in every preset): a statement pays ~20 ns plus a copy of its params
CQL::Performance.configure(&.monitoring.async=(true))
# config.monitoring.async_queue_capacity  # default 4096; a full queue drops statements (monitor_dropped_events)
CQL::Performance.flush(5.seconds)         # metrics lag until the queue drains: flush in tests and at shutdown
```

`track` blocks stay synchronous, and replacing the monitor closes the old queue.

## Log SQL

```crystal
CQL::Performance.enable_sql_logging(colorize: false, pretty: true) # turns monitoring on too; NO_COLOR disables colors
CQL::Performance.configure do |config| # info; warn from slow_query_threshold; error from very_slow_threshold
  config.logging.include_params = true # default false: adds bound values and unredacted driver errors
  config.logging.max_param_length = 20 # default 50 characters per value
  config.logging.max_sql_length = 500  # default 500 characters of SQL
end
CQL::Performance.disable_sql_logging
```

```text
INFO - cql.performance.monitor: ✅ SQL (12.04μs) {req-123}
  SELECT users.id, users.name, users.email
    FROM users
    WHERE users.name = ?
📊 Parameters: [A very long name tha...]
ERROR - cql.performance.monitor: Query failed: no such column: nope
SQL: SELECT users.id FROM users WHERE nope = ?
Params: [secret]
```

`{req-123}` is the [context](telemetry.md#capture-parameters-and-tag-events). Without `include_params`, a driver error's quoted span becomes `'?'` in logs and the metrics JSON (`Duplicate entry '?'`); text outside quotes and values written into the SQL itself are kept.

## Read the Profile

```crystal
profiler = CQL::Performance.monitor.profiler.not_nil!

# Per normalized statement (numbers and placeholders become ?, quoted strings '?')
profiler.statistics.each do |sql, stats|  # count, total_ms, avg_ms, min_ms, max_ms
  puts "#{stats[:count]}x avg #{stats[:avg_ms].round(2)}ms  #{sql}"
end
# 3x avg 0.01ms  SELECT users.id, users.name, users.email FROM users WHERE users.id = ? LIMIT ?

profiler.slowest_queries(5)  # QueryData: sql, params, execution_time, timestamp, rows_affected, error
profiler.issues              # :very_slow_queries (critical), :high_frequency_slow_query (high: > 100 runs averaging > 50 ms)

CQL::Performance.configure do |config|
  config.profiling.log_slow_queries = true       # default: WARN "SLOW QUERY (7.75μs): SELECT ..."
  config.profiling.log_all_queries = false       # default: record only slow queries (at most 1000 kept)
  config.profiling.max_recorded_queries = 10_000 # default cap on recorded queries
  config.profiling.max_tracked_statements = 1000 # distinct statements; later ones count under "(other)"
end
# Slow-query and N+1 warnings use the "cql.performance.base_performance_component" log source
```

## Detect N+1 Queries

```crystal
detector = CQL::Performance.monitor.detector.not_nil!
detector.patterns.each do |pattern|
  puts "#{pattern.repetition_count}x #{pattern.repeated_query}"
  puts "  after #{pattern.parent_query}"  # "Unknown" once it left the window
end
# 3x SELECT users.id, users.name, users.email FROM users WHERE users.id = ? LIMIT ?
#   after SELECT posts.id, posts.title, posts.user_id FROM posts

detector.issues  # severity by repetitions: 2-5 low, 6-20 medium, 21-50 high, more critical

CQL::Performance.configure do |config|
  config.detection.detection_window = 10  # default: recent statements compared
  config.detection.strict_mode = true     # warn at each new pattern (production preset)
  # config.detection.ignore_patterns      # ["COMMIT", "BEGIN", "ROLLBACK"]: prefixes never counted
end
# WARN - N+1 Query Pattern Detected: SELECT users.id, ... WHERE users.id = ? LIMIT ? (2 times)

CQL::Performance.start_relation_loading("user", "Post")  # markers take window slots; reports do not show them
CQL::Performance.end_relation_loading
```

To fix a pattern, see [Avoid N+1 Queries](../performance/n-plus-one.md).

{% hint style="info" %}
A count never exceeds `detection_window`, so with the default of 10 an N+1 issue is at most `medium` and never appears in `critical_issues` or `high_priority_issues`.
{% endhint %}

## Health and Metrics

```crystal
CQL::Performance.healthy?              # => true while the health score is 80 or more
CQL::Performance.critical_issues       # => Array(CQL::Performance::Issue)
CQL::Performance.high_priority_issues  # critical and high
CQL::Performance.metrics_summary
# => {"total_queries" => 8, "slow_queries" => 4, "error_rate_percent" => 0.0, "avg_query_time_ms" => 0.0068,
#     "p95_query_time_ms" => 0.0113, "n_plus_one_patterns" => 1, "health_score" => "97", "total_issues" => 1,
#     "uptime_seconds" => 0.00036, "observed_statements" => 8, "monitor_overhead_ms" => 0.0259,
#     "p95_pool_wait_ms" => 0.0, "monitor_dropped_events" => 0}

metrics = CQL::Performance.metrics       # PerformanceMetrics
metrics.query_metrics.latency            # p50, p95, p99 from a histogram: within 25% from 4 µs up
metrics.monitor                          # observed_statements, overhead (timed on 1 statement in 64), pool_wait, dropped_events
                                         # (a pool wait under 1 µs is a free connection and counts as zero)
metrics.issues_by_type(:n_plus_one)
metrics.issues_by_severity(:critical)
metrics.slowest_queries(5)               # Array(QueryData), params included
metrics.most_frequent_queries(5)         # {sql:, count:, avg_time:}
CQL::Performance.export_metrics_as_json  # metrics.to_json; slow queries carry params only with include_params
```

## Generate a Report

```crystal
puts CQL::Performance.report             # config.reporting.format: "text" ("logger" in the development preset)
puts CQL::Performance.report("console")  # colored; "logger" is an alias
File.write("tmp/perf.html", CQL::Performance.report("html"))
File.write("tmp/perf.json", CQL::Performance.report("json"))  # an unknown format falls back to text

class CsvReportFormatter < CQL::Performance::ReportFormatter
  def format(report : CQL::Performance::PerformanceReport) : String
    "queries,slow,errors\n#{report.total_queries},#{report.slow_queries},#{report.errors}\n"
  end
end

generator = CQL::Performance::UnifiedReportGenerator.new
generator.register_formatter("csv", CsvReportFormatter.new)
generator.available_formats  # => ["text", "json", "html", "console", "logger", "csv"]
CQL::Performance.monitor = CQL::Performance::Monitor.new(CQL::Performance.production_config, report_generator: generator)
puts CQL::Performance.report("csv")
```

## Track Statements CQL Does Not Run

```crystal
name = CQL::Performance.track("SELECT name FROM users WHERE id = ?", [1_i64] of DB::Any) do
  legacy_db.query_one("SELECT name FROM users WHERE id = ?", 1, as: String)
end  # an exception is counted as an error, recorded and re-raised

CQL::Performance.monitor.clear  # profile, patterns and counters; call it in before_each
```

Transactions and pool pressure are not profiled: see [Telemetry](telemetry.md#transactions) and [`pool_stats`](telemetry.md#connection-pool).

## What monitoring costs

From `benchmarks/telemetry_overhead_bench.cr`: `find` and `create!` on in-memory SQLite, one thread, `--release` on a 4-core VM (Crystal 1.22), mean of two runs. Compare bytes per iteration; time differences under about 10% are noise.

| Configuration | `find` | `create!` |
| --- | --- | --- |
| all off | 0.83 µs, 336 B | 3.28 µs, 2.44 kB |
| one synchronous subscriber | +80 ns, +0 B | +130 ns, +0 B |
| one `async: true` subscriber¹ | +45 ns, +0 B | about 0, +0 B |
| no-op tracer | about 0, +0 B | about 0, +0 B |
| production monitor | +340 ns, +0 B | +260 ns, +0 B |
| production monitor, `monitoring.async`¹ | +35 ns, +0 B | about 0, +0 B |
| SQL logging filtered out by the log level | +40 ns, +0 B | about 0, +0 B |

¹ The benchmark never yields, so these rows show the hand-off, not the background work, which costs about as much as the synchronous version.

The monitor allocates only a slow query's `QueryData` and SQL log lines. The benchmark repeats one statement, so the monitor rows are the N+1 detector's worst case. Under `-Dpreview_mt`, waking a parked consumer costs about half a microsecond.

## See Also

- [Monitor Performance](monitoring.md)
- [Telemetry](telemetry.md)
- [Avoid N+1 Queries](../performance/n-plus-one.md)
- [Optimize Queries](../performance/optimize-queries.md)
- [How CQL Keeps Queries Fast](../../explanation/performance-design.md)
