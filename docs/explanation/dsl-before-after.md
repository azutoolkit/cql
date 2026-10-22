# The query DSL: before and after

CQL's query layer grew from "hash conditions and table names" into a typed,
composable DSL. This page puts the old and new spellings side by side. Every
"after" snippet runs against the current code; the old forms keep working
unless noted.

## Filtering

**Before** – conditions were hashes, or a block that had to spell out every
column through the model class. A typo in a column name was a runtime
`KeyError`, and the block form could not use bare names:

```crystal
User.where(active: true).order(created_at: :desc).limit(20).all

Product.where {
  products = Product.table_column(:category)
  products.eq("Electronics") & products.gt(50.0)
}.all
```

**After** – bare column names inside the block, typed to the column:

```crystal
User.query
  .where { (age >= 18) & (status == "active") }
  .order_by(created_at: :desc)
  .limit(20)
  .to_a

Product.query.where { (category == "Electronics") & (price > 50.0) }
```

What the compiler now checks:

| Mistake | Result |
| --- | --- |
| `where { agee > 1 }` (unknown column) | compile error naming the model and column |
| `where { age > "old" }` | compile error: `cannot compare a Int32 column with String` |
| `order_by(nope: :asc)` | compile error listing the model's columns |
| `joins(:books) { name_of_book == 1 }` | compile error: no such column |

`== nil` and `!= nil` mean `IS NULL` / `IS NOT NULL`; `not(...)`/`.not` negate
a whole condition; `in`, `between`, `like`, `ilike` are available on the
columns they make sense for (`like`/`ilike` only on `String` columns).

## Joins

**Before** – a table name; the `ON` clause was inferred from a foreign key and
raised at runtime when there were zero or several candidates:

```crystal
TestUser.join(:profiles)
```

**After** – an association declared on the model, with an optional typed
condition that is added to the join:

```crystal
Author.query.joins(:profile) { profile.country == "US" }
Author.query.left_joins(:books)
Book.query.joins(:author)
```

An unknown association raises with the valid names; the block is checked at
compile time against the model's columns and associations.

## Choosing columns

**Before** – `select(:id, :email)` still hydrated the whole model, so any
non-nilable attribute that was not selected raised
`DB::MappingException` at runtime.

**After** – a partial select returns lightweight rows whose unselected
columns are `nil`, and keeps the whole chain:

```crystal
rows = User.query.where { age >= 18 }.select(:id, :email).order_by(age: :desc).limit(20).to_a
rows.first.email # String?
```

## Raw SQL, safely

**Before** – no raw fragments at all; the azu_cli templates called a
`where("x = ?", v)` that did not exist.

**After** – fragments whose values are always bound, never interpolated:

```crystal
User.where("lower(email) = ? AND age > :age", "ada@example.com", age: 18) # mixing styles raises
Query.where("id IN (?)", [1, 2, 3])                                        # arrays expand
Query.where { raw("lower(name) = ?", name) | (customers.id == 1) }
```

The SQL text must be a literal; only the values are bound.

## Building blocks that did not exist

```crystal
# Common table expressions, recursive ones, and subqueries in FROM
query.with(:totals, orders.sum(:total, as: :spent).group(:customer_id)).from(:totals)
query.with_recursive(:tree, anchor) { |step| step.from(:tree).join(:nodes) { |j| ... } }
query.from(subquery, as: :recent)

# Window functions
query.select(:name).window(:row_number, as: :dept_rank, partition_by: :dept, order_by: {salary: :desc})
query.window(:sum, :salary, as: :running, order_by: :id, rows: {:unbounded_preceding, 0})

# Set operations
a.union(b).intersect(c).except(d)

# Upsert and bulk upsert
Insert.into(:users).values(rows).on_conflict(:email).do_update(:name, visits: 1)
Insert.into(:users).upsert(rows, conflict: [:email], update: [:name])

# Locking, DISTINCT ON, FULL / CROSS joins, COUNT(DISTINCT), ILIKE
query.lock(skip_locked: true)
query.distinct_on(:customer_id)
query.count(:customer_id, distinct: true, as: :buyers)

# JSON and geo predicates
documents.data.json_eq(["profile", "country"], "US")
places.location.within_distance(-122.4, 37.8, 500)
```

## Looking at what will run

**Before** – only `query.to_sql`.

**After**

```crystal
query.to_sql                                  # {sql, params} for the schema's dialect
query.to_sql(for: CQL::Adapter::Postgres)     # render for another dialect, no connection needed
query.explain                                 # the database's plan, one line per row
query.explain(analyze: true)                  # PostgreSQL / MySQL / CockroachDB
```

## One execution path

Every statement – selects, inserts, updates, deletes, DDL through
`Schema#exec`, `explain` – goes through `CQL::Execution.run`. That is where
performance tracking and telemetry happen, and where an explicit connection
can be supplied:

```crystal
schema.with_connection do |connection|
  tx = connection.begin_transaction
  Insert.into(:users).values(name: "ada").using(connection).commit
  User.query.using(connection).to_a
  tx.rollback
end

CQL::Telemetry.subscribe("metrics") { |event| StatsD.timing("sql.#{event.operation}", event.duration) }
CQL::Telemetry.alert_on_slow(200.milliseconds) { |event| Alerts.warn(event.sql) }
```

See [Telemetry](../how-to/performance/telemetry.md) for subscribers, the tracer
hook (OpenTelemetry, Dashforge) and parameter redaction.

## Compatibility notes

- `QueryBuilder#where { }`, `join { }`, `left { }` and `right { }` now return a
  new builder (like every other builder method) instead of also mutating the
  receiver. Use the return value.
- Aggregate aliases are symbols: `count(:id, as: :n)`.
- Identifier quoting is opt-in (`quote_identifiers: true` on the schema) and
  covers queries and DML, not DDL.
- `NOT (...)` is always parenthesized.
- See `CHANGELOG.md` for the complete list.
