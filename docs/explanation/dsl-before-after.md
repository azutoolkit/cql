# Typed Query DSL: Before and After

CQL's query layer grew from hash conditions and table names into a typed, composable DSL. Each section below sets the old spelling next to the new one and says which mistakes moved from run time to compile time. The old forms keep working unless noted. To write typed queries step by step, see [Write Typed Queries](../how-to/querying/typed-where-dsl.md).

## Filtering: Columns Are Checked by the Compiler

```crystal
# ❌ Before: every column spelled through the model; a typo is a KeyError at run time
User.where { User.table_column(:age).gt(17) & User.table_column(:status).eq("active") }.all

# ✅ After: bare column names, each typed to its column
User.query
  .where { (age >= 18) & (status == "active") }
  .order_by(created_at: :desc)
  .limit(20)
  .to_a
# SELECT users.id, ... FROM users WHERE (users.age >= ?) AND (users.status = ?)
#   ORDER BY users.created_at DESC LIMIT ?
```

What the compiler now rejects:

| Mistake | Compile error |
| :--- | :--- |
| `where { agee > 1 }` | `undefined local variable or method 'agee' for User::Columns` |
| `where { age > "old" }` | ``CQL: cannot compare a Int32 column with String using `>`; use a Int32 value or another Int32 column`` |
| `order_by(nope: :asc)` | ``CQL order_by: User has no column `nope`. Columns: id, name, ...`` |
| `joins(:posts) { name_of_post == 1 }` | `undefined local variable or method 'name_of_post' for User::Columns` |

Inside the block, `== nil` and `!= nil` mean `IS NULL` and `IS NOT NULL`, and `.not` negates a whole condition. `in`, `between`, `like` and `ilike` exist only on the columns they make sense for; `like` and `ilike` only on `String` columns.

## Joins: Associations Replace Table Names

```crystal
# ❌ Before: a table name; ON is inferred from a declared foreign key, and raises at run time without one
User.join(:posts)
# ArgumentError: Could not find a foreign key relationship between 'posts' and existing tables/aliases [users, posts]

# ✅ After: an association declared on the model, with an optional typed condition
User.query.joins(:profile) { profile.country == "US" }
# ... FROM users INNER JOIN profiles ON (profiles.user_id = users.id) AND (profiles.country = ?)
User.query.left_joins(:posts)
# ... FROM users LEFT JOIN posts ON posts.user_id = users.id
Post.query.joins(:user)
```

An unknown association raises with the valid names ("User has no association :nope. Associations: posts, profile"). The block is checked at compile time against the model's columns and its associations.

## Choosing Columns: Partial Rows Instead of Mapping Errors

Before, `select(:id, :email)` still hydrated the whole model, which failed at run time for every non-nilable attribute that was not selected. Now a partial select returns lightweight `User::Row` records whose unselected columns are `nil`, and the rest of the chain still works:

```crystal
rows = User.query.where { age >= 18 }.select(:id, :email).order_by(id: :asc).limit(20).to_a
rows.first.email # String?
rows.first.name  # => nil (not selected)
```

## Raw SQL: Fragments With Bound Values

Before, CQL had no raw fragments. Now fragments bind every value and never interpolate:

```crystal
User.query.where("lower(email) = ? AND age > ?", "ada@example.com", 18)         # positional
User.query.where("lower(email) = :email AND age > :age", email: "ada@example.com", age: 18) # named
User.query.where("id IN (?)", [1, 2, 3])                                        # id IN (?, ?, ?)
User.query.where { CQL.raw("lower(users.name) = ?", "ada") | (id == 1) }        # inside a typed block
AppDB.query.from(:users).where { raw("lower(users.name) = ?", "ada") | (users.id == 1) }
```

The SQL text must be a literal; only the values are bound. Mixing `?` and `:name` in one fragment, a wrong value count and an empty array each raise `ArgumentError`.

## Building Blocks That Did Not Exist

```crystal
# CTEs: WITH totals AS (SELECT orders.customer_id, SUM(orders.total) AS spent ... GROUP BY orders.customer_id)
spend = AppDB.query.from(:orders).select(:customer_id).sum(:total, as: :spent).group(:customer_id)
big_spenders = AppDB.query.with(:totals, spend).from(:totals).select(:customer_id).where { totals.spent > 100 }

# Recursive CTEs: WITH RECURSIVE tree AS (... UNION ALL SELECT ... FROM tree INNER JOIN nodes ON nodes.parent_id = tree.id)
anchor = AppDB.query.from(:nodes).select(:id, :parent_id, :name).where(id: 1)
descendants = AppDB.query.with_recursive(:tree, anchor) do |step|
  step.from(:tree)
    .join(:nodes) { |j| j.nodes.parent_id.eq(j.tree.id) }
    .select(nodes: [:id, :parent_id, :name])
end.from(:tree).select(:name)

# Subqueries in FROM: SELECT recent.customer_id FROM (SELECT ...) AS recent
recent = AppDB.query.from(:orders).select(:customer_id, :total).where { orders.total > 25 }
AppDB.query.from(recent, as: :recent).select(:customer_id)

# Window functions: ROW_NUMBER() OVER (PARTITION BY employees.dept ORDER BY employees.salary DESC) AS dept_rank
AppDB.query.from(:employees).select(:name)
  .window(:row_number, as: :dept_rank, partition_by: :dept, order_by: {salary: :desc})
AppDB.query.from(:employees).select(:name)
  .window(:sum, :salary, as: :running, order_by: :id, rows: {:unbounded_preceding, 0})

# Set operations: UNION, UNION ALL, INTERSECT, EXCEPT
active = AppDB.query.from(:users).select(:email).where(active: true)
admins = AppDB.query.from(:users).select(:email).where(status: "admin")
active.union(admins)
active.except(admins)

# Upserts: INSERT ... ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name, age = ?
AppDB.insert.into(:users).values(name: "Ada", email: "ada@example.com").on_conflict(:email).do_update(:name, age: 37)
new_rows = [{:name => "Ada".as(DB::Any), :email => "ada@example.com".as(DB::Any)}]
AppDB.insert.into(:users).upsert(new_rows, conflict: [:email], update: [:name])

# Row locks (not on SQLite) and DISTINCT ON (PostgreSQL and CockroachDB)
AppDB.query.from(:orders).select(:id).lock(skip_locked: true)
AppDB.query.from(:orders).select(:customer_id, :total).distinct_on(:customer_id).order(customer_id: :asc, total: :desc)

# COUNT(DISTINCT orders.customer_id) AS buyers
AppDB.query.from(:orders).count(:customer_id, distinct: true, as: :buyers)
```

`CQL::Query` also gained `full(:table) { |j| ... }` and `cross(:table)` joins (see [Use FULL and CROSS Joins](../how-to/advanced-sql/joins-full-cross.md)). Row locks, `DISTINCT ON`, `FULL` joins and geospatial filters raise `CQL::DialectError` on the dialects that lack them. JSON and geo predicates (`documents.data.json_eq(["profile", "country"], "US")`, `places.location.within_distance(-122.4, 37.8, 500)`) are covered in [Query JSON and Geospatial Columns](../how-to/advanced-sql/json-and-geo-predicates.md).

## Inspecting a Query Before It Runs

Before, there was only `to_sql`. Now:

```crystal
query = AppDB.query.from(:users).select(:name).where(email: "ada@example.com")

query.to_sql                              # => {"SELECT users.name FROM users WHERE users.email = ?", ["ada@example.com"]}
query.to_sql(for: CQL::Adapter::Postgres) # => {"... WHERE users.email = $1", ["ada@example.com"]}, no connection needed
query.explain                             # the database's plan, one line per row ("SCAN users" on SQLite)
query.explain(analyze: true)              # runs the statement; PostgreSQL, MySQL and CockroachDB only
```

## One Execution Path

Every statement goes through `CQL::Execution.run`: selects, inserts, updates, deletes, DDL through `Schema#exec`, and `explain`. Telemetry happens there for all of them, performance tracking for selects and DML (not `Schema#exec` or `explain`), and that is where an explicit connection can be supplied:

```crystal
AppDB.with_connection do |connection|
  tx = connection.begin_transaction
  AppDB.insert.into(:users).values(name: "Ada", email: "ada@example.com").using(connection).commit
  User.query.using(connection).to_a
  tx.rollback
end

CQL::Telemetry.subscribe("metrics") { |event| Log.info { "sql.#{event.operation} #{event.duration.total_milliseconds}ms" } }
CQL::Telemetry.alert_on_slow(200.milliseconds) { |event| Log.warn { event.sql } }
```

See [Telemetry](../how-to/observability/telemetry.md) for subscribers, the tracer hook and parameter capture.

## Compatibility Notes

- `QueryBuilder#where { }`, `join { }`, `left { }` and `right { }` return a new builder, like every other builder method, instead of also changing the receiver. Use the return value.
- Aggregate aliases are symbols: `count(:id, as: :n)`.
- Identifier quoting is opt-in (`quote_identifiers: true` on the schema) and covers queries and DML, not DDL.
- `NOT (...)` is always parenthesized: `NOT ((users.age > ?) AND (users.age < ?))`.
- See `CHANGELOG.md` for the complete list.
