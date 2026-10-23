# Benchmarks

Two scripts measure the native PostgreSQL driver (`CQL::Postgres`) against a real server. Neither one ships with results: numbers depend on your hardware, network, server settings and Crystal build, so run them in the environment you care about.

Both read the server from `DATABASE_URL`, create their own scratch table, and should be run with `--release` for meaningful timings. Run them from the repository root.

## Requirements

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

## Related

- The README section "Native PostgreSQL Driver" describes `binary_params`, pooling and streaming.
- `script/README.md` covers the scripts that verify the driver against many servers and poolers.
