# Use CTEs and Recursive CTEs

This guide shows you how to build `WITH` queries (common table expressions), recursive CTEs, and subqueries in `FROM` with `CQL::Query`.

CTEs and derived tables live on `CQL::Query` (`schema.query`). They are not available on `QueryBuilder` or model classes yet.

The examples use a schema with `orders(customer_id, total)` and `customers(id, name)`:

```crystal
spend = AppDB.query.from(:orders)
  .select(:customer_id)
  .sum(:total, as: :spent)
  .group(:customer_id)
```

## Declare a CTE

`with(name, source)` declares `WITH name AS (source)`. The name then works like a table in `from`, `join` and `where`, with the columns the source selects (aliased aggregates included):

```crystal
query = AppDB.query
  .with(:totals, spend)
  .from(:totals).select(:customer_id, :spent)
  .where { totals.spent > 100 }

sql, params = query.to_sql
```

```sql
WITH totals AS (SELECT orders.customer_id, SUM(orders.total) AS spent FROM orders GROUP BY orders.customer_id)
SELECT totals.customer_id, totals.spent FROM totals WHERE totals.spent > ?
```

`params` is `[100]`. Values inside the CTE body and the outer query are bound in text order; on PostgreSQL they are numbered `$1`, `$2`, ... in that same order.

## Use several CTEs

Declare as many as you need. A later CTE can read an earlier one if you build it with the block form, which hands you a query that already knows the CTEs declared so far:

```crystal
query = AppDB.query
  .with(:totals, spend)
  .with(:big) { |scope| scope.from(:totals).select(:customer_id).where { totals.spent > 100 } }
  .from(:big).select(:customer_id)
```

```sql
WITH totals AS (...), big AS (SELECT totals.customer_id FROM totals WHERE totals.spent > ?)
SELECT big.customer_id FROM big
```

Passing a query that itself carries CTEs (`.with(:big, other_query)`) also works; the inner `WITH` is rendered inside the CTE body.

## Join a CTE to a real table

Give the join an explicit condition:

```crystal
AppDB.query
  .with(:totals, spend)
  .from(:customers)
  .join(:totals) { |j| j.totals.customer_id.eq(j.customers.id) }
  .select(customers: [:name], totals: [:spent])
```

The generated SQL contains `INNER JOIN totals ON totals.customer_id = customers.id`.

## Use a CTE inside a subquery

Build subqueries that read the outer query's CTEs with `nested`, which returns a fresh query that already knows them:

```crystal
outer = AppDB.query.with(:totals, spend)

outer.from(:customers).select(:name)
  .where { exists?(outer.nested.from(:totals).select(:customer_id).where { totals.spent > 5 }) }
```

## Walk a hierarchy with a recursive CTE

`with_recursive(name, anchor) { |step| ... }` declares `WITH RECURSIVE name AS (anchor UNION ALL step)`. The block receives an empty query that already knows `name`, and returns the recursive step:

```crystal
anchor = AppDB.query.from(:nodes).select(:id, :parent_id, :name).where(id: 1)

query = AppDB.query.with_recursive(:descendants, anchor) do |step|
  step.from(:descendants)
    .join(:nodes) { |j| j.nodes.parent_id.eq(j.descendants.id) }
    .select(nodes: [:id, :parent_id, :name])
end.from(:descendants).select(:name).order(id: :asc)

query.all(as: String) # => ["root", "a", "b", "c"] for the spec's sample tree
```

The SQL starts with:

```sql
WITH RECURSIVE descendants AS (SELECT nodes.id, nodes.parent_id, nodes.name FROM nodes WHERE nodes.id = ? UNION ALL SELECT ...
```

Pass `all: false` to use `UNION` (which removes duplicate rows, and so stops cycles) instead of `UNION ALL`:

```crystal
AppDB.query.with_recursive(:r, anchor, all: false) { |step| ... }
```

A recursive step cannot have `ORDER BY`, `LIMIT` or its own CTEs; CQL raises `ArgumentError` ("A recursive step cannot have ORDER BY, LIMIT or its own CTEs"). Put those on the outer query, as above.

## Query a subquery in FROM

`from(subquery, as: :alias)` renders `FROM (SELECT ...) AS alias`. The selected columns are addressable through the alias:

```crystal
ages = AppDB.query.from(:users).select(:name, :age)

AppDB.query.from(ages, as: :a).to_sql[0]
# => "SELECT a.name, a.age FROM (SELECT ..."
```

Calling `from` again afterwards replaces the subquery with a plain table.

## Rules and errors

| Mistake | Result |
| --- | --- |
| CTE name that is not a plain identifier (`:"x; DROP TABLE y"`) | `ArgumentError` "Invalid CTE name" |
| Declaring the same name twice | `ArgumentError` "already declared" |
| Selecting a column the CTE does not expose | `ArgumentError` "not found" |
| Merging two queries that define different CTEs with the same name | `ArgumentError` "Merge conflict: CTE ..." |

`clone` and `merge` carry CTEs along, and a built statement is a snapshot: changing the source query afterwards does not change a query that already used it.

## Dialect notes

- CTEs and recursive CTEs need MySQL 8.0+ and SQLite 3.8.3+.
- With `quote_identifiers: true` the CTE name is quoted too: `WITH "totals" AS (...)` on PostgreSQL, `` WITH RECURSIVE `r` AS (...) `` on MySQL.
- Combined with set operations, an operand that declares CTEs is grouped: `UNION (WITH t AS (...) ...)` on PostgreSQL, and `SELECT * FROM (WITH t AS (...) ...)` on SQLite. See [Combine Queries with Set Operations](set-operations.md).

## Related

- [Use Window Functions](window-functions.md)
- [Combine Queries with Set Operations](set-operations.md)
- [Build Complex Queries](complex-queries.md)
- [The query DSL: before and after](../../explanation/dsl-before-after.md)
