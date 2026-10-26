---
description: "Subscribe to an event for every statement CQL runs, alert on slow ones, trace them, and watch transactions and the connection pool."
---

# Telemetry

## Subscribe to Query Events

```crystal
CQL::Telemetry.subscribe("metrics") do |event|
  event.sql            # "SELECT users.id, ... FROM users WHERE users.id = ? LIMIT ?"
  event.operation      # :select, :insert, :update, :delete, :ddl or :explain
  event.duration       # Time::Span, including the wait for a pooled connection
  event.pool_wait      # the part of duration spent waiting for that connection
  event.param_count    # 2
  event.params         # nil unless capture_params is on
  event.rows_affected  # Int64 for writes and Schema#exec, nil for selects
  event.adapter        # CQL::Adapter::SQLite
  event.context        # from with_context, else nil
  event.error          # the exception of a failed statement, else nil
  event.success?       # error.nil?
end

CQL::Telemetry.subscribed?("metrics")  # => true
CQL::Telemetry.unsubscribe("metrics")
CQL::Telemetry.reset!                  # in specs: drops every subscriber, the tracer and capture_params
```

Events cover queries, inserts, updates, deletes, `Schema#exec` and `explain`; `Schema#alter` and migrations publish none. Raw SQL (`Schema#exec`, the native engine's `exec` and `pipeline`) is labeled by its first statement: `schema.exec("SELECT 1")` is a `:select`, an `INSERT` an `:insert`, and any other statement (`CREATE`, `ALTER`, `SET`, `PRAGMA`) `:ddl`. Subscribers run inline before the statement returns. One that raises is logged and never affects the query or other subscribers.

## Alert on Slow Queries and Log SQL

```crystal
CQL::Telemetry.alert_on_slow(200.milliseconds) do |event|  # subscriber name "cql.slow_query"
  Log.warn { "slow query (#{event.duration.total_milliseconds.round(1)}ms): #{event.sql}" }
end

CQL::Telemetry.log_queries         # name "cql.log", debug lines on the "cql.telemetry" log source
CQL::Telemetry.log_queries(:info)  # another severity
# [select] 0.02ms SELECT users.id, ... FROM users WHERE users.id = ? LIMIT ? (2 params)
# [select] 0.04ms SELECT users.id FROM users WHERE nope = ? (1 params) FAILED: SQLite3::Exception
```

Log lines never contain bound values or error messages. For formatted SQL with durations, use [Log SQL](query-profiler.md#log-sql).

## Deliver Off the Query Path

```crystal
CQL::Telemetry.async_queue_capacity = 8192  # default 4096; read when the first async subscriber builds the queue
CQL::Telemetry.subscribe("exporter", async: true) { |event| Exporter.record(event) }
CQL::Telemetry.alert_on_slow(200.milliseconds, async: true) { |event| Exporter.slow(event) }
CQL::Telemetry.log_queries(async: true)

CQL::Telemetry.flush(5.seconds)  # => true once every earlier event was delivered, false on timeout
CQL::Telemetry.dropped_events    # => Int64: a full queue drops events instead of blocking the statement
```

Async subscribers share one background fiber and one FIFO queue, kept until `reset!` (which restores the default capacity). Subscribing a name in one mode removes it from the other. After `unsubscribe` and a `flush` that returns true, a removed subscriber gets nothing more.

{% hint style="warning" %}
Async moves work out of query latency, not off the CPU. On one thread the consumer runs only when the application yields, so a tight loop of statements can fill the queue; queued events keep their SQL, error and captured values in memory until delivered.
{% endhint %}

## Capture Parameters and Tag Events

```crystal
CQL::Telemetry.capture_params = true  # event.params becomes a copy of the bound values; off by default

CQL::Telemetry.with_context("req-123") do
  User.find(1)                       # event.context == "req-123"
  CQL::Telemetry.current_context     # => "req-123"
  spawn { User.find(2) }             # a spawned fiber is not tagged
end
```

The context is per fiber and is the same one `CQL::Performance.with_context` sets. It also appears in SQL log lines whatever `capture_params` says, so use a request id, not personal data. `event.error.message` may hold data too: redact it before shipping it.

## Trace Statements

```crystal
class TimingTracer < CQL::Telemetry::Tracer
  def in_span(operation : Symbol, sql : String, & : -> T) : T forall T
    started = Time.instant
    begin
      yield  # runs the statement: call it exactly once and let its exceptions propagate
    ensure
      Log.info { "span sql.#{operation}: #{(Time.instant - started).total_microseconds.round}µs" }
    end
  end
end

CQL::Telemetry.tracer = TimingTracer.new  # wrap an OpenTelemetry (or other) span the same way
```

A tracer that skips the block raises, and one that swallows the statement's error has it re-raised. CQL depends on no tracing library.

## Transactions

```crystal
CQL::Telemetry.subscribe_transactions("tx") do |event|  # also takes async: true
  event.state     # CQL::Telemetry::TransactionState::Begin, Commit or Rollback
  event.id        # shared by a Begin and its Commit or Rollback
  event.duration  # time since Begin, pool wait included; zero for Begin
  event.nested    # a transaction was already open on this fiber
  event.error     # what caused the Rollback (a DB::Rollback too), or why COMMIT failed
end

CQL::Telemetry.unsubscribe_transactions("tx")
```

`Schema#transaction` publishes `Begin` before it checks out a connection. An exception ends in `Rollback` and is re-raised, `DB::Rollback` is still swallowed, and a failing `COMMIT` is reported as `Rollback`. `Schema#transaction(tx)` publishes nothing, and a transaction that began before the first subscriber registered publishes nothing. Where DDL is transactional (SQLite, PostgreSQL), `alter`, `build`, `Table#create!`/`drop!`/`truncate!`, `Migrator.new`, `up`, `down` and `pending_migrations` (once per migration it checks) run inside `Schema#transaction` and publish these events (`nested` when a transaction is already open).

{% hint style="warning" %}
Calling `tx.rollback` yourself and returning normally still reports `Commit`. An async transaction subscriber shares the query queue and its bound, so handle an end event whose `Begin` was dropped.
{% endhint %}

## Connection Pool

```crystal
stats = AppDB.pool_stats  # CQL::PoolStats; never checks out a connection, never raises
stats.open       # connections open
stats.idle       # open and not checked out
stats.in_flight  # checked out now (open - idle)
stats.max        # 0 means unlimited

# Pin statements to one connection; pool_wait is then about zero
AppDB.with_connection do |connection|
  User.query.using(connection).to_a
end
```

`pool_stats` returns zeros until the first query when the pool opens with `?initial_pool_size=0`. `using` also works on inserts, updates and deletes, and inside a transaction `with_connection` yields the transaction's connection. A checkout that fails reports its wait until the failure.

## See Also

- [Monitor Performance](monitoring.md)
- [Profile Queries and Detect N+1](query-profiler.md)
- [What Monitoring Costs](query-profiler.md#what-monitoring-costs)
- [Avoid N+1 Queries](../performance/n-plus-one.md)
- [Use Transactions](../data-operations/transactions.md)
