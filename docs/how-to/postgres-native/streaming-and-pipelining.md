# Stream Large Results and Pipeline Statements

Ordinary queries (`all`, `to_a`, `exec_query`) read a statement's whole result into memory. Use streaming when the
result is big, and pipelining when you have many small statements and the network round trip dominates.

## Stream Rows

`engine.stream` reads rows through a portal, `fetch_size` at a time, and yields a `DB::ResultSet`:

```crystal
engine.stream(User.query.where(active: true), fetch_size: 500) do |rows|
  rows.each { puts rows.read(String) }
end
```

It also takes SQL text with arguments:

```crystal
engine.stream("SELECT id FROM events WHERE kind = $1", ["click".as(DB::Any)], fetch_size: 1000) do |rows|
  rows.each { puts rows.read(Int64) }
end
```

The default `fetch_size` is 1000.

### Rules

- The connection is busy for the whole block. Do not run other statements on it inside the block; `engine.stream`
  takes its own pooled connection, `tx.stream` uses the transaction's.
- Stopping early is fine. The portal is closed when the block ends, however early, and the connection goes back to the
  pool in sync, inside a transaction too.
- A stream read after its block raises `CQL::Postgres::StreamClosed`.
- A stream must be read by the fiber that opened it, otherwise `CQL::Postgres::WrongFiber` is raised.
- `COPY` cannot be streamed.
- A value that cannot be decoded raises after its fetch, with the session kept in sync.

### Streaming in a Transaction

```crystal
engine.transaction do |tx|
  tx.stream(Order.query.where(status: "open"), fetch_size: 200) do |rows|
    rows.each { process(rows.read(Int64)) }
  end
end
```

### Timeouts and Cancel

`timeout:` bounds the whole stream. Once it passes, the next fetch raises `CQL::Postgres::QueryTimeout` and the session
is dropped unless the server confirmed a cancel.

```crystal
engine.stream(sql, [] of DB::Any, fetch_size: 500, timeout: 30.seconds) { |rows| ... }
```

Call `connection.session.cancel` from another fiber to end a stream. If the server is busy fetching, the fetch raises
`CQL::Postgres::QueryCanceled`; between fetches the next fetch raises it (rows already buffered are still delivered
first).

### Lower-Level Streams

`Session#stream` yields a `CQL::Postgres::RowStream`, an `Iterator` with `peak_buffered` (the most rows ever held at
once, never more than `fetch_size`) and `rows_read`:

```crystal
engine.with_connection do |connection|
  connection.session.stream("SELECT id FROM events") do |rows|
    rows.each { |row| ... }
    puts rows.peak_buffered
  end
end
```

`Connection#stream` is the `DB::ResultSet` flavour used by `engine.stream`.

## Pipeline Statements

`engine.pipeline` sends many statements in one network round trip on one connection. Each statement still reaches
telemetry (not the performance monitor: it passes `track: false`), and failures stay isolated.

```crystal
results = engine.pipeline([
  AppDB.query.from(:users).select(:name),
  AppDB.query.from(:orders).select(:id),
])

names = results[0].as(CQL::Postgres::PipelineResult).all(as: String)
ids   = results[1].as(CQL::Postgres::PipelineResult).all(as: Int64)
```

It also takes `{sql, params}` tuples:

```crystal
statements = (1..200).map { |n| {"SELECT $1::int + 1", [n.to_i32.as(DB::Any)]} }
results = engine.pipeline(statements)
```

### Handle Failures

Each element is either a `PipelineResult` or a `ServerError`. One failing statement does not affect the others:

```crystal
results.each do |result|
  case result
  in CQL::Postgres::PipelineResult then puts result.all(as: Int32).first
  in CQL::Postgres::ServerError    then puts "failed: #{result.sqlstate}"
  end
end
```

`PipelineResult` offers `all(as:)` (a class or a tuple of types such as `{Int32, String}`), `get`, `get!` and
`rows_affected`.

## Troubleshooting

**The pipeline raises behind PgBouncer**: pipelining needs the statement cache. With `statement_cache_size=0` it does
not work. See [poolers](tls-and-poolers.md#poolers).

**Streaming hangs behind pgcat or pgpool-II**: in the verified setups, streaming through a portal hung on both. See
the compatibility notes in [TLS, poolers and timeouts](tls-and-poolers.md#poolers).

**A stream seems slower than `to_a`**: it makes one round trip per `fetch_size` rows. Raise `fetch_size` to trade memory
for speed. In the README's measurement (200,000 rows, two columns, PostgreSQL 16) streaming held 1000 rows at once
instead of all 200,000, and took 125 ms against 82 ms. One machine, one run.

**`StreamClosed`**: you kept a `rows` object past its block. Read everything you need inside the block.
