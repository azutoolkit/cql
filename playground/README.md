# CQL playground

Two runnable tours. `cql_demo.cr` needs no database server; `postgres_async_demo.cr` needs PostgreSQL.

```bash
shards install --ignore-crystal-version   # once
crystal run playground/cql_demo.cr
DATABASE_URL=postgres://user:pass@localhost/db crystal run playground/postgres_async_demo.cr
```

## `cql_demo.cr`

A tour of the query DSL on three models (`Author` with `has_one :profile` and `has_many :books`). It writes a SQLite
file to your temp directory (`cql_demo_<pid>.db`) and removes it on exit, so it needs `libsqlite3` but no server.
Each numbered section prints the SQL and bound parameters CQL generates and, where it runs the query, the rows:

| Section | Shows |
| --- | --- |
| 1 | typed `where { (age >= 18) & (status == "active") }` with `order_by` and `limit` |
| 2 | `joins(:profile) { profile.country == "US" }` |
| 3 | a partial `select(:id, :name)` returning lightweight rows |
| 4 | filters added conditionally |
| 5 | a raw fragment with named parameters and a hostile value, which stays data |
| 6 | a CTE plus a `RANK()` window function |
| 7 | `union` |
| 8 | upsert: `on_conflict(:id).do_update(:name, :age)` |
| 9 | one query rendered for SQLite, PostgreSQL, MySQL and CockroachDB with `to_sql(for: adapter)`; only SQLite runs |
| 10 | `explain` |
| 11 | the last statements a `CQL::Telemetry.subscribe` block saw |

Section 9's output:

```text
  SQLite      SELECT authors.name FROM authors WHERE authors.status = ? LIMIT ? OFFSET ?
  Postgres    SELECT authors.name FROM authors WHERE authors.status = $1 LIMIT $2 OFFSET $3
  MySql       SELECT authors.name FROM authors WHERE authors.status = ? LIMIT ? OFFSET ?
  CockroachDB SELECT authors.name FROM authors WHERE authors.status = $1 LIMIT $2 OFFSET $3
```

To see the compile-time checks, uncomment the two lines under section 1 and run again. The build stops with:

```text
Author.query.where { agee > 1 }     # Error: undefined local variable or method 'agee' for Author::Columns (with ... yield) and top-level (current scope)
Author.query.where { age > "old" }  # Error: CQL: cannot compare a Int32 column with String using `>`; use a Int32 value or another Int32 column
```

## `postgres_async_demo.cr`

A tour of `CQL::Postgres::AsyncEngine`, in eight sections: connecting a pool of five; a telemetry subscriber that
prints every statement; parameterized DSL queries with a hostile value; model hydration with `Order`; eight fibers
sharing the five connections; a pipeline of 200 statements against the same statements one by one; a committed and a
rolled-back transaction, then a serializable one with a savepoint and `synchronous_commit: false` (the commit can
return before the WAL is flushed: a server crash can lose it, never corrupt it); and a typed
`CQL::Postgres::UniqueViolation` whose message leaves out the duplicated value.

It creates the table `cql_async_demo_orders` (dropping any existing table of that name) and drops it when it exits.
The timings in sections 5 and 6 are measured on your machine each run. It requires the `pg` shard only so that
`CQL::Schema` can describe the PostgreSQL dialect; every statement runs on the engine.

## See Also

- [Typed Query DSL: Before and After](../docs/explanation/dsl-before-after.md)
- [Write Typed Queries](../docs/how-to/querying/typed-where-dsl.md)
- [AsyncEngine and pool options](../docs/how-to/postgres-native/async-engine.md)
- [Native PostgreSQL Driver](../README.md#native-postgresql-driver)
