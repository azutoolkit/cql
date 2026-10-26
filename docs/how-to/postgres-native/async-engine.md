# Use AsyncEngine and Its Connection Pool

`CQL::Postgres::AsyncEngine` runs CQL statements over the native driver with a pool of connections shared by your
fibers. It needs only the standard library and `db`.

## Connect

```crystal
require "cql/postgres"

engine = CQL::Postgres::AsyncEngine.connect(
  "postgres://app:secret@db.internal/app?sslmode=verify-full&pool_size=10"
)
```

`connect` opens `pool_min_size` connections up front, so a wrong URL fails at startup. The adapter follows the URL:
`cockroachdb://` selects `CQL::Adapter::CockroachDB`, anything else `CQL::Adapter::Postgres`. Pass `adapter:` to
override it.

## Run Statements

Any CQL statement runs on the engine with `using`:

```crystal
User.query.where(active: true).using(engine).to_a
AppDB.query.from(:users).select(:name).where("age > ?", 18).using(engine).all(as: String)
AppDB.insert.into(:users).values(name: "ada").using(engine).commit
```

Raw SQL without rows goes through `exec`. Without arguments the text may hold several statements:

```crystal
engine.exec("CREATE TABLE IF NOT EXISTS notes (id bigserial PRIMARY KEY, body text)")
```

Values are always bound as parameters. Close the engine when you are done:

```crystal
engine.close
```

## Pool Options

Pool settings are URL query options:

| Option | Meaning | Default |
| --- | --- | --- |
| `pool_size` | Maximum connections | 10 |
| `pool_min_size` | Connections opened by `connect` (between 0 and `pool_size`) | 0 |
| `checkout_timeout` | Seconds to wait for a free connection | 5 |
| `health_check_after` | Ping connections idle longer than this many seconds before reuse | 30 |
| `max_queries` | Retire a connection after this many requests | unlimited |
| `max_idle_lifetime` | Retire a connection idle longer than this many seconds | unlimited |

Other useful URL options: `connect_timeout` (seconds for each connecting step, default 10), `application_name`
(default `cql`), `statement_cache_size` (default 256) and `binary_params`.

Notes:

- `max_queries` and `max_idle_lifetime` are checked when a connection would be lent out. There is no background reaper
  and retired connections are not refilled. Pings and resets count as requests.
- Malformed values (`pool_size=abc`) raise `ArgumentError`.
- These options apply to `AsyncEngine` only. `CQL::Schema` and `DB.open` use crystal-db's own pool, configured with
  `initial_pool_size`, `max_pool_size`, `retry_attempts` and friends.

Inspect the pool at any time:

```crystal
puts engine.pool.stats # => "2 in use, 3 idle, 10 max"
```

## Setup and Reset Hooks

`setup:` runs once on every new connection. `reset:` is a statement run each time a connection returns to the pool;
afterwards the driver clears its statement cache and runs `setup:` again.

```crystal
engine = CQL::Postgres::AsyncEngine.connect(
  ENV["DATABASE_URL"],
  setup: ->(c : CQL::Postgres::Connection) { c.exec_all("SET search_path TO app") },
  reset: "DISCARD ALL"
)
```

A transaction left open by a borrower is rolled back and the connection is reused. If the rollback or the reset
fails, the connection is dropped.

## Borrow One Connection

`with_connection` lends one pooled connection to the block:

```crystal
engine.with_connection do |connection|
  puts connection.session.server_parameters["server_version"]
end
```

A connection serves one request at a time; fibers sharing it queue.

## Transactions

```crystal
engine.transaction do |tx|
  AppDB.insert.into(:users).values(name: "ada").using(tx).commit
end
```

The block commits on return and rolls back when it raises. `raise DB::Rollback.new` rolls back without an error and
makes `transaction` return `nil`. Isolation, savepoints and durability are covered in
[TLS, poolers and timeouts](tls-and-poolers.md#transactions-isolation-and-savepoints). A `tx` is only valid inside
its block; using it afterwards raises `CQL::Postgres::TransactionClosed`.

## Handle Errors

Server errors arrive as typed `CQL::Postgres::ServerError` subclasses:

```crystal
begin
  AppDB.insert.into(:users).values(email: "ada@example.com").using(engine).commit
rescue ex : CQL::Postgres::UniqueViolation
  puts ex.constraint # which constraint
  # ex.detail names the duplicated key
end
```

Other classes include `ForeignKeyViolation`, `NotNullViolation`, `CheckViolation`, `SerializationFailure`,
`DeadlockDetected`, `UndefinedTable`, `UndefinedColumn` and `QueryCanceled`. Pool failures raise `PoolTimeout` or
`PoolClosed`.

The message quotes the server's wording only for SQLSTATE classes known not to carry data. `#server_message` and
`#detail` hold the rest and can contain bound values, so log them with care. Passwords never appear in driver messages.

## Observe Statements

Statements go through `CQL::Execution`, so telemetry and performance tracking see them. The exceptions are `engine.exec` and `engine.pipeline`, which pass `track: false`: telemetry sees them, the [performance monitor](../performance/query-profiler.md) does not.

```crystal
CQL::Telemetry.subscribe("pg") do |event|
  puts "[#{event.operation}] #{event.duration.total_milliseconds}ms #{event.sql}"
end
```

Bound values are not captured unless you turn on `CQL::Telemetry`'s `capture_params`.

## Supported Value Types

`Int*`, `Float*`, `Bool`, `String`, `Bytes`, `Time`, `UUID`, `JSON::Any`, arrays and `nil` are accepted as parameters.
Results decode `int2/4/8`, `float4/8`, `bool`, `text`, `bytea`, `uuid`, `date`, `time`, `timestamp(tz)`, `json(b)` and
`numeric` (as `CQL::Postgres::Types::DecimalText`, exact text). Other types arrive as text. Infinite and out-of-range
dates raise `CQL::Postgres::UnsupportedValue`.

## Troubleshooting

**`PoolTimeout`**: every connection was busy for longer than `checkout_timeout`. Raise `pool_size`, shorten the work
done while holding a connection, or raise `checkout_timeout`.

**Startup fails immediately**: `connect` opens `pool_min_size` connections. Check host, credentials and `sslmode`.

**`TransactionClosed`**: a `tx` escaped its block. Run the work inside the block.

**Errors 42P05 or 26000 behind a pooler**: see [TLS, poolers and timeouts](tls-and-poolers.md#poolers).
