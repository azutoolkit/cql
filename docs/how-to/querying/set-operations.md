# Combine Queries with Set Operations

This guide shows you how to combine queries with `UNION`, `UNION ALL`, `INTERSECT` and `EXCEPT`.

Set operations are defined for `CQL::Query` and for the result of another set operation (`CQL::CompoundQuery`). Both are executable like any query.

## Build a combined query

```crystal
customers = AppDB.query.from(:customers).select(:name)
users     = AppDB.query.from(:users).select(:name)

customers.union(users)
customers.union_all(users)
customers.intersect(users)
customers.except(users)
```

```crystal
customers.union(users).to_sql
# => {"SELECT customers.name FROM customers UNION SELECT users.name FROM users", []}
```

| Method | SQL | Duplicates |
| --- | --- | --- |
| `union` | `UNION` | removed |
| `union_all` | `UNION ALL` | kept |
| `intersect` | `INTERSECT` | rows in both |
| `except` | `EXCEPT` | rows in the left only |

Column names of the result come from the first (left) query, as in SQL.

## Run it

```crystal
user_names  = AppDB.query.from(:users).select(:name)
owner_names = AppDB.query.from(:profile_owners).select(:name)

user_names.union(owner_names).all(as: String)
owner_names.except(user_names).all(as: String)
owner_names.intersect(user_names).all(as: String)
```

`all`, `get`, `each`, `to_sql` and `explain` behave as they do on a query.

## Parameters stay bound, in order

Values from both sides are bound as parameters, left first:

```crystal
customers.where(city: "Tulum").union(users.where(email: "a@example.com")).to_sql
# params: ["Tulum", "a@example.com"]
```

On PostgreSQL the placeholders keep counting across operands: `customers.city = $1 UNION ... users.email = $2`.

## Chain operations

Chains read left to right. The already combined left side is grouped so its meaning is kept:

```crystal
chain = customers.union(users).intersect(users)
```

PostgreSQL and MySQL parenthesise the grouped operand:

```sql
(SELECT customers.name FROM customers UNION SELECT users.name FROM users) INTERSECT SELECT ...
```

SQLite does not accept parentheses around compound members, so it wraps the operand as a derived table instead:

```sql
SELECT * FROM (SELECT customers.name FROM customers UNION SELECT users.name FROM users) INTERSECT SELECT ...
```

## ORDER BY and LIMIT on an operand

An operand with its own `order` or `limit` keeps those clauses; they apply to that operand, not to the combined result. CQL groups such an operand automatically:

```crystal
customers.order(name: :asc).limit(1).union(users).to_sql(for: CQL::Adapter::Postgres)
# => {"(SELECT customers.name FROM customers ORDER BY customers.name ASC LIMIT $1) UNION SELECT users.name FROM users", [1]}
```

On SQLite the grouped operand becomes `SELECT * FROM (... LIMIT ?)`.

Ordering or limiting the combined result itself is not supported yet. Sort or slice the rows in Crystal, or apply `order`/`limit` to the operands.

## Operands with CTEs

An operand that declares CTEs is grouped too (`UNION (WITH t AS (...) ...)` on PostgreSQL). See [Use CTEs and Recursive CTEs](ctes.md).

## Dialect notes

- MySQL needs 8.0.31+ for `INTERSECT` and `EXCEPT`.
- SQLite wraps grouped operands in `SELECT * FROM (...)`; PostgreSQL, CockroachDB and MySQL use parentheses.
- Render for another dialect without a connection with `to_sql(for: CQL::Adapter::Postgres)`; see [Inspect Queries with to_sql and explain](explain-and-to-sql.md).

## Related

- [Use CTEs and Recursive CTEs](ctes.md)
- [Build Complex Queries](complex-queries.md)
- [Inspect Queries with to_sql and explain](explain-and-to-sql.md)
