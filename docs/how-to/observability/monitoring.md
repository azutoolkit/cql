---
description: "Wire telemetry and the performance monitor into a production app: export metrics, count queries per request and expose a health check."
---

# Monitor Performance

Build on [telemetry](telemetry.md) and the [performance monitor](query-profiler.md):

- Slow-query alerts and SQL logs: [Alert on Slow Queries and Log SQL](telemetry.md#alert-on-slow-queries-and-log-sql).
- Exporters that do I/O: subscribe with `async: true` ([Deliver Off the Query Path](telemetry.md#deliver-off-the-query-path)) and call `CQL::Telemetry.flush` and `CQL::Performance.flush` in `at_exit`.
- Reports: call `CQL::Performance.report` on your own timer ([Generate a Report](query-profiler.md#generate-a-report)); CQL never writes one; `config.reporting.auto_generate` and `reporting.interval` are deprecated and have no effect.
- Cost per statement: [What monitoring costs](query-profiler.md#what-monitoring-costs).

## Export Query Metrics

```crystal
module QueryMetrics
  @@count = Atomic(Int64).new(0)
  @@errors = Atomic(Int64).new(0)
  @@micros = Atomic(Int64).new(0)
  @@wait_micros = Atomic(Int64).new(0)

  def self.record(event : CQL::Telemetry::QueryEvent) : Nil
    @@count.add(1)
    @@errors.add(1) unless event.success?
    @@micros.add(event.duration.total_microseconds.to_i64)
    @@wait_micros.add(event.pool_wait.total_microseconds.to_i64)  # part of duration
  end

  def self.snapshot
    count = Math.max(@@count.get, 1)
    {queries: @@count.get, errors: @@errors.get,
     avg_ms: @@micros.get / count / 1000.0, avg_pool_wait_ms: @@wait_micros.get / count / 1000.0,
     dropped: CQL::Telemetry.dropped_events}
  end
end

CQL::Telemetry.subscribe("query_metrics", async: true) { |event| QueryMetrics.record(event) }

QueryMetrics.snapshot  # after three statements, one of them failed
# => {queries: 3, errors: 1, avg_ms: 0.028, avg_pool_wait_ms: 0.0, dropped: 0}
```

Push the snapshot to your metrics system on a timer. A rising pool wait with a steady statement time means the pool, not the SQL, is the bottleneck; a growing `dropped` count means the async queue is too small or its consumer too slow.

## Count Queries per Request

```crystal
module RequestQueries
  @@counts = Hash(String, Int32).new(0)
  @@mutex = Mutex.new

  def self.install : Nil
    CQL::Telemetry.subscribe("request_queries") do |event|
      if id = event.context
        @@mutex.synchronize { @@counts[id] += 1 }
      end
    end
  end

  def self.finish(id : String) : Int32
    @@mutex.synchronize { @@counts.delete(id) || 0 }
  end
end

class QueryCountHandler
  include HTTP::Handler

  def call(context)
    id = context.request.headers["X-Request-ID"]? || Random::Secure.hex(8)
    CQL::Telemetry.with_context(id) { call_next(context) }
    Log.info { "#{context.request.path}: #{RequestQueries.finish(id)} queries" }
  end
end
# INFO - /posts: 2 queries
```

The context is per fiber, so queries in fibers the request spawns are not counted. To find repeated statements within a request, see [Use Per-Request Caching](../caching/per-request.md).

## Expose a Health Check

```crystal
CQL::Performance.enable_production_mode!  # health data needs the monitor on

class HealthHandler
  include HTTP::Handler

  def call(context)
    return call_next(context) unless context.request.path == "/health/db"

    summary = CQL::Performance.metrics_summary
    pool = AppDB.pool_stats
    context.response.status_code = CQL::Performance.healthy? ? 200 : 503
    context.response.content_type = "application/json"
    {
      healthy:          CQL::Performance.healthy?,
      p95_ms:           summary["p95_query_time_ms"],
      p95_pool_wait_ms: summary["p95_pool_wait_ms"],
      pool:             {in_flight: pool.in_flight, idle: pool.idle, max: pool.max},
      critical:         CQL::Performance.critical_issues.map(&.message),
    }.to_json(context.response)
  end
end
# {"healthy":true,"p95_ms":0.0329,"p95_pool_wait_ms":0.0016,"pool":{"in_flight":0,"idle":1,"max":0},"critical":[]}
```

What feeds the health score and each key is in [Health and Metrics](query-profiler.md#health-and-metrics).

## See Also

- [Telemetry](telemetry.md)
- [Profile Queries and Detect N+1](query-profiler.md)
- [Avoid N+1 Queries](../performance/n-plus-one.md)
- [Optimize Queries](../performance/optimize-queries.md)
- [Use Per-Request Caching](../caching/per-request.md)
