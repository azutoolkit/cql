[![Crystal CI](https://github.com/azutoolkit/cql/actions/workflows/crystal.yml/badge.svg)](https://github.com/azutoolkit/cql/actions/workflows/crystal.yml)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/a85e29e6b78849c28fb813397cc3eb1a)](https://app.codacy.com/gh/azutoolkit/cql/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)

# CQL (Crystal Query Language)

<img width="1038" alt="cql-banner" src="https://github.com/user-attachments/assets/ed4e733a-3d37-4d03-a4d8-d15bfd7e6f25">

A high-performance, type-safe ORM for Crystal applications that combines compile-time safety with runtime performance. Unlike traditional ORMs that catch errors at runtime, CQL validates your queries, relationships, and data access patterns before your code executes.

> _"We migrated our Rails API to Crystal + CQL and saw response times drop from 200ms to 45ms while handling 3x more concurrent users."_ - Production User

**[Complete Documentation →](https://azutopia.gitbook.io/cql)**

## Why Choose CQL

### Performance

- `Model.find` renders its statement once per model and rebinds only the id: about a million lookups per second on in-memory SQLite, 480 bytes each
- SQL is written in one pass into one buffer; values are always bound, never interpolated
- `last`, `exists?`, `count` and `find_each` fetch only the rows they need; `preload` loads associations in one query per chunk
- Bulk writes (`insert_all`, `upsert_all`, `insert_<assoc>_all`), `INSERT ... RETURNING` on PostgreSQL, and opt-in dirty tracking that updates only changed columns
- Per-query diagnostics (SQL logging, performance monitor, request cache) are off unless you enable them or run in development, so production pays nothing for them

### Type Safety

- Catch errors at compile time - invalid queries fail before deployment
- Compile-time relationship integrity checks for `belongs_to` and `has_many`
- Foreign-key/primary-key mismatches fail with clear CQL errors, including forward-declared target models
- Optional strict schema/model mapping validation for production boot checks
- Full IDE autocompletion support for queries and relationships
- Safe refactoring - rename columns/tables with confidence
- No runtime surprises - association errors caught early

### Developer Experience

- Familiar ActiveRecord-style API - easy migration from Rails/Laravel
- Rich query DSL with readable, type-safe syntax
- Automatic schema synchronization - database changes tracked and versioned
- Built-in performance monitoring with N+1 query detection (opt-in)

## Core Features

- **Type-Safe ORM**: Leverage Crystal's static type system for compile-time safety
- **High Performance**: Cached find statements, single-pass SQL rendering, and diagnostics that are off until you enable them (see [How CQL Keeps Queries Fast](docs/explanation/performance-design.md))
- **Active Record Pattern**: Intuitive Active Record API with full CRUD operations
- **Smart Relationships**: Support for `belongs_to`, `has_one`, `has_many`, and `many_to_many` with compile-time FK/PK validation and `preload` eager loading for has_many, belongs_to and has_one
- **Schema Mapping Guardrails**: Opt-in validation checks model getter types against schema column types at application boot
- **Comprehensive Validations**: Built-in validation system with custom validator support
- **Lifecycle Callbacks**: Before/after hooks for validation, save, create, update, and destroy
- **Bulk Writes**: `insert_all`, `upsert_all` and has_many's `insert_<assoc>_all` send multi-row statements, chunked under each database's bind-parameter limit
- **Dirty Tracking**: Opt-in `CQL::ActiveRecord::DirtyTracking` reports `changes` and updates only changed columns
- **Intelligent Migrations**: Schema evolution tools with automatic rollback support
- **Schema Dump**: Reverse-engineer existing databases into CQL schema definitions
- **Typed Query DSL**: `User.query.where { (age >= 18) & (status == "active") }` with compile-time column and type checks, association joins, CTEs, window functions, set operations, upsert, JSON/geo predicates and safe bound raw fragments (see the [before/after guide](docs/explanation/dsl-before-after.md) and `playground/cql_demo.cr`)
- **Transaction Support**: Full ACID transaction support with nested transactions (savepoints)
- **Optimistic Locking**: Built-in support for optimistic concurrency control
- **Query Scopes**: Reusable query scopes for common filtering patterns
- **Advanced Caching**: Multi-layer caching with Redis and memory cache support
- **Performance Monitoring**: Opt-in query profiling, N+1 detection, and optimization suggestions
- **Multi-Database**: Support for PostgreSQL, MySQL, SQLite and CockroachDB with dialect-specific optimizations
- **Flexible Primary Keys**: Support for Int32, Int64, UUID, and ULID primary keys

## Performance

`benchmarks/sqlite_bench.cr` on in-memory SQLite, one fiber, release build:

| Operation | Throughput | Time | Allocated |
| --- | --- | --- | --- |
| `User.find(id)` | 1.01M ops/s | 0.99 µs | 480 B |
| `User.last` | 350k ops/s | 2.9 µs | 3.3 kB |
| `where(...).exists?` | 404k ops/s | 2.5 µs | 3.1 kB |
| `create!` | 333k ops/s | 3.0 µs | 2.4 kB |
| `update!` | 336k ops/s | 3.0 µs | 2.0 kB |
| Simple `to_sql` | 854k ops/s | 1.2 µs | 1.9 kB |
| JOIN with ORDER BY and LIMIT, `to_sql` | 491k ops/s | 2.0 µs | 3.7 kB |
| 100 parents with `preload(:children)` | 5.0k ops/s | 199 µs | 165 kB |

These numbers measure CQL's own overhead; against a database server, the round trip usually dominates. Your hardware will give different numbers, so measure your own workload with [Benchmark CQL](docs/how-to/performance/benchmark.md).

## Database Support

| Database       | Support Level | Special Features                  |
| -------------- | ------------- | --------------------------------- |
| **PostgreSQL** | Full          | JSONB, Arrays, Advanced Types     |
| **MySQL**      | Full          | Complete MySQL support            |
| **SQLite**     | Full          | Perfect for development & testing |
| **CockroachDB**| Full          | PostgreSQL dialect, native driver |

## Native PostgreSQL Driver

This is the default driver for `postgres://` and `postgresql://` URLs: `require "cql"` loads it and registers it with
crystal-db, so `CQL::Schema` and `DB.open` use it without the `pg` shard. If your app requires `pg` before `cql` (it
keeps the names) or after it (it replaces them), the `pg` shard's driver serves those URLs instead, so remove
`require "pg"` to switch, or compile with `-Dcql_no_postgres_driver` to keep this driver out of crystal-db's registry
(that flag also wins over `-Dcql_postgres_driver_cockroachdb`; call the `register` methods yourself if you want them).
Differences from the `pg` shard to know about when switching: `sslmode` takes `disable`, `prefer`, `require` or
`verify-full` only (`verify-ca`, `allow` and the libpq options `sslcert`, `sslkey` and similar are rejected, not
ignored; `auth_methods`, written for the `pg` shard, is accepted and ignored); `PGHOST`, `PGPORT`, `PGUSER` and `PGPASSWORD` are read from the environment when the URL omits
them; arrays decode to their text form and `numeric` to `CQL::Postgres::Types::DecimalText`, so `read(Float64)` and
`read(Array(Int32))` raise `TypeCastError` (register a codec with `Types.register`); connection failures reach
crystal-db's pool as `DB::ConnectionRefused`, so `retry_attempts` and `retry_delay` apply.
`cockroachdb://` is opt-in, because only CockroachDB 24.3 was checked: call `CQL::Postgres::Driver.register_cockroachdb`
(or compile with `-Dcql_postgres_driver_cockroachdb`) to let `DB.open("cockroachdb://...")` use it. A Schema with
`CQL::Adapter::CockroachDB` rewrites its URL to `postgres://`, so it follows the `postgres` rule above, and
`AsyncEngine.connect("cockroachdb://...")` needs no registration and picks the CockroachDB adapter. crystal-db's own pool serves
`Schema` and `DB.open`; the engine's `pool_size`/`max_queries` options only apply to `AsyncEngine`. Write a literal `+`
in a user name or password as `%2B` (crystal-db reads `+` as a space). See "CockroachDB", "PostgreSQL versions" and "PgBouncer" below for what was verified against real servers.

`CQL::Postgres::AsyncEngine` speaks the PostgreSQL wire protocol itself (3.2, falling back to 3.0), on Crystal fibers and the standard
library's event loop, with its own connection pool. It is also a `CQL::Executor` (`query.using(engine)`); SQLite/MySQL users are unaffected. The engine itself needs only the standard library and `db`. A `CQL::Schema`
for PostgreSQL opens a crystal-db connection when it is created (through this driver, so the `pg` shard is no longer
needed; `?initial_pool_size=0` keeps the connection from being opened). To run a schema on the engine's own pool instead, pass `source: CQL::Postgres::EngineSource.connect(url)` to `CQL::Schema.new` (see `docs/how-to/postgres-native/schema-on-engine.md`).

```crystal
require "cql/postgres"

engine = CQL::Postgres::AsyncEngine.connect("postgres://app:secret@db.internal/app?sslmode=verify-full&pool_size=10")

# Any CQL statement runs on it with `using`; rows map exactly as they do on the default driver.
User.query.where(active: true).using(engine).to_a
AppDB.query.from(:users).select(:name).where("age > ?", 18).using(engine).all(as: String)

# Transactions pin statements to one connection and roll back on exceptions (or `raise DB::Rollback`).
engine.transaction do |tx|
  AppDB.insert.into(:users).values(name: "ada").using(tx).commit
end

# Isolation, access mode, savepoints and commit durability are per transaction.
engine.transaction(isolation: :serializable, read_only: true) do |tx|
  tx.savepoint { |inner| AppDB.insert.into(:audit).values(note: "tried").using(inner).commit } # undone alone if the block raises
end

# A large result without holding it all: rows arrive 500 at a time through a portal.
engine.stream(User.query.where(active: true), fetch_size: 500) do |rows|
  rows.each { puts rows.read(String) } # stopping early is fine: the connection goes back to the pool in sync
end

# Many statements, one network round trip (each still reaches telemetry); failures stay isolated.
results = engine.pipeline([AppDB.query.from(:users).select(:name), AppDB.query.from(:orders).select(:id)])
results[0].as(CQL::Postgres::PipelineResult).all(as: String)
```

What it does:

- **Protocol version**: it asks for 3.2 (PostgreSQL 18; longer cancel keys) and follows the server's
  `NegotiateProtocolVersion`, or retries on 3.0 when an older server or proxy rejects the startup, answers with something that is not a protocol message, or closes the connection without answering (a stall is not retried: `connect_timeout` ends it). Pin it with
  `min_protocol_version` / `max_protocol_version` (`3.0` or `3.2`) in the URL. Covered by byte-fixture and fake-server
  specs, and by live specs against real PostgreSQL 11 to 18 servers, PgBouncer 1.22 and 1.24 and CockroachDB (see below). A server that rejects 3.2 costs every new connection one extra attempt, so set `max_protocol_version=3.0` for it. OAuth authentication (PostgreSQL 18) is not
  supported.
- **Protocol**: startup, trust/cleartext/MD5/SCRAM-SHA-256 authentication, TLS through SSLRequest
  (`sslmode=disable|prefer|require|verify-full`), Unix sockets (`?host=/var/run/postgresql`), simple and extended
  queries with per-connection prepared-statement caching, binary results for common types, `COPY` in and out,
  `LISTEN`/`NOTIFY` and notice callbacks, cancel requests and per-statement timeouts (`Session#query(..., timeout:)`, reached through `connection.session`).
  A cancel request carries the session's secret key and is sent over a new, unencrypted connection even under
  `sslmode=require`, as libpq does before version 17. Dropping a connection closes the socket itself, never a TLS close_notify, which could block on a dead path. TLS that is required but unavailable (declined, a failed handshake, a bad certificate) raises `CQL::Postgres::TLSRefused`, not an `IO::Error`, so crystal-db's pool does not retry it. A timed-out request whose cancel does not help (a dead path, a
  server that ignores it) has its socket closed after `cancel_grace` (5 seconds by default), and `Session#ping` closes
  a connection that does not answer within its timeout; the health checks of one checkout share a `checkout_timeout`
  budget, so idle connections on a silently dropped path delay a checkout by about one timeout, not one each; a single ping waits at most 5 seconds
  (waiting for a free slot and opening a connection take their own time on top).
- **Concurrency**: one request in flight per connection, enforced with a lock, so a connection shared between fibers is
  safe (they queue). `AsyncEngine` borrows connections from a pool (`pool_size`, `checkout_timeout`,
  `health_check_after` URL options), pings connections idle longer than `health_check_after` (30s by default) before reuse and discards ones left mid-transaction.
- **Pool lifecycle**: `pool_min_size` connections are opened up front (`AsyncEngine.connect` fails at startup on a wrong
  URL), a connection is retired after `max_queries` requests or after `max_idle_lifetime` seconds idle (both checked when
  it would be lent out; there is no background reaper, and retired connections are not refilled), `setup:` runs once on
  every new connection (`AsyncEngine.connect(url, setup: ->(c : CQL::Postgres::Connection) { c.exec_all("SET search_path TO app") })`)
  and `reset:` runs on every return (the driver's statement cache is cleared and `setup:` runs again afterwards).
  A transaction left open by a borrower is rolled back and the connection reused; if that or the reset fails, it is
  dropped. Every request counts towards `max_queries`, pings and resets included.
- **Errors**: `ErrorResponse` becomes a typed `CQL::Postgres::ServerError` (`UniqueViolation`, `ForeignKeyViolation`,
  `NotNullViolation`, `SerializationFailure`, `DeadlockDetected`, `UndefinedTable`, ...). The message carries the
  server's wording only for SQLSTATE classes known not to quote data; `#server_message` and `#detail` hold the rest and
  can contain bound values. Bound values and passwords never appear in driver messages, and telemetry carries no bound values unless you turn on `CQL::Telemetry`'s `capture_params`.
- **Values** are always bound as parameters. `Int*`, `Float*`, `Bool`, `String`, `Bytes`, `Time`, `UUID`, `JSON::Any`,
  arrays and `nil` are accepted; results decode `int2/4/8`, `float4/8`, `bool`, `text`, `bytea`, `uuid`, `date`,
  `time`, `timestamp(tz)`, `json(b)` and `numeric` (as `CQL::Postgres::Types::DecimalText`, exact text, to avoid
  depending on GMP). Other types (arrays, intervals, ranges, ...) arrive as their text form; register a codec with
  `CQL::Postgres::Types.register` to decode more.

Things to know:

- **CockroachDB**: verified against a real CockroachDB v24.3.5 single node, insecure and also secure (TLS with
  `sslmode=verify-full` and a password): `spec/postgres/live_spec.cr` and `streaming_spec.cr` pass there, except the LISTEN/NOTIFY example, which stays pending
  because CockroachDB has no LISTEN. CockroachDB answers a protocol 3.2 startup with HTTP/2 bytes instead of an error;
  `cockroachdb://` URLs given to `DB.open` or `AsyncEngine.connect` therefore start at 3.0 (a `Schema` on
  `CQL::Adapter::CockroachDB` uses a `postgres://` URL, so it starts at 3.2 and pays one failed attempt per new
  connection; put `max_protocol_version=3.0` in its URL to avoid that), and the driver also falls back to 3.0 whenever the first reply is not a
  protocol message. Savepoints, `SET LOCAL synchronous_commit`, pipelining, COPY, cancel and `40001` mapping to
  `SerializationFailure` work as on PostgreSQL. Differences: `SELECT 1` is an `int8`, `pg_sleep` returns a bool, the
  default isolation level is serializable, `deferrable: true` is refused, and COPY mistakes come back as a generic
  `ServerError`.
- `synchronous_commit: false` (or `?synchronous_commit=off` for a whole connection) lets `COMMIT` return before the WAL is
  flushed to disk. It cannot corrupt the database, but commits from the last few hundred milliseconds (up to about three
  times `wal_writer_delay`) can be lost if the server crashes, and a replica or client may have seen them already.
  Use it for data you can recompute; keep the default for money. A transaction-level `SET LOCAL` only affects that one
  transaction.

- Ordinary queries (`all`, `to_a`, `exec_query`) read a statement's whole result into memory. For big
  results use `engine.stream(query_or_sql, fetch_size:)` (a `DB::ResultSet`) or `Session#stream` (an `Iterator` with
  `peak_buffered` and `rows_read`): Execute with a row limit, at most `fetch_size` rows buffered, and the portal closed
  when the block ends however early (`Close` before `Sync`, so inside a transaction too), and a stream read after its
  block raises `StreamClosed`. The connection is busy for the whole block (do not use it inside); `engine.stream` takes its
  own pooled connection, `tx.stream` uses the transaction's. `timeout:` bounds the whole stream: once it passes, the
  next fetch raises `QueryTimeout` and the session is dropped unless the server confirmed a cancel.
  `connection.session.cancel` from another fiber raises `QueryCanceled` if the server is busy fetching (otherwise there
  is nothing to cancel). COPY cannot be streamed, and a value that cannot be decoded raises after its fetch, with the
  session kept in sync. Measured with `benchmarks/pg_wire_bench.cr` against
  PostgreSQL 16 (200000 rows of two columns): 1000 rows held at once and +1.7 MB peak memory streamed, 200000 rows and
  +45 MB read whole; streaming took 125 ms against 82 ms because of its 200 round trips.
- Infinite and out-of-range dates and timestamps raise `CQL::Postgres::UnsupportedValue`.
- **Binary parameters** (`binary_params=true` in the URL, off by default). Parameters are normally sent as text and
  the server infers their types. With the option on, a parameter that is a `Bool`, `Int`, `Float32`/`Float64`, `UUID`,
  `Time`, `DecimalText`, `JSON::Any` or an `Array` of those waits until the statement has been described, and is then
  sent in binary if the type the server reported has a form for it: int2/int4/int8 (the value must fit, otherwise
  the text goes and the server reports the range error itself), float4 (from a `Float32`) and float8 (a `Float64` is
  never narrowed to float4), bool, uuid, timestamp and timestamptz (cut to microseconds like the text form) and date,
  numeric (from `DecimalText` or an integer; NaN, infinities and exponent forms stay text), jsonb, and one- or
  multi-dimensional arrays of those and of text/varchar/bpchar, with NULL elements (ragged arrays stay text).
  Strings, `json`, `bytea` and anything else are unchanged. Values are still bound parameters; the choice is made from
  the server's own `ParameterDescription`. `Session#binary_params_sent` counts what went out in binary. Each type is
  checked against PostgreSQL 16, 18 and 19rc1 (a release candidate) and CockroachDB 24.3 by sending the same value as text and as binary
  (`spec/postgres/binary_live_spec.cr`) and requiring the same answer. CockroachDB reads float4 (0.1 returns as
  0.10000000149011612) and numeric (`100000000` returns as `1E+8`, `-0.00` as `0`) differently, so those stay text
  there (detected from its `crdb_version` parameter), and it has no multi-dimensional arrays at all. **It is off by
  default.** `benchmarks/pg_binary_params_bench.cr` on PostgreSQL 16 over loopback
  (medians of 7 rounds of 5000 statements, encoding included in the timing, statements per second, text then binary):
  six scalars 15751 / 18358, one int8 19958 / 19509, one timestamptz 18431 / 18717, one numeric 19176 / 19385, a
  7-column insert 12902 / 13654, int8[1000] 1944 / 3009, text[200] 7224 / 8339, numeric[200] 5113 / 5877 and
  timestamptz[500] 904 / 4929 (5.4 times faster). A single value is within the few percent that separate two runs
  (an earlier numeric encoder was slower than text until it was rewritten as a byte pass); several parameters and
  arrays gain 6% to 440%. One machine and one run.
  The default stays text: it is the established behaviour and binary is not shown to help a lone value. A deferred parameter keeps a
  reference to the array or JSON value it was made from, so mutate it
  only after the statement has returned. Because the choice waits for the server's types, an array holding a value
  that cannot be bound raises when the statement is bound (after the describe round trip), not when the parameter is created.
  Also run live by pointing `DATABASE_URL` at them for `spec/postgres/binary_live_spec.cr`: through PgBouncer 1.26.1 in session mode and in transaction mode
  with `max_prepared_statements` (0 failures; in transaction mode without it, use `statement_cache_size=0`, and the
  pipeline example then raises because pipelining needs the cache), and on a secure CockroachDB 24.3.5 node with
  `sslmode=require` and `verify-full` plus a password (0 failures).
- **Binary COPY**: `session.copy_in_binary(sql, types) { |rows| rows.row(1_i64, "a", nil) }` and
  `session.copy_out_binary(sql, types) { |row| ... }` (also on `Connection`) take the `COPY ... (FORMAT binary)`
  statement and the column type OIDs (`CQL::Postgres::Types::OID`). The signature, header and trailer are handled,
  rows may be split across chunks, and a damaged stream or a trailer that never came raises `ProtocolError` (without
  quoting data). Each value must have a binary form for its column type (the list above plus text, json and
  bytea); there is no conversion between kinds, and a mismatch raises `ArgumentError` naming the column and the Crystal
  class only. A statement the server runs as text (no `(FORMAT binary)`) raises `ArgumentError` too, before any data is sent (`copy_in_binary`) or after the output has been read (`copy_out_binary`). Types without a decoder (arrays among them) come back as raw `Bytes`. Timeouts, `cancel` and an exception
  in the block (the way to stop early; there is no `break`) behave as in the text `copy_in` / `copy_out` (the same
  code path). A damaged row raises `ProtocolError` while it is read, which drops the connection (a stream that ends without its trailer raises the same error afterwards, with the session left in sync). CockroachDB's float4 and numeric
  differences above apply to binary `COPY FROM` too (not tested: it cannot copy the rows back out in binary). Checked live on PostgreSQL 16, 18
  and 19rc1: 10002 rows of 11 columns round-trip, early stop, timeout, cancel and abort leave the session usable.
  CockroachDB 24.3 accepts binary `COPY FROM` but answers binary `COPY TO` with `0A000 unimplemented`.
- Behind PgBouncer in transaction mode use `statement_cache_size=0` (the unnamed statement is used; pipelining needs the
  cache). See "PgBouncer" below.
- **PostgreSQL versions** (`script/pg-matrix start` then `run` starts one server per major and runs
  `spec/postgres/matrix_spec.cr` plus `live_spec.cr` against each; all measured on Linux x86_64 with the binaries named):

  | PostgreSQL | protocol used | cancel key | SCRAM / MD5 / cleartext | `live_spec.cr` (23 examples) |
  |---|---|---|---|---|
  | 11.22, 12.22, 13.23 (end of life) | 3.0 (server answers `NegotiateProtocolVersion`) | 4 bytes | pass | pass |
  | 14.24, 15.19, 16.15, 17.11 | 3.0 (same) | 4 bytes | pass | pass |
  | 18.6 | 3.2 | 32 bytes | pass | pass |

  PostgreSQL 19rc1 (a release candidate built from source) also passed the matrix (7 of 7), the live spec (23 examples, none pending) and the streaming spec (35 examples). Untested: a final PostgreSQL 19 release, PostgreSQL on non-Linux or non-x86_64 hosts, and
  distribution-patched builds. Each version also passes: re-preparing after a schema change, pipelining and failure isolation, COPY in and out,
  cancel after a statement timeout, and `synchronous_commit: false` per transaction (`SHOW` reads `off` inside and `on`
  after). Which majors upstream still supports changes yearly; check postgresql.org/support/versioning.
- **PgBouncer** 1.22 (`script/pgbouncer-matrix`, spec `spec/postgres/pgbouncer_spec.cr`, real PgBouncer in front of
  PostgreSQL 16): it answers a 3.2 startup with `FATAL 08P01 bad packet header` and closes, and the driver reconnects with 3.0. In transaction mode
  with `max_prepared_statements` above 0, cached statements, pipelining, cancel (with the 4-byte key the pooler hands
  out), `SET LOCAL` and rollback of a leaked transaction all work. In transaction mode without it, named statements
  collide between clients (SQLSTATE `42P05`, and `26000` when a statement is missing on the next server connection):
  use `statement_cache_size=0` there. Session mode behaves like a direct connection. Streaming works in transaction mode with `max_prepared_statements`, and a
  stream's portal pins the pooler's server connection until the block ends (another client of a one-connection pool
  waits for it; checked with `default_pool_size = 1`). `statement_cache_size=0` describes the unnamed statement without a
  Sync, so Bind stays in the same request and a transaction-mode pooler keeps both on one server connection; before that
  change, 8 clients over 3 PgBouncer server connections failed about half the runs (`bind message supplies N
  parameters, but prepared statement "" requires M`, or worse, another client's statement), after it 25 of 25 runs passed. Everything above was also run
  against PgBouncer 1.24.1 and 1.26.1 built from source (10 of 10 examples each; 1.26.1 also negotiates 3.2 down to 3.0).
  `script/pooler_probes.cr` runs nine probes (connect, cached statements, interleaved clients, `statement_cache_size=0`,
  pipelining, `SET LOCAL`, timeout cancel, streaming, savepoints) against any pooler; set `POOLER_NAME`, `POOLER_PORT`,
  `POOLER_USER`, `POOLER_PASSWORD` and optionally `POOLER_QUERY` (extra URL options). Results on one machine, PostgreSQL 16 behind:
  - PgBouncer 1.26.1 with `client_tls_sslmode = require` and its own CA, in front of PostgreSQL 16 and 18: all nine probes pass with
    `sslmode=require` and with `sslmode=verify-full` plus `sslrootcert`, and the timeout cancel works (the CancelRequest travels unencrypted
    on its own connection, as the protocol says). With `sslmode=disable` the pooler answers `FATAL SSL required`, and a bad `sslrootcert` raises `TLSRefused`.
  - Odyssey 1.5.2 (transaction mode): all nine pass. It resets the connection on a 3.2 startup, so the driver falls back to 3.0 (one extra attempt per new connection; set `max_protocol_version=3.0`).
  - pgcat 1.2.0 (transaction mode): it drops a 3.2 startup (the driver falls back to 3.0) and does not accept the Flush message (`Unexpected code: H`), so
    cached statements, pipelining and timeout cancel work, but `statement_cache_size=0`, `SET LOCAL`, streaming and savepoints hang until the client gives up (4 of 9 probes failed). Not usable for those features.
  - pgpool-II 4.3.7 (default settings, no load balancing): needs `max_protocol_version=3.0` (it forwards the 3.2 startup to PostgreSQL and fails the login with `XX000`); then eight of nine probes pass and streaming through a portal hangs.
  Not tested: RDS Proxy, Supavisor, other pgpool-II settings.
- `sslrootcert` adds a CA to the system trust store (Crystal's TLS context cannot drop the system roots); `prefer` and
  `require` encrypt without verifying the server, like libpq.
- `playground/postgres_async_demo.cr` is a runnable tour, and `benchmarks/pg_wire_bench.cr` compares the engine with
  the `pg` shard on your server:
  `DATABASE_URL=postgres://... crystal run --release benchmarks/pg_wire_bench.cr`. Numbers depend on your hardware and
  network, so none are quoted here.

Verified on one Linux machine; CI has not run this yet. The live specs in `spec/postgres/live_spec.cr` (types, errors,
transactions, pipelining, COPY, cancellation, pool, `NOTIFY`) run when `DATABASE_URL` points at a server and are pending
otherwise; the PostgreSQL, PgBouncer and CockroachDB results above come from running them against real servers.
TLS modes and Unix sockets were tried by hand against PostgreSQL 16 earlier and otherwise have byte-level fixture and
fake-server specs only; `script/tls-probes` now checks TLS refusal against real servers (PostgreSQL 16 without TLS and with TLS, CockroachDB secure): the error is `TLSRefused` and the pool makes one attempt, where a plain hang-up is retried. `spec/postgres/blackhole_spec.cr` (`CQL_TLS_PG_PORT` set to a TLS server) drops a TLS connection on a path that stops answering: 50 timed-out requests, 50 pings and 10 writes finished without hanging (slowest request ~0.5 s, ping ~0.3 s) and the descriptor count stayed at 12. CockroachDB was tested insecure and with TLS plus a password.

## Safety Guardrails

CQL validates relationship declarations during compilation. If a relation points at an incompatible key type, compilation fails with a CQL-specific error instead of a deep Crystal macro stack:

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
end

class Post
  include CQL::ActiveRecord::Model(Int32)

  property user_id : Int32?

  # Compile-time error:
  # CQL belongs_to error in Post: foreign key `:user_id` type Int32
  # does not match User.id! primary key type Int64.
  belongs_to :user, User, :user_id
end
```

The check also works when the associated model is defined later in the program, as long as it is required before compilation finishes.

For stricter deployment checks, enable schema mapping validation:

```bash
CQL_VALIDATE_SCHEMA_MAPPINGS=1 crystal run src/app.cr
```

When enabled, CQL compares model getter types with the table metadata from `db_context` and raises a clear `CQL schema mapping error` for mismatches. This mode is opt-in so existing applications can intentionally omit database columns from models or use nilable transient fields before persistence.

## Installation

Add CQL and your database driver to your `shard.yml`:

```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: "~> 0.0.589"

  # Choose your database driver:
  pg: # Optional: CQL ships its own PostgreSQL driver
    github: will/crystal-pg
  mysql: # For MySQL
    github: crystal-lang/crystal-mysql
  sqlite3: # For SQLite
    github: crystal-lang/crystal-sqlite3
```

Then install dependencies:

```bash
shards install
```

## Quick Start

### 1. Define Your Schema

```crystal
require "cql"
require "sqlite3"  # or "mysql"; PostgreSQL needs no extra require

# Define your database schema with compile-time validation
BlogDB = CQL::Schema.define(
  :blog_database,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://db/blog.db"
) do
  table :users do
    primary :id, Int64
    text :username
    text :email
    text :first_name, null: true
    text :last_name, null: true
    boolean :active, default: true
    timestamps
  end

  table :posts do
    primary :id, Int64
    text :title
    text :content
    boolean :published, default: false
    bigint :user_id
    timestamps

    # Type-safe foreign key relationships
    foreign_key [:user_id], references: :users, references_columns: [:id]
  end
end

# Create tables (with automatic validation)
BlogDB.users.create!
BlogDB.posts.create!
```

### 2. Create Models

```crystal
class User
  include CQL::ActiveRecord::Model(Int64) # provides `id : Int64?`
  db_context BlogDB, :users

  property username : String
  property email : String
  property first_name : String?
  property last_name : String?
  property active : Bool = true
  property created_at : Time?
  property updated_at : Time?

  # Compile-time validated relationships
  has_many :posts, Post, :user_id

  # Built-in validations with clear error messages
  validate :username, presence: true, size: 2..50
  validate :email, required: true, match: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  def initialize(@username : String, @email : String,
                 @first_name : String? = nil, @last_name : String? = nil)
  end

  def full_name
    if first_name && last_name
      "#{first_name} #{last_name}"
    else
      username
    end
  end
end

class Post
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :posts

  property title : String
  property content : String
  property published : Bool = false
  property user_id : Int64
  property created_at : Time?
  property updated_at : Time?

  # Type-safe relationships prevent association errors
  belongs_to :user, User, :user_id

  # Comprehensive validations
  validate :title, presence: true, size: 1..100
  validate :content, presence: true

  # `user_id` has a default so `user.posts.build(title: ..., content: ...)` can build a Post
  def initialize(@title : String, @content : String, @user_id : Int64 = 0_i64)
  end
end
```

Models are classes (not structs) so `save` can assign the generated `id` to your instance.

### 3. Work with Your Data

```crystal
# Validate, then save (save raises ValidationError for an invalid record)
author = User.new("alice_j", "alice@example.com", "Alice", "Johnson")
if author.valid?
  author.save
  puts "User created with ID: #{author.id}"
else
  puts "Validation errors: #{author.errors.map(&.message)}"
end

# Type-safe queries
alice = User.find_by(username: "alice_j")
active_users = User.where(active: true).all

# Build associated records through the association (user_id is set for you)
post = author.posts.build(title: "My First Post", content: "Hello, World!")
post.save!

# Safe transactions with automatic rollback
User.transaction do |tx|
  bob = User.create!(username: "bob", email: "bob@example.com")
  Post.create!(title: "Bob's Post", content: "Content here", user_id: bob.id!)

  # If anything raises, everything rolls back automatically
end

# Typed queries with joins on a declared association (inside the block, `user` is
# the association, so do not keep a local variable named `user` in scope)
published_posts = Post.query
  .joins(:user) { user.active == true }
  .where(published: true)
  .order_by(created_at: :desc) # typed, so it is not ambiguous between posts and users
  .limit(10)
  .all

# Bound raw fragments and typed blocks
recent_authors = User.query
  .where("created_at > ?", 1.week.ago)
  .where { active == true }
  .count

puts "Found #{recent_authors} active authors this week"
```

## Advanced Features

### Type-Safe Schema Definition

```crystal
# Schema with advanced features
BlogDB = CQL::Schema.define(:blog, adapter: CQL::Adapter::Postgres, uri: ENV["DATABASE_URL"]) do
  table :products do
    primary :id, String, auto_increment: false # UUID primary keys (stored as text)
    text :name
    double :price
    json :metadata, null: true           # JSON columns
    timestamps

    # Constraints and indexes
    unique_constraint [:name]
    index [:price, :created_at]          # created with the table as idx_products_price_created_at
  end
end
```

### Active Record Pattern

```crystal
class Product
  include CQL::ActiveRecord::Model(UUID)
  db_context BlogDB, :products

  property name : String
  property price : Float64
  property created_at : Time?
  property updated_at : Time?

  # Custom validations with clear error messages
  validate :name, presence: true, size: 2..100
  validate :price, gt: 0.0, lt: 1_000_000.0

  def initialize(@name : String, @price : Float64)
  end
end

# CRUD operations with validation
product = Product.create!(name: "Laptop", price: 999.99)
product = Product.find!(product.id!)

# Efficient querying with type safety
affordable_products = Product.where("price < ?", 1000.0)
                             .order(:name)
                             .limit(50)
                             .all

# Safe updates with validation
product.price = 899.99
product.save!  # Validates before saving

# Safe deletion
product.delete!

# Bulk writes: multi-row INSERTs, no validations or callbacks
Product.insert_all([{name: "Mouse", price: 25.0}, {name: "Desk", price: 300.0}])
Product.upsert_all([{name: "Mouse", price: 20.0}], on_conflict: :name)
```

Include `CQL::ActiveRecord::DirtyTracking` after `Model` and `save` sends only the columns that changed, or nothing when none did:

```crystal
user = User.find!(1)
user.name = "Ada"
user.changes # => {:name => {"Grace", "Ada"}}
user.save    # UPDATE users SET name = ?, updated_at = ? WHERE users.id = ?
```

### Validations

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)

  property name : String
  property email : String
  property age : Int32
  property password : String?
  property password_confirmation : String?

  def initialize(@name : String, @email : String, @age : Int32 = 1)
  end

  # Built-in validations with clear error messages
  validate :name, presence: true, size: 2..50
  validate :email, required: true, match: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  validate :age, gt: 0, lt: 120
  validate :password_confirmation, confirmation: :password

  # Custom business logic validators
  use CustomPasswordValidator
  use BusinessRuleValidator
end

# Comprehensive error handling (save/save! raise ValidationError on an invalid record)
user = User.new("", "invalid-email")
unless user.valid?
  user.errors.each do |error|
    puts "🚫 #{error.field}: #{error.message}"
  end
end
```

### Smart Relationships

```crystal
class User
  # Type-safe relationship definitions
  has_one :profile, UserProfile, foreign_key: :user_id
  has_many :posts, Post, foreign_key: :user_id
  has_many :comments, Comment, foreign_key: :user_id
end

class Post
  belongs_to :user, User, :user_id
  has_many :comments, Comment, foreign_key: :post_id
  many_to_many :tags, Tag, join_through: PostTag # PostTag is the join table's model
end

# Efficient association loading
user = User.find!(1_i64)
user.posts.build(title: "New Post", content: "Content").save!
user.posts.size                         # Number of posts
user.posts.empty?                       # Existence check

# Insert many children in multi-row statements (no validations or callbacks)
user.insert_posts_all([{title: "One", content: "..."}, {title: "Two", content: "..."}]) # => 2

# Eager loading with preload for has_many, belongs_to and has_one associations (avoids N+1 queries)
users_with_posts = User.preload(:posts, :profile)
                      .where(active: true)
                      .all
posts = Post.preload(:user).all
# One query per association instead of one per record
```

### Transaction Management

```crystal
# Simple atomic transactions
User.transaction do |tx|
  user = User.create!(username: "john", email: "john@example.com")
  Post.create!(title: "First Post", content: "Hello!", user_id: user.id!)

  # Automatic rollback on any exception
  raise "Error!" if some_condition  # Everything safely rolls back
end

# Nested transactions are savepoints (on every adapter)
User.transaction do |outer_tx|
  user = User.create!(username: "alice", email: "alice@example.com")

  User.transaction(outer_tx) do |inner_tx|
    # Independent rollback scope
    risky_operation()
  rescue
    inner_tx.rollback  # Only inner transaction rolls back
  end

  # Outer transaction continues safely
end
```

### Schema Migrations

```crystal
# Version-controlled database evolution
class CreateUsersTable < CQL::Migration(20240101120000)
  def up
    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end

class AddEmailToUsers < CQL::Migration(20240102120000)
  def up
    schema.alter :users do
      add_column :email, String, null: false
      create_index :idx_users_email, [:email], unique: true
    end
  end

  def down
    schema.alter :users do
      drop_index :idx_users_email
      drop_column :email
    end
  end
end

# Safe migration management
migrator = CQL::Migrator.new(BlogDB)
migrator.up                        # Apply all pending migrations
migrator.down(1)                   # Rollback last migration safely
migrator.print_pending_migrations  # Check migration status
migrator.print_applied_migrations
```

### Query Scopes

```crystal
class Post
  # Define reusable query patterns
  scope :published, ->{ where(published: true) }
  scope :recent, ->{ where("created_at > ?", 1.week.ago).order(created_at: :desc) }
  scope :by_user, ->(user_id : Int64) { where(user_id: user_id) }
  scope :popular, ->{ where("view_count > ?", 1000) }
end

# Chainable, composable queries
trending_posts = Post.published
                    .recent
                    .popular
                    .limit(10)
                    .all

user_content = Post.by_user(user.id.not_nil!)
                  .published
                  .order(created_at: :desc)
                  .all
```

### Schema Dump

```crystal
# Import existing databases into CQL
require "cql"

# Connect to legacy database
dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, "sqlite3://legacy_app.db")

# Generate type-safe CQL schema from existing database
dumper.dump_to_file("src/schemas/legacy_schema.cr", :LegacyDB, :legacy_db)

# Generated schema uses proper CQL methods with type safety:
# text :name               # instead of generic column definitions
# integer :user_id         # with proper type inference
# timestamps               # standardized timestamp handling

dumper.close

# Now use your legacy database with full CQL features!
```

### Caching

```crystal
# Memory cache for lightning-fast access
memory_cache = CQL::Cache::MemoryCache.new(max_size: 1000)

# Redis cache for distributed applications
redis_cache = CQL::Cache::RedisCache.new("redis://localhost:6379")

# Fragment caching for expensive operations: a store plus an invalidation strategy
strategy = CQL::Cache::TimestampInvalidation.new(1.hour)
fragment_cache = CQL::Cache::FragmentCache.new(memory_cache, strategy)

# The block runs only on a cache miss and returns a String
titles_json = fragment_cache.cache_fragment(
  "active_user_posts",
  params: {"user_id" => user.id!} of String => DB::Any,
  tags: ["user:#{user.id}", "posts"],
  ttl: 10.minutes
) do
  Post.where(user_id: user.id!, published: true).all.map(&.title).to_json
end

# Tag-based cache invalidation
fragment_cache.invalidate_tags(["user:#{user.id}", "posts"])
```

### Performance Monitoring

```crystal
# Subscribe to every statement (selects, DML, DDL, explain)
CQL::Telemetry.subscribe("slow") do |event|
  puts "Slow query: #{event.sql} (#{event.duration.total_milliseconds}ms)" if event.duration > 100.milliseconds
end
CQL::Telemetry.alert_on_slow(100.milliseconds) { |event| Log.warn { event.sql } }

# N+1 query detection (with `CQL::Performance.enable_monitoring`, statements run through CQL feed the global monitor)
detector = CQL::Performance::NPlusOneDetector.new
queries.each { |sql| detector.record_query(sql) }
detector.patterns.each do |pattern|
  puts "⚠️  N+1 Query Pattern Detected:"
  puts "   Repeated #{pattern.repetition_count}x: #{pattern.repeated_query}"
  puts "   Suggestion: load the association once with .preload(:association)"
end

# Generate beautiful performance reports
report = CQL::Performance::PerformanceReport.new(10.seconds, total_queries: 120, slow_queries: 3, errors: 0)
report_generator = CQL::Performance::UnifiedReportGenerator.new
File.write("performance_report.html", report_generator.generate("html", report))
puts "📊 Performance report generated: performance_report.html"
```

## Use Cases

### High-Performance APIs

- RESTful APIs serving millions of requests
- GraphQL backends with complex data fetching
- Real-time applications with WebSocket connections
- Microservices requiring fast data access

### Enterprise Applications

- Large-scale web applications
- Complex business logic with data integrity requirements
- Multi-tenant SaaS platforms
- Financial and healthcare applications requiring compliance

### Cloud-Native Development

- Container-based deployments
- Kubernetes-native applications
- Serverless functions with database access
- Auto-scaling applications

### Modern Development Workflows

- CI/CD pipelines with database testing
- Type-safe development practices
- Large team collaboration
- Long-term maintenance and refactoring

## Documentation

**[Complete Documentation on GitBook →](https://azutopia.gitbook.io/cql)**

Comprehensive guides for every level:

### Getting Started

- **[Installation Guide](./docs/installation.md)** - Set up CQL in your project
- **[Getting Started](./docs/tutorials/getting-started/your-first-cql-app.md)** - Your first CQL application
- **[Configuration](./docs/how-to/configuration/database-connection.md)** - Environment setup and database connections

### Core Features

- **[Defining Models](./docs/how-to/models/define-model.md)** - Active Record model setup
- **[CRUD Operations](./docs/how-to/data-operations/create.md)** - Create, read, update, delete
- **[Complex Queries](./docs/how-to/querying/complex-queries.md)** - Advanced querying and N+1 prevention
- **[Validations](./docs/how-to/models/add-validations.md)** - Data validation and integrity
- **[Relationships](./docs/how-to/relationships/has-many.md)** - Model associations and relationships

### Advanced Topics

- **[Transactions](./docs/how-to/data-operations/transactions.md)** - Managing database transactions
- **[Migrations](./docs/how-to/migrations/run-migrations.md)** - Schema evolution and versioning
- **[Callbacks](./docs/how-to/models/use-callbacks.md)** - Lifecycle hooks and callbacks
- **[Scopes](./docs/how-to/querying/scopes.md)** - Reusable query methods
- **[Optimistic Locking](./docs/how-to/models/optimistic-locking.md)** - Concurrency control
- **[Dirty Tracking](./docs/how-to/models/dirty-tracking.md)** - Track changes and update only changed columns

### Performance & Production

- **[Advanced Caching](./docs/how-to/caching/query-cache.md)** - Multi-layer caching strategies
- **[Performance Monitoring](./docs/how-to/performance/monitoring.md)** - Query profiling and optimization
- **[Optimize Queries](./docs/how-to/performance/optimize-queries.md)** - Bulk writes, preload and the cached paths
- **[How CQL Keeps Queries Fast](./docs/explanation/performance-design.md)** - What each query costs and what is opt-in
- **[Benchmark CQL](./docs/how-to/performance/benchmark.md)** - Run the benchmarks and compare versions
- **[Testing Strategies](./docs/how-to/testing/test-models.md)** - Testing CQL applications

### Reference

- **[Quick Reference](./docs/reference/quick-reference.md)** - Cheat sheet for common operations
- **[Architecture Overview](./docs/explanation/README.md)** - Understanding CQL's design
- **[FAQ](./docs/resources/faq.md)** - Frequently asked questions
- **[Troubleshooting](./docs/how-to/troubleshooting/connection-errors.md)** - Common issues and solutions

## Development & Testing

### Running Tests

```bash
# Start PostgreSQL for full test suite
docker run --rm -e POSTGRES_DB=spec -e POSTGRES_PASSWORD=password -p 5432:5432 postgres

# Run comprehensive test suite with PostgreSQL
DATABASE_URL="postgres://postgres:password@localhost:5432/spec" crystal spec

# Quick test with SQLite (default)
crystal spec

# Run specific test categories
crystal spec spec/patterns/active_record/relations/  # Relationship tests
crystal spec spec/cache/                           # Caching tests
crystal spec spec/performance/                     # Performance tests
```

### Database Compatibility

CQL is actively tested and optimized for:

- **PostgreSQL**: 11 through 18 (native driver matrix above; the full spec suite runs against 16)
- **CockroachDB**: 24.3 through the PostgreSQL dialect and the native driver
- **MySQL**: 8.0+ with dialect-specific optimizations
- **SQLite**: 3.35+ perfect for development and testing

Each adapter supports database-specific features and provides optimal performance.

## Contributing

We welcome contributions! Here's how to get involved:

### Quick Start

1. Fork the repository on GitHub
2. Clone your fork: `git clone https://github.com/yourusername/cql.git`
3. Create your feature branch: `git checkout -b my-feature`
4. Make your changes and add comprehensive tests
5. Run the test suite: `crystal spec`
6. Commit your changes: `git commit -am 'Add feature'`
7. Push to your branch: `git push origin my-feature`
8. Create a Pull Request with a clear description

### Contribution Ideas

- **Bug Fixes** - Help improve reliability
- **Performance** - Optimize queries, reduce memory usage, improve speed
- **Documentation** - Improve guides, add examples, fix typos
- **Tests** - Add test coverage, create integration scenarios
- **Features** - Implement new ORM features and database support
- **Developer Experience** - Improve error messages, add tooling

### Development Guidelines

- Follow Crystal coding conventions and style guidelines
- Add comprehensive tests for new features and bug fixes
- Update documentation for API changes and new features
- Ensure compatibility across all supported databases (PostgreSQL, MySQL, SQLite, CockroachDB)
- Use meaningful commit messages following [conventional commits](https://conventionalcommits.org/)
- Add performance benchmarks for query-related features
- Consider security implications for new features

### Areas We Need Help With

- Database adapter improvements and new database support
- Query optimization and performance enhancements
- Documentation improvements and examples
- Testing across different Crystal versions
- Integration with popular Crystal web frameworks

## License

CQL is released under the [MIT License](./LICENSE). Feel free to use it in personal and commercial projects.

---

## Get Started

```crystal
# Install CQL and start building your application
shards install

# Try the interactive examples
crystal examples/run_examples.cr
```

**[Get Started Now →](./docs/tutorials/getting-started/your-first-cql-app.md) • [Try Examples →](./examples/) • [Join Community →](https://github.com/azutoolkit/cql/discussions)**

---

Built for the Crystal community.

CQL provides the productivity of modern ORMs with the performance and type safety that Crystal developers need. Whether you're building a simple web application or a complex enterprise system, CQL gives you the tools to work with your data efficiently and safely.
