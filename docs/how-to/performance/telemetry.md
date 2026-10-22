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

## Pinning a connection

```crystal
schema.with_connection do |connection|
  User.query.using(connection).to_a
end
```

`using` works on queries, inserts, updates and deletes, so a transaction's connection can be
passed explicitly instead of relying on the fiber-local one.

Statements served from the result cache emit no event, and the duration includes pool wait time.
`Schema#alter` and migrations bypass telemetry. `event.error.message` may contain data, so
redact it before shipping it anywhere.

Call `CQL::Telemetry.reset!` in specs to remove all subscribers.
