# Profile Queries and Detect N+1

This guide shows you how to use CQL's built-in performance monitor: the query profiler, the N+1 detector, health metrics and reports.

It lives in `CQL::Performance`. Every select, insert, update and delete CQL runs is timed once in `CQL::Execution.run` and recorded by the monitor (DDL and `explain` are not), so once monitoring is enabled you get data without wrapping your queries; a failed statement is recorded with its real duration. A profiler or detector that raises while recording is logged at error and never changes the statement's outcome. For events you can subscribe to and ship to a metrics system, see [Telemetry](telemetry.md). The two are independent and can run together.

## Turn It On

Monitoring is opt-in: it runs several regex passes and takes two global locks per query, so it is off unless you enable it. Any of these turns it on:

```crystal
CQL.configure { |c| c.monitor_performance = true } # when the configure block finishes
CQL::Performance.enable_monitoring
CQL::Performance.enable_sql_logging                # SQL is logged by the monitor, so this enables it too
```

The environment can enable it as well: `CQL_MONITORING_ENABLED=true`, or `CRYSTAL_ENV`/`CQL_ENV=development` (see the table below). `CQL.build_schema` calls `enable_sql_logging` when `sql_logging` is on, which is the default when `CRYSTAL_ENV=development` (not when it is unset). Enabling is one-way: `monitor_performance = false` and `CQL.reset_config!` do not switch off a monitor that is already on; use `CQL::Performance.disable!` for that.

Health checks and dashboards that read `CQL::Performance.metrics` only see data once monitoring is on, so enable it explicitly in production if you rely on them. The profiler keeps slow queries, including their bound parameters, in memory; the JSON export leaves the parameters out unless `logging.include_params` is on (see [Health and Metrics](#health-and-metrics)).

Quick setups:

```crystal
CQL::Performance.enable_development_mode!   # profiling, N+1 detection and SQL logging
CQL::Performance.enable_production_mode!    # profiling and strict N+1 detection, no SQL logging
CQL::Performance.disable!                   # everything off
```

Or configure the pieces you want:

```crystal
CQL::Performance.configure do |config|
  config.profiling.slow_query_threshold = 50.milliseconds
  config.profiling.very_slow_threshold = 500.milliseconds
  config.detection.threshold = 3
  config.logging.enabled = true
end
```

To record in the background instead:

```crystal
CQL::Performance.configure(&.monitoring.async=(true)) # queue capacity: config.monitoring.async_queue_capacity (4096)
CQL::Performance.flush(5.seconds)                     # before reading metrics in a test, or at shutdown (pass a timeout)
```

With `monitoring.async`, a statement run through CQL hands itself to one background fiber through a bounded queue, which costs the query about 20 ns plus a copy of its bound values instead of the whole recording; profiling, N+1 detection and SQL logging then happen on that fiber. Metrics lag until the queue drains, a full queue drops statements instead of blocking, `track` blocks stay synchronous, and `Monitor#close` stops the queue so later statements are recorded inline. Queued statements keep their SQL, their error (whose message may hold data) and a copy of their bound values in memory until recorded; the bound is a count, not bytes, so lower the capacity for large binary parameters. It is off in every preset. On one Crystal thread this moves the work out of query latency, not out of CPU.

Without any setup the monitor starts from `Config.from_env`:

| Environment | Effect |
| --- | --- |
| `CRYSTAL_ENV=development` or `CQL_ENV=development` | monitoring and SQL logging on |
| `CRYSTAL_ENV=test` or `CQL_ENV=test` | monitoring and logging off, slow threshold 10 ms |
| `CRYSTAL_ENV=production` or `CQL_ENV=production` | monitoring and logging off |
| none of the above | monitoring and logging off |
| `CQL_MONITORING_ENABLED=true\|false` | override monitoring |
| `CQL_SQL_LOGGING=true\|false` | override SQL logging (logs only while monitoring is on) |
| `CQL_SLOW_QUERY_MS=200` | slow query threshold in milliseconds |

Presets are available as `CQL::Performance.development_config`, `test_config`, `production_config` and `minimal_config`. Install your own with `CQL::Performance.monitor = CQL::Performance::Monitor.new(config)`.

## Log SQL

With SQL logging on, the monitor logs each statement to the `cql.performance.monitor` source: at info, at warn once it takes `profiling.slow_query_threshold` or longer, and at error from `profiling.very_slow_threshold`. A statement that raises is logged at error as `Query failed: <message>` followed by its SQL.

Bound parameter values are left out of these lines, since they often hold personal data or secrets. To log them, opt in:

```crystal
CQL::Performance.enable_sql_logging
CQL::Performance.configure do |config|
  config.logging.include_params = true  # adds "Parameters: [...]", and "Params: [...]" to a failure
  config.logging.max_param_length = 20  # characters kept of each value
end
```

| Setting | Default | Meaning |
| --- | --- | --- |
| `logging.include_params` | false | log the bound values of each statement and of a failed one |
| `logging.max_param_length` | 50 | characters kept of each logged value (`...` marks the cut) |
| `logging.max_sql_length` | 500 | characters kept of the SQL in a statement's line |
| `logging.colorize` | true | ANSI colors; `enable_sql_logging(colorize:)` sets it |
| `logging.pretty_format` | true | break the SQL over lines at its clauses; `enable_sql_logging(pretty:)` sets it |

`include_params` covers the bound values and a failed statement's driver error message. Drivers print the offending value inside quotes without escaping the quotes it holds, so one span, from the earliest to the latest quote of either kind, is replaced by `'?'` / `"?"` (`Duplicate entry 'x' for key 'y'` is logged, and kept in the metrics JSON, as `Duplicate entry '?'`); when a kind of quote occurs only once, everything from it to the end of the message is replaced (`can't connect` becomes `can'?`). Text outside quotes is not redacted: encoding errors that print the value's bytes, and messages raised by the database itself (`RAISE EXCEPTION`, `SIGNAL`, `RAISE(ABORT)`). Values written into the SQL text itself are logged as they are. The `include_params` value in force when a failed query is recorded decides its stored and exported error text.

## Read the Profile

The profiler keeps running statistics per normalized query (literal numbers, quoted strings and placeholders are replaced by `?`, so `WHERE id = 1` and `WHERE id = 2` count as one query).

```crystal
CQL::Performance.enable_monitoring
profiler = CQL::Performance.monitor.profiler.not_nil!

profiler.statistics.each do |sql, stats|
  puts "#{stats[:count]}x avg #{stats[:avg_ms].round(2)}ms max #{stats[:max_ms].round(2)}ms  #{sql}"
end

profiler.slowest_queries(5).each do |query|
  puts "#{query.execution_time.total_milliseconds.round(1)}ms  #{query.sql}"
end
```

`statistics` returns `count`, `total_ms`, `avg_ms`, `min_ms` and `max_ms` for each query. `slowest_queries(limit)` returns `QueryData` with `sql`, `params`, `execution_time`, `timestamp`, `rows_affected` and `error`.

### What Is Recorded

| Setting | Default | Meaning |
| --- | --- | --- |
| `profiling.slow_query_threshold` | 100 ms | a query slower than this is "slow" |
| `profiling.very_slow_threshold` | 1 s | a slow query above this is reported as critical |
| `profiling.log_slow_queries` | true | log slow queries as warnings |
| `profiling.log_all_queries` | false | keep every query, not only slow ones, in the recorded list |
| `profiling.max_recorded_queries` | 10,000 (100 in test) | cap on the recorded list |
| `profiling.max_tracked_statements` | 1000 | distinct statement shapes tracked in the statistics; later shapes are aggregated under `"(other)"` |

Statistics are kept for all queries. The slow query list holds up to 1000 entries.

### Profiler Issues

`profiler.issues` flags:

- `very_slow_queries` (critical): queries slower than `very_slow_threshold`;
- `high_frequency_slow_query` (high): a query run more than 100 times with an average above 50 ms.

## Detect N+1 Queries

The detector watches the most recent queries (`detection.detection_window`, default 10). When the same normalized query appears at least `detection.threshold` times (default 2), it records a pattern together with the query that came just before it.

```crystal
CQL::Performance.enable_monitoring
detector = CQL::Performance.monitor.detector.not_nil!

detector.patterns.each do |pattern|
  puts "#{pattern.repetition_count}x #{pattern.repeated_query}"
  puts "  after #{pattern.parent_query}"
end

detector.issues.each do |issue|
  puts "[#{issue.severity}] #{issue.message}"
end
```

Severity grows with repetitions: 2 to 5 is `low`, 6 to 20 `medium`, 21 to 50 `high`, above that `critical`. Statements starting with `COMMIT`, `BEGIN` or `ROLLBACK` are ignored (`detection.ignore_patterns`).

With `config.detection.strict_mode = true` a warning is logged as soon as a new pattern is found, which suits staging and specs:

```text
N+1 Query Pattern Detected: SELECT * FROM users WHERE id = ? (12 times)
```

You can mark relation loading yourself so the report shows where a burst of queries came from:

```crystal
CQL::Performance.start_relation_loading("author", "Post")
posts.each(&.author)
CQL::Performance.end_relation_loading
```

CQL's own relation loaders do not call these hooks, so without them the detector relies on the repeated SQL alone. To fix what it finds, see [Avoid N+1 Queries](n-plus-one.md).

## Label Work With a Context

```crystal
CQL::Performance.with_context("PostsController#index") do
  Post.query.limit(20).to_a
end
```

The context is attached to log lines produced while SQL logging is on, and to the telemetry events of the block (`QueryEvent#context`). It is the same per-fiber context as `CQL::Telemetry.with_context`, so concurrent requests each keep their own; work you `spawn` inside the block is not tagged.

## Health and Metrics

```crystal
CQL::Performance.healthy?              # => true when the health score is 80 or higher
CQL::Performance.critical_issues       # => Array(Issue)
CQL::Performance.high_priority_issues
CQL::Performance.metrics_summary
# => {"total_queries" => ..., "slow_queries" => ..., "error_rate_percent" => ...,
#     "avg_query_time_ms" => ..., "p95_query_time_ms" => ..., "n_plus_one_patterns" => ...,
#     "health_score" => ..., "total_issues" => ..., "uptime_seconds" => ...,
#     "observed_statements" => ..., "monitor_overhead_ms" => ..., "p95_pool_wait_ms" => ...}
```

`CQL::Performance.metrics` returns a `PerformanceMetrics` with the full breakdown (query, N+1, cache, system and health metrics, top queries and patterns). It also offers `to_json`, `issues_by_type(:n_plus_one)`, `issues_by_severity(:critical)`, `slowest_queries(limit)` and `most_frequent_queries(limit)`. The slow queries in `to_json` (and `CQL::Performance.export_metrics_as_json`) have no `params` key unless `config.logging.include_params` is on; `slowest_queries(limit)` still returns each `QueryData` with its `params`. In the query lists, `avg_time` and `total_time` are in milliseconds.

`metrics.query_metrics.latency` is a `LatencyPercentiles` (`p50`, `p95`, `p99`) over every statement the profiler recorded, and `query_metrics.to_h` has them as `p50_execution_time_ms`, `p95_execution_time_ms` and `p99_execution_time_ms`. They come from a fixed-size histogram, so an estimate is within 25% from 4 µs up and never outside the recorded minimum and maximum; recording one costs no allocation. `metrics.monitor` (also `Monitor#counters`, and `"monitor"` in `to_h`) is what the monitor observed itself: `observed_statements`, the time spent recording them (`overhead`, estimated by timing one statement in 64, so it settles after a few thousand statements) and the p50/p95/p99 wait for a pooled connection (`pool_wait`, from statements run through `CQL::Execution.run`; `track` blocks have none; a wait under 1 µs is a free connection and counts as zero, without taking a lock). Together they add about 15 ns and no allocation to each monitored statement on one thread; with several threads recording at once (`-Dpreview_mt`) the shared counters add contention.

## Generate a Report

```crystal
puts CQL::Performance.report             # format from config.reporting.format ("text" by default)
puts CQL::Performance.report("console")  # colored terminal output
File.write("tmp/perf.html", CQL::Performance.report("html"))
File.write("tmp/perf.json", CQL::Performance.report("json"))
```

`UnifiedReportGenerator` renders a `PerformanceReport` with one formatter per format: `text`, `json`, `html`, `console` and `logger` (an alias of `console`). An unknown format falls back to `text`. Every format shows the overall latency: a `Latency: p50 … / p95 … / p99 …` line in `text` and `console`, a p95 card in `html`, and `p50_ms`, `p95_ms` and `p99_ms` under `metrics` in `json` (`PerformanceReport#latency`, and `"latency"` in its `to_h`). Each per-statement tracker in a report's `stats` adds `p50_time_ms`, `p95_time_ms` and `p99_time_ms`.

### Add Your Own Format

```crystal
class CsvReportFormatter < CQL::Performance::ReportFormatter
  def format(report : CQL::Performance::PerformanceReport) : String
    "queries,slow,errors\n#{report.total_queries},#{report.slow_queries},#{report.errors}\n"
  end
end

generator = CQL::Performance::UnifiedReportGenerator.new
generator.register_formatter("csv", CsvReportFormatter.new)
generator.available_formats # => ["text", "json", "html", "console", "logger", "csv"]
```

Hand the generator to a monitor and use it:

```crystal
CQL::Performance.monitor = CQL::Performance::Monitor.new(report_generator: generator)
puts CQL::Performance.report("csv")
```

## Track Statements CQL Does Not Run

Wrap other database calls to include them in the profile:

```crystal
result = CQL::Performance.track("SELECT * FROM legacy_users WHERE id = ?", [1_i64] of DB::Any) do
  legacy_db.query_one("SELECT * FROM legacy_users WHERE id = ?", 1)
end
```

An exception in the block is counted as an error, recorded with the query, and re-raised.

## Transactions and the Connection Pool

The profiler measures statements. The `BEGIN` and `COMMIT` of a transaction are issued by the database driver, not by CQL, so a transaction does not appear as a query here. The statements inside it do.

To observe transactions, subscribe to the transaction events from [Telemetry](telemetry.md#transactions):

```crystal
CQL::Telemetry.subscribe_transactions("perf") do |event|
  Log.info { "tx #{event.id} #{event.state} #{event.duration.total_milliseconds.round(1)}ms nested=#{event.nested}" }
end
```

A long transaction shows up as a `Commit` or `Rollback` event with a large `duration` (which includes the wait for a pooled connection). For pool pressure, read `schema.pool_stats` (`open`, `idle`, `in_flight`, `max`; see [Telemetry](telemetry.md#connection-pool)). `in_flight` close to `max` while queries are slow usually means the pool, not the SQL, is the bottleneck.

## Reset Between Runs

```crystal
CQL::Performance.monitor.clear   # profiler data, detector patterns and the error count
```

Call it in `before_each` of specs that assert on the profile. Use `CQL::Performance.monitor = CQL::Performance::Monitor.new(CQL::Performance.test_config)` to switch monitoring off for a spec suite.

## Related

- [Monitor Performance](monitoring.md)
- [Telemetry](telemetry.md)
- [Avoid N+1 Queries](n-plus-one.md)
- [Optimize Queries](optimize-queries.md)
