# Benchmark CQL

This guide shows you how to measure CQL's speed with the benchmarks in the repository, and how to compare two versions without fooling yourself.

## Prerequisites

- Crystal and the dependencies installed (`shards install --ignore-crystal-version`)
- For the PostgreSQL benchmarks: a disposable database you can write to, in `DATABASE_URL`

## Pick a Benchmark

| Script | Measures | Needs |
| --- | --- | --- |
| `benchmarks/sqlite_bench.cr` | Query building and SQL generation (`to_sql`), then ActiveRecord operations (`find`, `where.order.first`, `last`, `exists?`, `find_each`, associations and preload, `create!`, `update!`) on in-memory SQLite | Nothing |
| `benchmarks/pg_wire_bench.cr` | CQL's native PostgreSQL driver against the `pg` shard: scalar selects, 100-row selects, inserts and a DSL lookup, on one fiber and several | `DATABASE_URL` |
| `benchmarks/pg_binary_params_bench.cr` | Text against binary bind parameters through the native driver | `DATABASE_URL` |

[benchmarks/README.md](../../../benchmarks/README.md) lists every workload and setting.

## Run One

Always build with `--release`; a debug build measures the compiler, not CQL:

```bash
crystal run --release benchmarks/sqlite_bench.cr
BENCH_ONLY=join crystal run --release benchmarks/sqlite_bench.cr      # workloads whose name contains "join"
DATABASE_URL=postgres://user:pass@localhost/db crystal run --release benchmarks/pg_wire_bench.cr
```

`sqlite_bench.cr` prints, per workload, iterations per second, time per iteration and bytes allocated per iteration. Bytes per iteration is the steadier number: it does not move with machine load.

## Compare Two Versions

Timings drift by several percent between runs on the same machine. To compare a change with a baseline:

1. Build both versions into separate binaries instead of using `crystal run` twice:

   ```bash
   git worktree add ../cql-base master
   (cd ../cql-base && crystal build --release -o /tmp/bench_base benchmarks/sqlite_bench.cr)
   crystal build --release -o /tmp/bench_new benchmarks/sqlite_bench.cr
   ```

2. Run them alternately, at least twice each, so both see the same machine conditions:

   ```bash
   for i in 1 2; do
     BENCH_ONLY=join /tmp/bench_base
     BENCH_ONLY=join /tmp/bench_new
   done
   ```

3. Trust a difference that shows up in every round, and in bytes per iteration where it applies. Treat a few percent on one round as noise.

## Measure Your Own Workload

To time a query from your application, use Crystal's `Benchmark`:

```crystal
require "benchmark"

Benchmark.ips do |x|
  x.report("find") { User.find(42) }
  x.report("to_sql") { User.where(active: true).order(name: :asc).limit(10).to_sql }
end
```

Run it with the configuration you deploy with: SQL logging or the performance monitor, when enabled, cost several microseconds per query (see [How CQL Keeps Queries Fast](../../explanation/performance-design.md#what-is-off-by-default)).

## See Also

- [How CQL Keeps Queries Fast](../../explanation/performance-design.md)
- [Optimize Queries](optimize-queries.md)
- [Profile Queries and Detect N+1](query-profiler.md)
