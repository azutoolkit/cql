# Inspect Queries with to_sql and explain

This guide shows you how to see the SQL a query will run, render it for another database, and ask the database for its execution plan.

## See the SQL and its parameters

`to_sql` returns the SQL text and the bound parameters for the schema's dialect. Nothing is executed:

```crystal
query = AppDB.query.from(:customers).select(:name).where(city: "Tulum").limit(5)

sql, params = query.to_sql
```

Values are never in the SQL text; they are in `params`.

`to_sql` is available on queries and on set operations (`union`, ...). Model query builders have two flavours:

```crystal
User.query.where { age >= 18 }.to_sql              # SQL string only
User.query.where { age >= 18 }.to_sql_with_params  # {sql, params}
User.query.where { age >= 18 }.query.to_sql        # the underlying CQL::Query, {sql, params}
```

## Render for another dialect

`to_sql(for: adapter)` renders the same query for a different database, without a connection to it:

```crystal
query.to_sql(for: CQL::Adapter::Postgres)
# => {"SELECT customers.name FROM customers WHERE customers.city = $1 LIMIT $2", ["Tulum", 5]}

query.to_sql(for: CQL::Adapter::MySql)[0]
# ends with "customers.city = ? LIMIT ?"
```

The schema's `quote_identifiers` setting is used for the target dialect too: a schema with `quote_identifiers: true` renders `"order"."id"` for PostgreSQL. It works for set operations as well:

```crystal
query.union(other).to_sql(for: CQL::Adapter::Postgres)[0]
# contains "LIMIT $2) UNION SELECT users.name"
```

This is the tool for checking dialect differences before they reach production. The other adapters are `CQL::Adapter::SQLite` and `CQL::Adapter::CockroachDB`.

For a hand-built generator (for example to test an upsert), use `Expression::Generator`:

```crystal
query.to_sql(Expression::Generator.new(CQL::Adapter::Postgres))

AppDB.insert.into(:accounts).values(email: "a@x.io", name: "Ada")
  .on_conflict(:email).do_update(:name)
  .to_sql(Expression::Generator.new(CQL::Adapter::Postgres))
```

`Insert`, `Update` and `Delete` take a generator in `to_sql`; the `for:` form is on queries.

Some features raise `CQL::DialectError` while generating SQL for a dialect that lacks them, such as `lock` on SQLite or `full` joins on MySQL. Rendering with `for:` is a quick way to find out.

## Ask the database for its plan

`explain` runs the database's `EXPLAIN` on the query, with its parameters bound, and returns the plan as text, one line per plan row:

```crystal
plan = AppDB.query.from(:users).select(:name).where(name: "ada").explain
puts plan
```

| Dialect | Statement | One plan row |
| --- | --- | --- |
| PostgreSQL, CockroachDB | `EXPLAIN <sql>` | the plan text (e.g. `Seq Scan on t`) |
| MySQL | `EXPLAIN <sql>` | the row's columns joined with ` \| ` |
| SQLite | `EXPLAIN QUERY PLAN <sql>` | the detail column (e.g. `SCAN t`) |

It also works on set operations:

```crystal
names = AppDB.query.from(:users).select(:name)
names.union(names).explain
```

### Run and time it

```crystal
query.explain(analyze: true)
```

`analyze: true` actually executes the statement (`EXPLAIN ANALYZE`), so do not point it at a statement with side effects you do not want. It is available on PostgreSQL, MySQL and CockroachDB. On SQLite it raises `CQL::DialectError` ("SQLite does not support EXPLAIN ANALYZE").

### Plans are diagnostics

`explain` is not cached and is not counted as an application query by the performance monitor, so it does not show up in the performance monitor's query metrics. Telemetry reports it with the operation `:explain`; see [Telemetry](../performance/telemetry.md).

## Dialect notes

- MySQL needs 8.0.18+ for `EXPLAIN ANALYZE`.
- The plan text differs per database; do not parse it in application code.

## Related

- [Optimize Queries](../performance/optimize-queries.md)
- [Telemetry](../performance/telemetry.md)
- [Combine Queries with Set Operations](set-operations.md)
