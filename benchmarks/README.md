# Benchmarks

Four scripts, run from the repository root with `--release`. Two need no server (SQLite in memory); two measure the
native PostgreSQL driver (`CQL::Postgres`) against a real server. None ships with results: numbers depend on your
hardware, network, server settings and Crystal build.

```bash
crystal run --release benchmarks/sqlite_bench.cr
crystal run --release benchmarks/telemetry_overhead_bench.cr
DATABASE_URL=postgres://user:pass@localhost/db crystal run --release benchmarks/pg_wire_bench.cr
DATABASE_URL=postgres://user:pass@localhost/db crystal run --release benchmarks/pg_binary_params_bench.cr
```

| Script | Measures | Needs |
| --- | --- | --- |
| `sqlite_bench.cr` | query building and `to_sql`, then ActiveRecord operations | nothing |
| `telemetry_overhead_bench.cr` | what telemetry and the performance monitor add to one statement | nothing |
| `pg_wire_bench.cr` | CQL's wire driver against the `pg` shard, and streaming memory | PostgreSQL |
| `pg_binary_params_bench.cr` | text against binary bind parameters | PostgreSQL |

## `sqlite_bench.cr`

```bash
BENCH_ONLY=join crystal run --release benchmarks/sqlite_bench.cr   # workloads whose name contains "join"
```

It seeds 10,000 `ar_users` with 3 `ar_posts` each, plus an empty `ar_events`, in a single-connection
`sqlite3::memory:` pool, with indexes on `ar_posts.user_id` and `ar_users.age`. Seeding runs on every invocation,
even with `BENCH_ONLY`. It uses the library's default configuration, so the numbers are what an application gets out
of the box. `Benchmark.ips` reports iterations per second, time per iteration and bytes allocated per iteration.

| Workloads | What is timed |
| --- | --- |
| `simple where by id` (also `quoted ...`, on a schema with `quote_identifiers: true`), `10-condition where`, `join with order and limit`, `insert 500 rows` | building the query and `to_sql`, no round trip; the insert's row hashes are built beforehand |
| `ar: find by id`, `ar: where + order + first`, `ar: load 100 rows`, `ar: last`, `ar: exists?`, `ar: find_each 10000 rows` | building, executing and hydrating |
| `ar: has_many children` | one parent through the association; 100 parents through the association against `preload(:posts)` |
| `ar: insert one`, `ar: update one`, `ar: insert 1000 records` | `create!` into `ar_events` and `update!` of one user, after the reads |

| Variable | Default | Meaning |
| --- | --- | --- |
| `BENCH_ONLY` | none | run only workloads whose name contains this text, ignoring case; a filter that matches nothing exits with an error |

The [Performance](../README.md#performance) table in the root README is one run of this script.

## `telemetry_overhead_bench.cr`

```bash
BENCH_ONLY=tracer crystal run --release benchmarks/telemetry_overhead_bench.cr   # one configuration
```

`find` by id and `create!` against 1,000 seeded rows (a single-connection in-memory pool), under each configuration
in this order:

| Configuration | Set up with |
| --- | --- |
| `all off` | a monitor built from `CQL::Performance.minimal_config`, `CQL::Telemetry.reset!` |
| `sync subscriber` | `CQL::Telemetry.subscribe("bench") { }` |
| `async subscriber` | `subscribe("bench", async: true)`; the loop never yields, so this mostly measures the push and drop path |
| `tracer` | a no-op `CQL::Telemetry::Tracer` |
| `production monitor` | `CQL::Performance.enable_production_mode!` |
| `async monitor` | the production config with `monitoring.async = true`; mostly the push and drop path again |
| `sql logging, filtered out` | `CQL::Performance.enable_sql_logging(colorize: false)` with info lines below the log level |
| `baseline again` | `all off` repeated, so drift over the run is visible |

Every configuration starts from the 1,000 seeded rows, logging is set to errors only before timing (failed or very
slow statements would still be logged, with their bound values), and `all off` is restored between configurations.
Compare each row's bytes per iteration and iterations per second with `all off`. Bytes per iteration is the reliable
column; time differences under about 10% are run-to-run noise. The production monitor row repeats one statement, so
the N+1 detector takes its full pattern path every time: treat it as a worst case. `BENCH_ONLY` matches configuration
names by substring, ignoring case. `spec/performance/overhead_spec.cr` asserts that the instrumentation around a
statement allocates nothing with everything off and with one subscriber.

## PostgreSQL Scripts

Both read the server from `DATABASE_URL` and create their own scratch table, so use a disposable database. Put
`sslmode=` in `DATABASE_URL` when the server requires TLS (for example `?sslmode=require`), so every driver
negotiates TLS the same way. `pg_wire_bench.cr` also compiles the `pg` shard, a development dependency in
`shard.yml` (`shards install --ignore-crystal-version`).

### `pg_wire_bench.cr`

Compares `CQL::Postgres::AsyncEngine` with the `pg` shard through the same crystal-db calls. It first reads one large
result twice, with `Session#stream` 1000 rows per fetch and then whole, and prints the rows held at once, the time and
the peak resident memory from `/proc` (Linux only). Then each driver runs, wire driver first:

- select one value, 1 fiber and `BENCH_CONCURRENCY` fibers
- select 100 rows, 1 fiber (`BENCH_OPS / 10` operations)
- insert one row, 1 fiber and `BENCH_CONCURRENCY` fibers
- a one-row lookup through the CQL query DSL, 1 fiber and `BENCH_CONCURRENCY` fibers

It prints operations per second and mean, p50 and p99 latency per workload and driver, and creates and drops
`cql_wire_bench_items`.

| Variable | Default | Meaning |
| --- | --- | --- |
| `DATABASE_URL` | required | server to test |
| `BENCH_OPS` | 5000 | operations per workload |
| `BENCH_CONCURRENCY` | 8 | fibers for the concurrent workloads, and each driver's pool size (filled before timing) |
| `BENCH_WARMUP` | 200 | warm-up operations before timing |
| `BENCH_STREAM_ROWS` | 200000 | rows in the streaming comparison; `0` skips it |

Reading the results: the wire driver caches prepared statements per connection and reads binary results, while the
`pg` shard parses on every call; inserts are dominated by the server's commit; everything runs on one Crystal
thread; and the `pg` shard's query-DSL rows go through a `CQL::Schema` with its own pool of the same maximum size, so
that side can hold up to twice as many connections.

### `pg_binary_params_bench.cr`

```bash
BENCH_ONLY=int8 DATABASE_URL=... crystal run --release benchmarks/pg_binary_params_bench.cr   # one workload
```

Compares text and binary bind parameters (`binary_params=true`) on the wire driver's session. Workloads: six mixed
scalars in one statement; single `int8`, `timestamptz` and `numeric` values; `int8[1000]`, `text[200]`,
`timestamptz[500]` and `numeric[200]`; a seven-column insert into the unlogged table `cql_binary_bench_items`, which it
creates and drops. For each workload it first checks that text and binary return the same rows (and aborts if not),
then alternates the two modes within every round and reports the median statements per second and the binary-to-text
ratio. Parameter encoding is part of what is timed. A row marked `(no binary form)` fell back to text, so both
columns measure the same thing.

| Variable | Default | Meaning |
| --- | --- | --- |
| `DATABASE_URL` | required | server to test |
| `BENCH_OPS` | 5000 | statements per workload and round |
| `BENCH_ROUNDS` | 7 | rounds; text and binary alternate inside each, the median is reported |
| `BENCH_ONLY` | none | run only workloads whose name contains this text (case-sensitive) |

## See Also

- [Native PostgreSQL Driver](../README.md#native-postgresql-driver): `binary_params`, pooling, streaming, and the
  measured results of both PostgreSQL scripts
- [Benchmark a Change](../docs/resources/contributing.md#benchmark-a-change): compare two versions
- [script/README.md](../script/README.md): the scripts that check the driver against many servers and poolers
