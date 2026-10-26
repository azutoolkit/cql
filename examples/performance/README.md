# Performance Monitoring Examples

> [!WARNING]
> None of the four programs here compiles against the current `src/`. They were written for an earlier
> `CQL::Performance` API. For the current one, use [Monitor Performance](../../docs/how-to/observability/monitoring.md)
> and [Profile Queries and Detect N+1](../../docs/how-to/observability/query-profiler.md).

| File | Meant to show | Why it does not compile |
| --- | --- | --- |
| `performance_metrics_demo.cr` | `CQL::Performance.configure`, `track` around simulated queries, `start_relation_loading` for an N+1 pattern, then `CQL::Performance.metrics`: summary, query, N+1, health and system metrics, slowest and most frequent queries, issues, JSON export | it requires only `../../src/performance`, which needs `CQL::Telemetry` from `src/cql` (`undefined constant CQL::Telemetry::QueryEvent`). With `require "../../src/cql"` instead, it compiles and runs |
| `logger_report_example.cr` | the logger report format on simulated N+1 and slow queries | `CQL::Performance::PerformanceMonitor`, `after_query` and `generate_comprehensive_report` no longer exist; the class is now `CQL::Performance::Monitor`, and reports come from `generate_report` |
| `performance_monitoring_example.cr` | query plan analysis, N+1 detection, profiling and HTML/JSON reports on a SQLite `AcmeDB` | it requires `src/performance/event_system`, `analyzers/query_plan_analyzer`, `profilers/query_profiler` and `reports/report_generators`, which were removed |
| `sql_colorize_test.cr` | SQL logging settings (`sql_logging`, `sql_logging_colorize`) | it requires `src/performance/sql_log_formatter`, which was removed; it also runs no query, it only prints SQL strings |

The current API, as `performance_metrics_demo.cr` uses it:

```crystal
CQL::Performance.configure do |config|
  config.monitoring.enabled = true
  config.profiling.enabled = true
  config.detection.enabled = true
end

CQL::Performance.track("SELECT * FROM users WHERE id = ?", [1] of DB::Any) { }

metrics = CQL::Performance.metrics
metrics.summary # {"total_queries" => 1, "slow_queries" => 0, ...}
metrics.slowest_queries(3)
metrics.healthy?
```

`CQL::Performance.track` records a statement you time yourself. Statements run through CQL reach the monitor on
their own once monitoring is on.

## See Also

- [Monitor Performance](../../docs/how-to/observability/monitoring.md)
- [Telemetry](../../docs/how-to/observability/telemetry.md)
- [Avoid N+1 Queries](../../docs/how-to/performance/n-plus-one.md)
- [blog/](../blog/README.md): a running app with `monitor_performance = true` and a logger report
