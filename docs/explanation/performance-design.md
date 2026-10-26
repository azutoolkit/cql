# How CQL Keeps Queries Fast

CQL keeps the work it adds to a query small: diagnostics that cost time on every statement are opt-in, results that never change are computed once, and the ActiveRecord layer picks the query that reads the fewest rows. To tune an application, see [Optimize Queries](../how-to/performance/optimize-queries.md). To measure CQL itself, see [Benchmark CQL](../how-to/performance/benchmark.md).

## A Query Is Built, Rendered, Executed and Hydrated

```crystal
User.where(active: true).order(name: :asc).limit(10).all
# SELECT users.id, ... FROM users WHERE users.active = ? ORDER BY users.name ASC LIMIT ?
```

| Stage | What happens | What keeps it cheap |
| :--- | :--- | :--- |
| Build | Each `QueryBuilder` call clones its `CQL::Query` and records one clause. | A query allocates a clause collection (joins, GROUP BY, CTEs and so on) only when such a clause is added, and `clone` copies only the collections that hold something. |
| Render | `Query#build` turns the clauses into an AST, and `Expression::Generator`, a visitor, writes the SQL. | Every clause, condition and column writes into one string builder per statement, instead of each part building a string for its parent to copy. Values become placeholders. |
| Execute | `CQL::Execution.run` sends the SQL and its parameters through the schema's executor: the pooled connection, or the fiber's open transaction. | With no telemetry subscriber and the monitor off, the statement is not even timed. |
| Hydrate | Rows are decoded into models with `DB::Serializable`. | A partial `select` decodes into a lighter `Model::Row`. |

The benchmarks below measure building and rendering on their own, so you can compare that cost with your database's round trip.

## What Is Off by Default

Features that would tax every statement do nothing until you turn them on.

| Feature | Off unless | What it costs when on |
| :--- | :--- | :--- |
| Performance monitor (profiler, N+1 detector) | `config.monitor_performance = true`, `CQL::Performance.enable_monitoring`, `CQL::Performance.enable_sql_logging`, `CQL_MONITORING_ENABLED=true`, or `CRYSTAL_ENV` / `CQL_ENV` set to `development` when the monitor is first used | Each statement is timed and recorded, and its SQL is normalized for grouping (at most 512 normalized statements are cached). |
| SQL log | `CQL.build_schema` with `config.sql_logging = true`, or with development named (`CRYSTAL_ENV=development` or `config.env = "development"`, and `CQL_NO_SQL_LOG` unset); `CQL::Performance.enable_sql_logging`; the monitor's development default | One log line per statement, formatted only when its level is emitted. Bound values are left out unless `logging.include_params` is on. |
| Telemetry | `CQL::Telemetry.subscribe`, `log_queries` or `alert_on_slow` | One event per statement for each subscriber. Bound values are attached only with `CQL::Telemetry.capture_params = true`. |
| Per-request query cache | `CQL::Cache::RequestQueryCacheHelper.start_request`, or `RequestQueryCacheHelper.enabled = true` | Each statement is recorded by its SQL and a hash of its values, to count repeats within the request; results are not stored. At most `max_size` entries (1,000 by default). |

An unset `CRYSTAL_ENV` turns none of these on. See the [Configuration Reference](../reference/configuration.md) for every switch.

{% hint style="warning" %}
`CQL_NO_SQL_LOG` changes only the `CQL.configure` default. With `CRYSTAL_ENV=development`, the monitor still turns itself on with its SQL log the first time it is used.
{% endhint %}

## Work That Is Done Once

Some results do not change between calls, so CQL computes them once and reuses them:

- **`Model.find` statements.** A model that reads through CQL's own `self.query` (it carries the `CQL::ActiveRecord::StaticQuery` annotation, which SoftDeletable keeps) renders its find-by-id SQL once, as a `CQL::StatementTemplate`. Later calls bind only the new id. The statement is cached, never the result. A model that defines its own `self.query`, such as a tenant filter, and any subclass of a model render the statement on every call, so their scopes still apply. The template is rendered again after `Schema#alter` changes the table's columns.
- **Raw fragments.** `where("lower(name) = ?", value)` parses its SQL text once. The parsed template is reused with new values, and at most 512 templates are kept.
- **Dialects.** Each adapter has one dialect instance. PostgreSQL placeholders (`$1`, `$2`, and so on) come from a precomputed table.
- **Quoted identifiers.** With `quote_identifiers: true`, each table and column keeps its quoted name per dialect (`CQL::QuotedNameCache`), so the name is not quoted again on every render.
- **Prepared statements on PostgreSQL.** The native driver prepares each distinct SQL text once per connection and keeps it in a statement cache (`statement_cache_size`, 256 by default). A repeated query sends only Bind and Execute.

## Queries That Read Fewer Rows

The ActiveRecord layer picks the query that does the least work:

| Call | SQL it sends |
| :--- | :--- |
| `last` | The order reversed (ties broken by the primary key), `LIMIT 1`. A paged, grouped, aggregated or `DISTINCT` query loads its rows instead, because reversing it could change which row is last. |
| `exists?`, `any?` | `SELECT users.id ... LIMIT ?` with 1; `many?` asks for 2. Nothing is counted. |
| `count` | `COUNT(*)` without `ORDER BY`. With a limit or offset, it counts a subquery: `SELECT COUNT(*) FROM (SELECT users.id ... LIMIT ?) AS counted_rows`. |
| `find_each`, `find_in_batches` | Keyset pages, `WHERE ... AND users.id > ? ORDER BY users.id LIMIT ?`, so each batch costs the same however deep it is. A query with its own order, select, distinct, group or having falls back to `LIMIT ? OFFSET ?` pages. |
| `preload` | One query per association for `has_many`, `belongs_to` and `has_one`, split into `IN (...)` chunks that fit `Dialect#max_bind_params`. |
| `insert_all`, `upsert_all`, `insert_<name>_all` | Multi-row `INSERT` statements, sized to fit `max_bind_params`. |
| `delete_all` on a query | One `SELECT` of the matching ids, then `DELETE ... WHERE id IN (...)` per chunk. A model with destroy callbacks, a `dependent:` association or a `many_to_many` deletes record by record. |
| `create!` on PostgreSQL and CockroachDB | The new row is read back with `INSERT ... RETURNING` (`Dialect#supports_returning?`), one round trip instead of two, unless the model defines its own `self.query`. |
| `save` with `CQL::ActiveRecord::DirtyTracking` | Only the changed columns, and no `UPDATE` at all when nothing changed. |

`max_bind_params` is 999 on SQLite and 32,767 on the other dialects.

## Trade-offs

| Choice | What it costs |
| :--- | :--- |
| Values are always bound and identifiers validated. | There is no string-interpolation fast path. |
| A model with its own `self.query` renders its find statement per call. | It gives up the cached statement so that its scope always applies. |
| Bulk writes skip validations and callbacks. | Use the per-record methods (`save`, `create!`, `delete!`) when those must run. |
| Dirty tracking keeps a copy of each record's column values. | It costs memory, which is why it is opt-in. |

## Measuring It Yourself

`benchmarks/sqlite_bench.cr` measures query building, `to_sql` and ActiveRecord operations on SQLite, and `benchmarks/telemetry_overhead_bench.cr` what telemetry and the performance monitor add to one statement. `pg_wire_bench.cr` and `pg_binary_params_bench.cr` measure the native PostgreSQL driver. No results ship with them, because the numbers depend on your hardware and server; [Benchmark CQL](../how-to/performance/benchmark.md) shows how to run them and compare two versions.
