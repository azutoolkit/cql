# Benchmark CQL

Measure CQL's speed with the repository's benchmarks, and compare two versions without fooling yourself.

## Pick a Benchmark

```bash
shards install --ignore-crystal-version   # once, from the repository root

# Query building and to_sql, then ActiveRecord on in-memory SQLite (find, where.order.first, last,
# exists?, find_each, associations and preload, create!, update!). Needs nothing.
crystal run --release benchmarks/sqlite_bench.cr

# What telemetry and the performance monitor add to one find and one create!. Needs nothing.
crystal run --release benchmarks/telemetry_overhead_bench.cr

# The native PostgreSQL driver against the pg shard: scalar and 100-row selects, inserts and a DSL lookup,
# on one fiber and several. Needs a disposable database it can write to.
DATABASE_URL=postgres://user:pass@localhost/db crystal run --release benchmarks/pg_wire_bench.cr

# Text against binary bind parameters through the native driver.
DATABASE_URL=postgres://user:pass@localhost/db crystal run --release benchmarks/pg_binary_params_bench.cr
```

[benchmarks/README.md](https://github.com/azutoolkit/cql/blob/master/benchmarks/README.md) lists every workload and setting (`BENCH_OPS`, `BENCH_CONCURRENCY`, `BENCH_ROUNDS` and more).

## Run One Workload

```bash
BENCH_ONLY=join crystal run --release benchmarks/sqlite_bench.cr                 # names containing "join", any case
BENCH_ONLY=tracer crystal run --release benchmarks/telemetry_overhead_bench.cr   # one configuration
```

In these two scripts a `BENCH_ONLY` that matches nothing exits with an error; `pg_binary_params_bench.cr` matches case-sensitively. Both print, per workload, iterations per second, time per iteration and bytes allocated per iteration. Bytes per iteration is the steadier number: it does not move with machine load.

{% hint style="warning" %}
Always build with `--release`: a debug build is unoptimized, so its timings say little about CQL.
{% endhint %}

## Compare Two Versions

```bash
# 1. Build both versions into separate binaries, instead of calling crystal run twice
git worktree add ../cql-base master
(cd ../cql-base && shards install --ignore-crystal-version && crystal build --release -o /tmp/bench_base benchmarks/sqlite_bench.cr)
crystal build --release -o /tmp/bench_new benchmarks/sqlite_bench.cr

# 2. Run them alternately, at least twice each, so both see the same machine conditions
for i in 1 2; do
  BENCH_ONLY=join /tmp/bench_base
  BENCH_ONLY=join /tmp/bench_new
done
```

Timings drift by several percent between runs on one machine. Trust a difference that shows up in every round, and in bytes per iteration where it applies; treat a few percent in one round as noise.

## Measure Your Own Workload

```crystal
require "benchmark"

Benchmark.ips do |x|
  x.report("find") { User.find(42) }
  x.report("to_sql") { User.where(active: true).order(name: :asc).limit(10).to_sql }
end
#   find 278.20k (  3.59µs) (± 6.30%)    384B/op   1.27× slower
# to_sql 352.39k (  2.84µs) (± 5.42%)  4.27kB/op        fastest
# label, iterations per second, time per iteration, deviation, bytes allocated per iteration
```

Run it with the configuration you deploy. SQL logging and the performance monitor, when on, add to every statement: [What monitoring costs](../observability/query-profiler.md#what-monitoring-costs) has the numbers.

## See Also

- [How CQL Keeps Queries Fast](../../explanation/performance-design.md)
- [Optimize Queries](optimize-queries.md)
- [Profile Queries and Detect N+1](../observability/query-profiler.md)
- [Monitor Performance](../observability/monitoring.md)
