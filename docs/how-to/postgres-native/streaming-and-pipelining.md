# Stream Large Results and Pipeline Statements

`all`, `to_a` and `exec_query` hold a whole result in memory: stream big results a batch at a time, and pipeline many small statements into one network round trip.

## Stream Rows

```crystal
# A CQL::Query, read through a portal 500 rows per fetch; rows is a DB::ResultSet
engine.stream(AppDB.query.from(:users).select(:id, :name).where(active: true), fetch_size: 500) do |rows|
  rows.each { puts "#{rows.read(Int64)} #{rows.read(String)}" }
end

# A model query: pass its CQL::Query with .query
engine.stream(User.query.where(active: true).query) do |rows|
  rows.each { puts rows.read(Int64) } # the model's columns, id first; fetch_size defaults to 1000
end

# SQL text with arguments
engine.stream("SELECT id FROM users WHERE name = $1", ["Ada".as(DB::Any)], fetch_size: 1000) do |rows|
  rows.each { puts rows.read(Int64) }
end
```

{% hint style="warning" %}
`engine.stream(User.query.where(active: true))` does not compile: **`stream`** and **`pipeline`** destructure `to_sql` into SQL and parameters, and `QueryBuilder#to_sql` returns only the SQL string. Pass `.query`.
{% endhint %}

### Rules

```crystal
engine.stream(AppDB.query.from(:users).select(:id), fetch_size: 100) do |rows|
  rows.each do
    break if rows.read(Int64) >= 1000 # stopping early closes the portal; the connection goes back in sync
  end
end
# engine.stream holds its own pooled connection until the block ends. tx.stream uses the transaction's:
# a statement on tx inside the block raises Sync::Error::Deadlock (Crystal 1.20+).
# Read rows inside the block, on the fiber that opened the stream. Kept past its block, a stream
# yields only rows already buffered, then raises CQL::Postgres::StreamClosed; another fiber gets WrongFiber.
# COPY cannot be streamed and fetch_size must be positive (ArgumentError for both).
# A value that cannot be decoded raises after its fetch, with the session kept in sync.
```

### Stream in a Transaction

```crystal
engine.transaction do |tx|
  tx.stream(AppDB.query.from(:posts).select(:id).where(user_id: 1_i64), fetch_size: 200) do |rows|
    rows.each { puts rows.read(Int64) }
  end
end
```

### Timeouts and Cancel

```crystal
engine.stream("SELECT id FROM users", [] of DB::Any, fetch_size: 500, timeout: 30.seconds) do |rows|
  rows.each { rows.read(Int64) }
end
# timeout bounds the whole stream, block time included: the next fetch after it raises
# CQL::Postgres::QueryTimeout, and the session is dropped unless the server confirmed a cancel.
# connection.session.cancel from another fiber ends a stream with CQL::Postgres::QueryCanceled,
# during a fetch or at the next one (rows already buffered are delivered first).
```

### Lower-Level Streams

```crystal
engine.with_connection do |connection|
  connection.session.stream("SELECT id FROM users", fetch_size: 100) do |rows|
    rows.each { |row| row.first } # CQL::Postgres::RowStream: an Iterator of Array(Types::Value)
    rows.rows_read                # => 3
    rows.peak_buffered            # => 3 (most rows held at once, never above fetch_size)
  end
end
# connection.stream(sql, args, fetch_size: 100) is the DB::ResultSet flavour engine.stream uses;
# without arguments pass [] of DB::Any, since connection.stream(sql) does not compile.
```

## Pipeline Statements

```crystal
results = engine.pipeline([
  AppDB.query.from(:users).select(:name),
  AppDB.query.from(:posts).select(:id),
]) # one round trip on one connection (two for statements not prepared yet)

names = results[0].as(CQL::Postgres::PipelineResult).all(as: String)
ids = results[1].as(CQL::Postgres::PipelineResult).all(as: Int64)

# {sql, params} tuples work too
statements = (1..200).map { |n| {"SELECT $1::int + 1", [n.as(DB::Any)]} }
sums = engine.pipeline(statements)
```

Each statement reaches telemetry; the first one's duration covers the round trip. `pipeline` passes `track: false`, so the [performance monitor](../performance/query-profiler.md) does not see them. Large batches go out in chunks that fit the socket buffers; `COPY` cannot be pipelined.

### Handle Failures

```crystal
results = engine.pipeline([{"SELECT nope FROM users", [] of DB::Any}, {"SELECT 1::int4", [] of DB::Any}])
results.each do |result|
  case result
  in CQL::Postgres::PipelineResult then puts result.all(as: Int32).first # => 1
  in CQL::Postgres::ServerError    then puts result.sqlstate             # => 42703
  end
end
# One failing statement leaves the others unaffected.
# PipelineResult: all(as: Class), all(as: {Int32, String}), get(as:), get!(as:), rows_affected
```

## Troubleshooting

**`ArgumentError: pipelining needs the statement cache`**: the URL has `statement_cache_size=0`, which a transaction-mode pooler may need; see [poolers](tls-and-poolers.md#poolers).

**Streaming hangs behind pgcat or pgpool-II**: streaming through a portal hung on both in the project's [measured compatibility](https://github.com/azutoolkit/cql#measured-compatibility) runs.

**A stream is slower than `to_a`**: it costs one round trip per `fetch_size` rows. In the README's [measurement](https://github.com/azutoolkit/cql#measured-compatibility) (200,000 two-column rows, PostgreSQL 16, one run), streaming 1000 rows per fetch held 1000 rows instead of 200,000 and took 125 ms against 82 ms. Raise `fetch_size` to trade memory for speed.

## See Also

- [Use AsyncEngine and Its Connection Pool](async-engine.md)
- [Bulk Load with COPY and Send Binary Parameters](copy-and-binary-params.md)
- [Configure TLS, Poolers, Timeouts and Transactions](tls-and-poolers.md)
- [Optimizing Queries in CQL](../performance/optimize-queries.md)
