# CQL playground

`cql_demo.cr` is a runnable tour of the query DSL: typed `where` blocks, association joins,
partial selects, conditionally built filters, bound raw fragments, a CTE with a window function,
set operations, upsert, rendering one query for every dialect, `explain`, and a telemetry
subscriber that observes all of it.

```bash
shards install --ignore-crystal-version   # once
crystal run playground/cql_demo.cr
```

"No setup" here means no database *server*: the demo writes a throwaway SQLite file in your
temp directory and removes it on exit. You still need the shards installed and `libsqlite3`
available on your system.

## Reading the output

Each numbered section prints the SQL and bound parameters CQL generates and, where it runs the
query, the rows it got back. Section 9 renders the same query for SQLite, PostgreSQL, MySQL and CockroachDB without
connecting to any of them (`query.to_sql(for: adapter)`); only SQLite is executed.

## Things to try

Uncomment the two compile-error lines in section 1 and run again: the build fails with a message
naming the model and the column, instead of failing at runtime.

```crystal
Author.query.where { agee > 1 }     # undefined method 'agee' for Author::Columns
Author.query.where { age > "old" }  # CQL: cannot compare a Int32 column with String
```

## Native PostgreSQL driver demo

`postgres_async_demo.cr` tours `CQL::Postgres::AsyncEngine`: connecting to a pool, telemetry output for every
statement, parameterized queries through the CQL DSL (with a hostile value, to show it is only data), model hydration,
eight fibers sharing five pooled connections, a pipelined batch of 200 statements against the same statements one by
one, a committed and a rolled-back transaction, and a typed `UniqueViolation` whose message omits the duplicated value.
Unlike `cql_demo.cr` it needs a PostgreSQL server, because the point is the wire driver:

```bash
shards install --ignore-crystal-version   # once
DATABASE_URL=postgres://user:pass@localhost/db crystal run playground/postgres_async_demo.cr
```

It creates the table `cql_async_demo_orders` (dropping any existing table of that name) and drops it when it exits. Timings in sections 5 and 6 are measured on
your machine each time you run it; they are not fixed numbers.
