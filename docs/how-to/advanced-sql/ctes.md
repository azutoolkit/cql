# Use CTEs and Recursive CTEs

Build `WITH` queries, recursive CTEs and subqueries in `FROM` on `CQL::Query` (`AppDB.query`). `QueryBuilder` and model classes do not have them.

The examples use `orders(customer_id, total)`, `customers(id, name)`, `users(name, age)` and `nodes(id, parent_id, name)`.

## Declare a CTE

```crystal
spend = AppDB.query.from(:orders)
  .select(:customer_id)
  .sum(:total, as: :spent)
  .group(:customer_id)

# The name works like a table, with the columns the body selects (aliases included)
query = AppDB.query
  .with(:totals, spend)
  .from(:totals).select(:customer_id, :spent)
  .where { totals.spent > 100 }

query.to_sql
# => {"WITH totals AS (SELECT orders.customer_id, SUM(orders.total) AS spent FROM orders GROUP BY orders.customer_id)
#      SELECT totals.customer_id, totals.spent FROM totals WHERE totals.spent > ?", [100]}
query.all(as: {Int64, Float64}) # => [{1, 150.0}]

# Values bind in text order: body first, then the outer query ($1, $2 on PostgreSQL)
AppDB.query.with(:totals, spend.clone.where { orders.total > 5 }).from(:totals).select(:spent)
  .where { totals.spent > 100 }.to_sql(for: CQL::Adapter::Postgres)
# => {"WITH totals AS (... WHERE orders.total > $1 GROUP BY ...) SELECT totals.spent FROM totals WHERE totals.spent > $2", [5, 100]}
```

## Use Several CTEs

```crystal
# The block receives a query that already knows the CTEs declared so far
AppDB.query
  .with(:totals, spend)
  .with(:big) { |scope| scope.from(:totals).select(:customer_id).where { totals.spent > 100 } }
  .from(:big).select(:customer_id)
# WITH totals AS (...), big AS (SELECT totals.customer_id FROM totals WHERE totals.spent > ?)
# SELECT big.customer_id FROM big

# A source that declares its own CTEs keeps them inside the body: big AS (WITH totals AS (...) ...)
AppDB.query.with(:big, AppDB.query.with(:totals, spend).from(:totals).select(:customer_id))
```

## Join a CTE to a Table

```crystal
AppDB.query
  .with(:totals, spend)
  .from(:customers)
  .join(:totals) { |j| j.totals.customer_id.eq(j.customers.id) } # always give the ON condition
  .select(customers: [:name], totals: [:spent])
  .all(as: {String, Float64})
# SELECT customers.name, totals.spent FROM customers INNER JOIN totals ON totals.customer_id = customers.id
```

## Read a CTE from a Subquery

```crystal
outer = AppDB.query.with(:totals, spend)

# nested returns a fresh query that already knows outer's CTEs
outer.from(:customers).select(:name)
  .where { exists?(outer.nested.from(:totals).select(:customer_id).where { totals.spent > 5 }) }
# ... FROM customers WHERE EXISTS (SELECT totals.customer_id FROM totals WHERE totals.spent > ?)
```

## Walk a Hierarchy

```crystal
anchor = AppDB.query.from(:nodes).select(:id, :parent_id, :name).where(id: 1)

# The block receives an empty query that knows :descendants and returns the recursive step
query = AppDB.query.with_recursive(:descendants, anchor) do |step|
  step.from(:descendants)
    .join(:nodes) { |j| j.nodes.parent_id.eq(j.descendants.id) }
    .select(nodes: [:id, :parent_id, :name])
end.from(:descendants).select(:name).order(id: :asc)
# WITH RECURSIVE descendants AS (SELECT nodes.id, nodes.parent_id, nodes.name FROM nodes WHERE nodes.id = ?
#   UNION ALL SELECT nodes.id, ... FROM descendants INNER JOIN nodes ON nodes.parent_id = descendants.id)
# SELECT descendants.name FROM descendants ORDER BY descendants.id ASC

query.all(as: String) # => ["root", "a", "b", "c"]

# all: false renders UNION, which drops duplicate rows and so stops cycles
AppDB.query.with_recursive(:descendants, anchor, all: false) do |step|
  step.from(:descendants).join(:nodes) { |j| j.nodes.parent_id.eq(j.descendants.id) }.select(nodes: [:id, :parent_id, :name])
end
```

## Query a Subquery in FROM

```crystal
ages = AppDB.query.from(:users).select(:name, :age)

AppDB.query.from(ages, as: :a).where { a.age >= 40 }.all(as: {String, Int32})
# SELECT a.name, a.age FROM (SELECT users.name, users.age FROM users) AS a WHERE a.age >= ?
# A later from(:users) replaces the subquery with the plain table
```

## Avoid These Errors

```crystal
AppDB.query.with(:"x; DROP TABLE y", spend)       # ArgumentError: Invalid CTE name ...
AppDB.query.with(:t, spend).with(:t, spend)        # ArgumentError: CTE t is already declared
AppDB.query.with(:t, spend).from(:t).select(:nope) # ArgumentError: Column 'nope' not found ...: t
AppDB.query.with(:t, spend).merge(AppDB.query.with(:t, spend))
# ArgumentError: Merge conflict: CTE t is defined differently in both queries (each query declares its own :t)
AppDB.query.with_recursive(:r, anchor) { |step| step.from(:r).select(:id, :parent_id, :name).limit(1) }
# ArgumentError: A recursive step cannot have ORDER BY, LIMIT or its own CTEs; apply them to the outer query
```

`clone` and `merge` carry CTEs along. A built statement is a snapshot: changing a source query later does not change a query that already used it.

{% hint style="info" %}
CTEs need MySQL 8.0+ and SQLite 3.8.3+. With `quote_identifiers: true` the CTE name is quoted too: `WITH "totals" AS (...)` on PostgreSQL, `` WITH RECURSIVE `r` AS (...) `` on MySQL.
{% endhint %}

In a set operation, an operand that declares CTEs is grouped: `UNION (WITH t AS (...) ...)` on PostgreSQL, `UNION SELECT * FROM (WITH t AS (...) ...)` on SQLite.

## See Also

- [Use Window Functions](window-functions.md)
- [Combine Queries with Set Operations](set-operations.md)
- [Build Complex Queries](../querying/complex-queries.md)
- [Inspect Queries with to_sql and explain](../querying/explain-and-to-sql.md)
- [The query DSL: before and after](../../explanation/dsl-before-after.md)
