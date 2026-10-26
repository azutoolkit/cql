# Use FULL and CROSS Joins

Add `FULL JOIN` and `CROSS JOIN` clauses to a `CQL::Query` (`AppDB.query`) with `full` and `cross`. `QueryBuilder` has neither; reach them with `with_query`.

## Keep Unmatched Rows from Both Sides

`full(table) { |j| ... }` matches on the condition the block returns; `j` reaches every table in the query:

```crystal
AppDB.query.from(:customers)
  .full(:orders) { |j| j.orders.customer_id.eq(j.customers.id) }
  .select(customers: [:name], orders: [:total]) # select after the join, once orders is known
  .all(as: {String?, Float64?})
# SELECT customers.name, orders.total FROM customers FULL JOIN orders ON orders.customer_id = customers.id
# => [{"Ada", 120.0}, {"Ada", 30.0}, {"Grace", 20.0}, {"Linus", nil}, {nil, 9.0}]
```

A customer without orders (`Linus`) and an order without a customer (`9.0`) both appear, with `nil` for the missing side.

## Pair Every Row with Every Row

`cross(table)` takes no block and renders no `ON`:

```crystal
AppDB.query.from(:customers)
  .cross(:sizes)
  .select(customers: [:name], sizes: [:label])
  .all(as: {String, String}) # 3 customers x 2 sizes => 6 rows
# SELECT customers.name, sizes.label FROM customers CROSS JOIN sizes
```

## Use the Other Join Types

```crystal
AppDB.query.from(:customers).join(:orders) { |j| j.orders.customer_id.eq(j.customers.id) }  # INNER JOIN orders ON ...
AppDB.query.from(:customers).left(:orders) { |j| j.orders.customer_id.eq(j.customers.id) }  # LEFT JOIN orders ON ...
AppDB.query.from(:customers).right(:orders) { |j| j.orders.customer_id.eq(j.customers.id) } # RIGHT JOIN orders ON ...

# Without a block, ON comes from a foreign key the schema declares on orders:
#   foreign_key [:customer_id], references: :customers, references_columns: [:id]
AppDB.query.from(:customers).left(:orders).select(customers: [:name], orders: [:id])
# SELECT customers.name, orders.id FROM customers LEFT JOIN orders ON orders.customer_id = customers.id
AppDB.query.from(customers: :c).right(orders: :o) # aliases: ... FROM customers AS c RIGHT JOIN orders AS o ON o.customer_id = c.id
# No such foreign key: ArgumentError "Could not find a foreign key relationship between ..."
```

On models, join declared associations with `User.query.joins(:posts)` and `left_joins`; see [Write Typed Queries](typed-where-dsl.md).

## Emulate FULL JOIN on MySQL

MySQL has no `FULL JOIN`: generating its SQL raises `CQL::DialectError` ("MySQL does not support FULL JOIN"). Combine a `left` and a `right` join with `union`, which also removes duplicate rows:

```crystal
left_rows = AppDB.query.from(:customers)
  .left(:orders) { |j| j.orders.customer_id.eq(j.customers.id) }
  .select(customers: [:name], orders: [:total])
right_rows = AppDB.query.from(:customers)
  .right(:orders) { |j| j.orders.customer_id.eq(j.customers.id) }
  .select(customers: [:name], orders: [:total])

left_rows.union(right_rows).all(as: {String?, Float64?}) # the five rows of the FULL JOIN above
# SELECT customers.name, orders.total FROM customers LEFT JOIN orders ON ...
# UNION SELECT customers.name, orders.total FROM customers RIGHT JOIN orders ON ...
```

{% hint style="info" %}
PostgreSQL and CockroachDB support both joins. CQL renders `FULL JOIN` and `RIGHT JOIN` for SQLite without a version check; SQLite itself added them in 3.39.
{% endhint %}

## See Also

- [Build Complex Queries](complex-queries.md)
- [Combine Queries with Set Operations](set-operations.md)
- [Write Typed Queries](typed-where-dsl.md)
- [Use CTEs and Recursive CTEs](ctes.md)
