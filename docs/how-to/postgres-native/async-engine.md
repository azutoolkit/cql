---
description: "CQL::Postgres::AsyncEngine runs CQL statements over the native driver on its own fiber-safe connection pool."
---

# Use AsyncEngine and Its Connection Pool

## Connect

```crystal
require "cql"

engine = CQL::Postgres::AsyncEngine.connect(
  "postgres://app:secret@db.internal/app?sslmode=verify-full&pool_size=10"
)
# The URL is parsed here, so a malformed option raises ArgumentError at once.
# Connections open on first use; pool_min_size=N opens N now, so a wrong host fails at startup.
# cockroachdb:// selects CQL::Adapter::CockroachDB, other schemes CQL::Adapter::Postgres; adapter: overrides.
```

## Run Statements

```crystal
User.query.where(active: true).using(engine).to_a
AppDB.query.from(:users).select(:name).where("age > ?", 18).using(engine).all(as: String) # ... WHERE age > $1
AppDB.insert.into(:users).values(name: "Ada", email: "ada@example.com").using(engine).commit

# Raw SQL that returns no rows; without arguments the text may hold several statements
engine.exec("CREATE TABLE IF NOT EXISTS notes (id bigserial PRIMARY KEY, body text)")
engine.exec("INSERT INTO notes (body) VALUES ($1)", ["first".as(DB::Any)])
```

{% hint style="warning" %}
**`using(engine)`** changes where a statement runs, not its SQL: the schema's adapter renders it. A statement from a SQLite schema sends `?` placeholders and fails with `SyntaxOrAccessError`.
{% endhint %}

## Pool Options

Pool settings are URL query options:

| Option | Meaning | Default |
| --- | --- | --- |
| `pool_size` | Maximum connections, at least 1 | 10 |
| `pool_min_size` | Connections opened by `connect`, 0 to `pool_size` | 0 |
| `checkout_timeout` | Seconds to wait for a free connection, then `PoolTimeout` | 5 |
| `health_check_after` | Ping a connection idle longer than this many seconds before lending it | 30 |
| `max_queries` | Retire a connection after this many requests | none |
| `max_idle_lifetime` | Retire a connection idle this many seconds | none |

```crystal
engine = CQL::Postgres::AsyncEngine.connect(
  "postgres://app:secret@db.internal/app?pool_size=20&pool_min_size=2&max_queries=5000&max_idle_lifetime=300"
)
engine.pool.stats.to_s # => "0 in use, 2 idle, 20 max"

# Retirement is checked when a connection would be lent out: no background reaper, no refill.
# Pings and resets count as requests. pool_size=abc raises ArgumentError.
#
# Connection options:
#   connect_timeout=10        seconds for each connecting step; 0 waits forever
#   application_name=cql
#   statement_cache_size=256  prepared statements kept per connection; 0 turns the cache off
#   binary_params=false       send parameters in binary; see the COPY and binary parameters guide
#   search_path=app           any other key is sent to the server as a startup parameter
```

{% hint style="info" %}
These options apply to `AsyncEngine` and `EngineSource`. A `CQL::Schema` or `DB.open` without a source uses crystal-db's pool: `initial_pool_size`, `max_pool_size`, `checkout_timeout`, `retry_attempts` and friends.
{% endhint %}

## Setup and Reset Hooks

```crystal
engine = CQL::Postgres::AsyncEngine.connect(
  ENV["DATABASE_URL"],
  setup: ->(c : CQL::Postgres::Connection) { c.exec_all("SET search_path TO app, public") }, # every new connection
  reset: "DISCARD ALL"                                                                     # every return to the pool
)
# On return, a transaction the borrower left open is rolled back, then reset runs, the statement
# cache is cleared and setup runs again. If any step fails, the connection is dropped, not reused.
```

## Borrow One Connection

```crystal
engine.with_connection do |connection|
  connection.session.server_parameters["server_version"] # => "16.15 (Ubuntu 16.15-0ubuntu0.24.04.1)"
  connection.scalar("SELECT 1")                         # a DB::Connection: crystal-db calls work
end
# One request at a time per connection; fibers sharing it queue. It returns to the pool after the block.
```

## Transactions

```crystal
engine.transaction do |tx|
  AppDB.insert.into(:users).values(name: "Grace", email: "grace@example.com").using(tx).commit
  User.query.where(name: "Grace").using(tx).to_a
end
# Commits when the block returns; rolls back and re-raises when it raises.
# raise DB::Rollback.new rolls back quietly, and transaction returns nil.
# tx is valid only inside its block; later use raises CQL::Postgres::TransactionClosed.
```

Isolation, savepoints and `synchronous_commit` are in [Configure TLS, Poolers, Timeouts and Transactions](tls-and-poolers.md#transactions-isolation-and-savepoints).

## Handle Errors

```crystal
begin
  AppDB.insert.into(:users).values(name: "Ada", email: "ada@example.com").using(engine).commit
rescue ex : CQL::Postgres::UniqueViolation
  ex.sqlstate   # => "23505"
  ex.constraint # => "users_email_key"
  ex.detail     # => "Key (email)=(ada@example.com) already exists."
end

# CQL::Postgres::ServerError (sqlstate, server_message, detail, hint, table, column, constraint)
#   IntegrityViolation    UniqueViolation, ForeignKeyViolation, NotNullViolation, CheckViolation
#   TransactionRollback   SerializationFailure, DeadlockDetected
#   SyntaxOrAccessError   UndefinedTable, UndefinedColumn
#   InvalidAuthorization, QueryCanceled
# Pool: CQL::Postgres::PoolTimeout, CQL::Postgres::PoolClosed
```

{% hint style="warning" %}
`message` quotes the server only for SQLSTATE classes that carry no data, such as `23`; `server_message` and `detail` can contain bound values, so log them with care. Driver messages never contain passwords.
{% endhint %}

## Observe Statements

```crystal
CQL::Telemetry.subscribe("pg") do |event|
  puts "[#{event.operation}] #{event.duration.total_milliseconds}ms #{event.sql}"
end
CQL::Telemetry.capture_params = true # adds the bound values as event.params; off by default

# Statements run through CQL::Execution, so telemetry and the performance monitor see them.
# engine.exec and engine.pipeline pass track: false: telemetry sees them, the monitor does not.
```

## Read Values

```crystal
engine.with_connection do |connection|
  connection.query_one(
    "SELECT $1::numeric, $2::int4[], '12:30'::time",
    "1.50", [1, 2],
    as: {CQL::Postgres::Types::DecimalText, String, Time::Span}
  ) # => {DecimalText(@text="1.50"), "{1,2}", 12:30:00}
end
# Parameters: nil, Bool, Int, Float, String, Bytes, Time, UUID, JSON::Any, DecimalText, and arrays of these.
# Decoded: int2/4/8, float4/8, bool, text, bytea, uuid, oid, date, time, timestamp(tz), json(b), numeric.
# Other types, arrays included, arrive as String. Infinite dates raise CQL::Postgres::UnsupportedValue.
```

## Troubleshooting

**`PoolTimeout`**: every connection stayed busy for `checkout_timeout`. Raise `pool_size`, hold connections for less time, or raise `checkout_timeout`.

**`TransactionClosed`**: a `tx` escaped its block. Run the work inside the block.

**SQLSTATE `42P05` or `26000` behind a pooler**: see [poolers](tls-and-poolers.md#poolers).

## See Also

- [Run a Schema on the AsyncEngine's Pool](schema-on-engine.md)
- [Stream Large Results and Pipeline Statements](streaming-and-pipelining.md)
- [Configure TLS, Poolers, Timeouts and Transactions](tls-and-poolers.md)
- [Set Up Connection Pooling](../configuration/connection-pooling.md)
- [Telemetry](../observability/telemetry.md)
- [Profile Queries and Detect N+1](../observability/query-profiler.md)
