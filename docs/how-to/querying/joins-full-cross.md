# Use FULL and CROSS Joins

This guide shows you how to add `FULL JOIN` and `CROSS JOIN` clauses with `CQL::Query#full` and `#cross`. For the common joins see the other join methods listed at the end.

## FULL JOIN

`full(table) { |j| ... }` keeps rows from both sides, matched on the condition you give. The block receives a filter builder with every table in the query:

```crystal
AppDB.query.from(:customers).select(customers: [:name])
  .full(:orders) { |j| j.orders.customer_id.eq(j.customers.id) }
```

The SQL contains:

```sql
FULL JOIN orders ON orders.customer_id = customers.id
```

Customers without orders and orders without customers both appear, with `NULL` for the missing side.

## CROSS JOIN

`cross(table)` pairs every row with every row of the other table. It takes no block and renders no `ON`:

```crystal
AppDB.query.from(:customers).select(customers: [:name]).cross(:orders)
```

```sql
... FROM customers CROSS JOIN orders
```

Use it for generating combinations, such as every product with every size.

## Regular joins

The same query takes the other join types:

```crystal
query.join(:totals) { |j| j.totals.customer_id.eq(j.customers.id) }   # INNER JOIN
query.left(:orders) { |j| j.orders.customer_id.eq(j.customers.id) }   # LEFT JOIN
query.right(:orders) { |j| j.orders.customer_id.eq(j.customers.id) }  # RIGHT JOIN
```

`join(:table)`, `left(:table)` and `right(:table)` without a block infer the `ON` clause from a foreign key.

On models, declared associations use `joins(:assoc)` and `left_joins(:assoc)`; see [Write Typed Queries](typed-where-dsl.md).

## Dialect notes

- **MySQL has no FULL JOIN.** Generating SQL raises `CQL::DialectError` ("MySQL does not support FULL JOIN"). Combine a `left` and a `right` query with `union` instead; see [Combine Queries with Set Operations](set-operations.md):

  ```crystal
  left  = AppDB.query.from(:customers).select(customers: [:name])
            .left(:orders) { |j| j.orders.customer_id.eq(j.customers.id) }
  right = AppDB.query.from(:customers).select(customers: [:name])
            .right(:orders) { |j| j.orders.customer_id.eq(j.customers.id) }
  left.union(right)
  ```

  (This combination is not covered by a spec.)
- PostgreSQL and CockroachDB support both joins.
- CQL generates `FULL JOIN` for SQLite without a version check; your SQLite library has to be new enough (SQLite itself added FULL JOIN in 3.39).

## Related

- [Build Complex Queries](complex-queries.md)
- [Combine Queries with Set Operations](set-operations.md)
- [Write Typed Queries](typed-where-dsl.md)
