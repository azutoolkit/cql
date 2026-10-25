# How CQL Keeps Queries Fast

This page explains what CQL does for each query, which parts cost time, and the design choices that keep that cost low. It is background reading; for step-by-step instructions see [Optimize Queries](../how-to/performance/optimize-queries.md) and [Benchmark CQL](../how-to/performance/benchmark.md).

## The Life of a Query

```crystal
User.where(active: true).order(name: :asc).limit(10).all
```

1. **Build.** The query builder records the clauses. A `CQL::Query` allocates a clause collection (joins, GROUP BY, CTEs and so on) only when a clause of that kind is added, and `clone` copies only the collections that hold something, so a chained call costs little.
2. **Render.** `Query#build` turns the clauses into an AST, and `Expression::Generator` (a visitor) writes the SQL. Every clause, condition and column reference is written straight into one string builder for the statement, instead of each part building its own string for its parent to copy. Values are never written into the SQL: each one is bound as a parameter.
3. **Execute.** The SQL and its parameters go to the database through the schema's executor (the connection pool, or the fiber's open transaction).
4. **Hydrate.** Rows are decoded into model instances (`DB::Serializable`).

For most applications the database round trip dominates. On an in-memory SQLite database, building and rendering a simple query takes about a microsecond. Against a PostgreSQL server, one round trip on a local socket is tens of microseconds.

## What Is Off by Default

Features that would tax every query are opt-in:

- **Performance monitor** (profiler, N+1 detector): off unless you set `config.monitor_performance = true`, call `CQL::Performance.enable_monitoring` or `enable_sql_logging`, set `CQL_MONITORING_ENABLED=true`, or run with `CRYSTAL_ENV` or `CQL_ENV` set to `development`. SQL logging, when on, enables it too. When it is on, a query's log line is formatted only if its level is emitted, and normalized SQL is cached (at most 512 entries).
- **SQL logging**: on only when development is named, with `CRYSTAL_ENV=development` or `config.env = "development"` (and `CQL_NO_SQL_LOG` unset), or when you set `config.sql_logging = true`. An unset `CRYSTAL_ENV` does not turn it on. Logging every query costs several microseconds, which can be more than the query itself on a fast path.
- **Per-request query cache**: it stores nothing until `CQL::Cache::RequestQueryCacheHelper.start_request` is called (or `RequestQueryCacheHelper.enabled = true`), and it is bounded by `max_size`.

See [Configuration reference](../reference/configuration.md) for every switch.

## Work Done Once, Not per Query

Several results are computed once and reused, because they do not change between calls:

- **`Model.find` statements.** A model that reads through CQL's own `self.query` (marked with the `CQL::ActiveRecord::StaticQuery` annotation, which SoftDeletable keeps) renders its find-by-id SQL once, as a `CQL::StatementTemplate`, and rebinds only the id. The statement is cached, never the result. A model that defines its own `self.query`, for example a tenant filter, and any subclass of a model render per call, so per-call scopes still apply. The template is re-rendered if `Schema#alter` changes the table's columns.
- **Raw fragments.** `where("lower(name) = ?", value)` parses its SQL text once, and the parsed template (at most 512 kept) is reused with new values.
- **Dialects.** There is one dialect instance per adapter, and PostgreSQL placeholders (`$1`, `$2`, ...) come from a precomputed table.
- **Quoted identifiers.** With `quote_identifiers: true`, each table and column keeps its quoted name per dialect (`CQL::QuotedNameCache`), which closes most of the gap between quoted and unquoted SQL.
- **Prepared statements on PostgreSQL.** The native driver prepares each distinct SQL text once per connection and keeps it in a statement cache (`statement_cache_size`, 256 by default), so a repeated query sends only Bind and Execute.

## Algorithms That Avoid Extra Rows and Round Trips

The ActiveRecord layer picks the query that does the least work:

- **`last`** reverses the order and fetches one row; it does not load the table.
- **`exists?` and `any?`** select one row with `LIMIT 1` instead of counting every match; `many?` stops at two.
- **`count`** drops `ORDER BY` and counts through a subquery when a limit or offset is set.
- **`find_each` and `find_in_batches`** page by primary key (`WHERE id > ? ORDER BY id LIMIT n`), so each batch costs the same however deep it is.
- **`preload`** loads `has_many`, `belongs_to` and `has_one` associations with one query per chunk of ids, chunked under the dialect's bind-parameter limit (`Dialect#max_bind_params`).
- **Bulk writes.** `insert_all`, `upsert_all` and has_many's `insert_<name>_all` send multi-row statements; `delete_all` reads the matching ids with one SELECT and deletes them with one `DELETE ... WHERE id IN (...)` per chunk of `max_bind_params`, when the model has no destroy callbacks, no `dependent:` association and no `many_to_many`.
- **`create!` on PostgreSQL and CockroachDB** reads the new row from `INSERT ... RETURNING` (`Dialect#supports_returning?`), one round trip instead of two.
- **Dirty tracking** (opt-in, `CQL::ActiveRecord::DirtyTracking`) sends only changed columns, and no UPDATE at all when nothing changed.

## Trade-offs

- **Safety over speed.** Values are always bound and identifiers validated; there is no string-interpolation fast path.
- **Correctness of scopes.** A model with its own `self.query` gives up the cached find statement, so its scope is applied on every call.
- **Callbacks.** Bulk writes skip validations and callbacks by design; the per-record methods (`create!`, `save`, `delete!`) keep them.
- **Memory for tracking.** A dirty-tracked record keeps a copy of its column values, which is why tracking is opt-in.

## Measuring It Yourself

`benchmarks/sqlite_bench.cr` measures query building and ActiveRecord operations on SQLite, and `benchmarks/pg_wire_bench.cr` the native PostgreSQL driver. [Benchmark CQL](../how-to/performance/benchmark.md) explains how to run them and compare two versions.
