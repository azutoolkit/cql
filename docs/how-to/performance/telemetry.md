# Telemetry

Every query and DML statement CQL runs (selects, inserts, updates, deletes, `Schema#exec` DDL and `explain`) passes through
`CQL::Execution.run`, which publishes a `CQL::Telemetry::QueryEvent` to your subscribers.

```crystal
CQL::Telemetry.subscribe("metrics") do |event|
  StatsD.timing("sql.#{event.operation}", event.duration)
end

CQL::Telemetry.alert_on_slow(200.milliseconds) { |event| Alerts.warn(event.sql) }
CQL::Telemetry.log_queries                       # one debug log line per statement (plain text)
```

An event carries `sql`, `operation` (`:select`, `:insert`, `:update`, `:delete`, `:ddl`,
`:explain`), `duration`, `param_count`, `adapter`, `error`, `rows_affected`, `context`, `params` (only with `capture_params`) and `success?`.

## Parameters are redacted by default

`event.params` is `nil` unless you opt in with `CQL::Telemetry.capture_params = true`; the count is
always available.

## Context

```crystal
CQL::Telemetry.with_context("req-123") { ... } # fiber-local, attached to events in the block
```

## Tracing (OpenTelemetry, Dashforge, ...)

Subclass `CQL::Telemetry::Tracer` and implement `in_span(operation, sql, &)` to wrap each
statement in a span. `in_span` must call the block exactly once and let its exceptions propagate;
a tracer that skips the block raises, and one that swallows an error has it re-raised. CQL adds no hard dependency on any tracing library.

## Transactions

`Schema#transaction` publishes a `CQL::Telemetry::TransactionEvent` to transaction subscribers:

```crystal
CQL::Telemetry.subscribe_transactions("dashboard") do |event|
  # event.state: Begin, Commit or Rollback
  Dashboard.record(event.id, event.state, event.duration, event.nested, event.error)
end
```

- `Begin` is published before the connection is checked out, so the `duration` of the matching `Commit`/`Rollback`
  (same `id`) includes pool wait time. `Begin` has a zero duration.
- A `DB::Rollback` or any exception is a `Rollback` with the exception in `error`; exceptions are still re-raised and
  `DB::Rollback` is still swallowed, as before. A `Commit` whose `COMMIT` statement fails is reported as a `Rollback` too.
- `nested` is informational: a transaction was already open on this fiber when this one started.
- `Schema#transaction(tx)` (an existing transaction) publishes nothing.
- **Known limit:** calling `tx.rollback` yourself and then returning normally still reports `Commit`.
- Subscribers fail in isolation, like query subscribers, and nothing is allocated or timed while none are registered.
  A transaction that began before the first subscriber registered publishes no events.

`Telemetry.unsubscribe_transactions(name)` removes one, `Telemetry.subscribed?(name)` tells whether a query or
transaction subscriber is registered under that name, and `reset!` clears both kinds.

## Connection pool

```crystal
stats = schema.pool_stats # CQL::PoolStats
stats.open      # connections currently open
stats.idle      # open and not checked out
stats.in_flight # checked out right now (open - idle)
stats.max       # 0 means unlimited
```

`pool_stats` never checks out a connection and never raises; with `?initial_pool_size=0` it returns zeros until the
first query.

## Pinning a connection

```crystal
schema.with_connection do |connection|
  User.query.using(connection).to_a
end
```

`using` works on queries, inserts, updates and deletes, so a transaction's connection can be
passed explicitly instead of relying on the fiber-local one.

Every executed statement emits an event, and the duration includes pool wait time.
`Schema#alter` statements (including those inside migrations) bypass telemetry. `event.error.message` may contain data, so
redact it before shipping it anywhere.

Call `CQL::Telemetry.reset!` in specs to remove all subscribers.
