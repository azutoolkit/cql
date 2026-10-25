# Benchmarks

Two scripts measure the native PostgreSQL driver (`CQL::Postgres`) against a real server, and two run on SQLite without a server: one measures query building and ActiveRecord operations, the other what telemetry and monitoring add to a statement. None ships with results: numbers depend on your hardware, network, server settings and Crystal build, so run them in the environment you care about.

The PostgreSQL scripts read the server from `DATABASE_URL` and create their own scratch table. All of them should be run with `--release` for meaningful timings, from the repository root.

## Requirements (PostgreSQL scripts)

- Crystal and the repository's dependencies (`shards install --ignore-crystal-version`). `pg_wire_bench.cr` also compiles the `pg` shard, which is a development dependency in `shard.yml`.
- A PostgreSQL server you can write to. Use a disposable database: the scripts drop and create tables.
- Put `sslmode=` in `DATABASE_URL` if the server requires TLS (for example `?sslmode=require`), so every driver negotiates TLS the same way.

## `pg_wire_bench.cr`

Compares CQL's wire driver (`CQL::Postgres::AsyncEngine`) with the `pg` shard on the same server, through the same crystal-db calls.

```bash
DATABASE_URL=postgres://user:pass@localhost/db crystal run --release benchmarks/pg_wire_bench.cr
```

Workloads, each run for both drivers:

- select one value, 1 fiber and `BENCH_CONCURRENCY` fibers
- select 100 rows, 1 fiber
- insert one row, 1 fiber and `BENCH_CONCURRENCY` fibers
- a one-row lookup through the CQL query DSL, 1 fiber and `BENCH_CONCURRENCY` fibers

It prints operations per second, mean, p50 and p99 latency per workload and driver. It then compares memory for one large result: read with `Session#stream` a fetch at a time against read whole, using the process's peak resident memory from `/proc` (Linux only).

| Variable | Default | Meaning |
| --- | --- | --- |
| `DATABASE_URL` | required | server to test |
| `BENCH_OPS` | 5000 | operations per workload |
| `BENCH_CONCURRENCY` | 8 | fibers for the concurrent workloads, and the size of each driver's pool |
| `BENCH_WARMUP` | 200 | warm-up operations before timing |
| `BENCH_STREAM_ROWS` | 200000 | rows in the streaming-memory comparison; `0` skips it |

It creates and drops the table `cql_wire_bench_items`.

### Reading the Results

- The drivers differ by design. The wire driver caches prepared statements per connection and reads binary results; the `pg` shard parses on every call.
- The wire driver runs first, and inserts are dominated by the server's commit.
- Everything runs on one Crystal thread.
- The `pg` shard's query-DSL rows go through a `CQL::Schema` with its own pool of the same maximum size, so that side can hold up to twice as many connections.

## `pg_binary_params_bench.cr`

Compares text and binary bind parameters (`binary_params=true`) on the same server, using the wire driver's session directly.

```bash
DATABASE_URL=postgres://user@localhost/db crystal run --release benchmarks/pg_binary_params_bench.cr
BENCH_ONLY=int8 DATABASE_URL=... crystal run --release benchmarks/pg_binary_params_bench.cr   # one workload
```

Workloads: six mixed scalars in one statement, single `int8`, `timestamptz` and `numeric` values, arrays (`int8[1000]`, `text[200]`, `timestamptz[500]`, `numeric[200]`) and a seven-column insert. For each one it first checks that the text and binary runs return the same rows (and aborts if not), then alternates the two modes within every round and reports the median statements per second and the binary-to-text ratio. A row marked `(no binary form)` means the driver fell back to text for that workload, so the two columns measure the same thing.

| Variable | Default | Meaning |
| --- | --- | --- |
| `DATABASE_URL` | required | server to test |
| `BENCH_OPS` | 5000 | statements per workload and round |
| `BENCH_ROUNDS` | 7 | rounds; text and binary alternate inside each, the median is reported |
| `BENCH_ONLY` | none | run only workloads whose name contains this text |

Parameter encoding is part of what is timed. It creates and drops the unlogged table `cql_binary_bench_items`.

## `sqlite_bench.cr`

Measures query building and SQL generation (`to_sql`, no round trip), then ActiveRecord operations against a real in-memory SQLite database. It needs no server and no `DATABASE_URL`: it creates and seeds its own `ar_users`, `ar_posts` and `ar_events` tables (10,000 users with 3 posts each) in a single-connection `sqlite3::memory:` pool, with indexes on `ar_posts.user_id` and `ar_users.age`.

```bash
crystal run --release benchmarks/sqlite_bench.cr
BENCH_ONLY=join crystal run --release benchmarks/sqlite_bench.cr   # one workload
```

Query-building workloads: a `where` by id, a ten-condition `where`, a join with order and limit, and a 500-row multi-row insert. ActiveRecord workloads (prefixed `ar:`): `find` by id, `where.order.first`, loading 100 rows with `limit(100).all`, `last`, `exists?`, `find_each` over 10,000 rows, has_many children (one parent through the association, and 100 parents through the association versus `preload`), `create!` of one record, `update!` of one record, and 1,000 `create!` calls per iteration. `last` reverses the order and takes one row, and `exists?` steps through at most one row. Writes go to `ar_events` (inserts) or one user row (update) and run after the reads. Each one is reported by `Benchmark.ips` as iterations per second, time per iteration and bytes allocated per iteration.

| Variable | Default | Meaning |
| --- | --- | --- |
| `BENCH_ONLY` | none | run only workloads whose name contains this text |

Building the query is part of what is timed (and, for `ar:` workloads, execution and row hydration); the insert's row hashes are built once beforehand. Seeding runs on every invocation, even with `BENCH_ONLY`. It runs with the library's default configuration, so the numbers reflect what an application gets out of the box. `BENCH_ONLY` ignores case, and a filter that matches nothing exits with an error.

## `telemetry_overhead_bench.cr`

Measures what CQL's telemetry and performance monitoring add to one statement. It runs `find` by id and `create!` against a seeded in-memory SQLite table (1,000 rows, a single-connection pool) under six configurations, in this order: all off, one synchronous `CQL::Telemetry.subscribe` subscriber, one `async: true` subscriber (the benchmark loop never yields, so the consumer fiber rarely runs and this row mostly measures the push and drop path), a no-op `CQL::Telemetry::Tracer`, `CQL::Performance.enable_production_mode!`, and SQL logging with the info lines filtered out by the log level, then a "baseline again" repeat of "all off" so drift over the run is visible. Every configuration starts from the 1,000 seeded rows, logging is set to errors only before timing starts (failed or very slow statements would still be logged, with their bound values), and "all off" is restored between configurations.

```bash
crystal run --release benchmarks/telemetry_overhead_bench.cr
BENCH_ONLY=tracer crystal run --release benchmarks/telemetry_overhead_bench.cr   # one configuration
```

Read each configuration's bytes per iteration and iterations per second against the "all off" run of the same operation: the difference is the cost of that instrumentation. Bytes per iteration is the reliable column; time differences under about 10% are within run-to-run noise. The production monitor row repeats one statement, so the N+1 detector takes its full pattern path every time: treat it as a worst case. `BENCH_ONLY` matches configuration names by substring, ignoring case. `spec/performance/overhead_spec.cr` asserts that the instrumentation around a statement allocates nothing with everything off and with one subscriber.

## Related

- The README section "Native PostgreSQL Driver" describes `binary_params`, pooling and streaming.
- `script/README.md` covers the scripts that verify the driver against many servers and poolers.
