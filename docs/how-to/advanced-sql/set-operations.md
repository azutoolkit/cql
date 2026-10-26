# Combine Queries with Set Operations

Combine two `CQL::Query` objects with `UNION`, `UNION ALL`, `INTERSECT` and `EXCEPT`; the result is a `CQL::CompoundQuery` that runs like a query.

## Combine Two Queries

```crystal
customer_names = AppDB.query.from(:customers).select(:name)
user_names = AppDB.query.from(:users).select(:name)

customer_names.union(user_names)     # UNION: duplicates removed
customer_names.union_all(user_names) # UNION ALL: duplicates kept
customer_names.intersect(user_names) # INTERSECT: rows in both
customer_names.except(user_names)    # EXCEPT: rows in the left query only

customer_names.union(user_names).to_sql
# => {"SELECT customers.name FROM customers UNION SELECT users.name FROM users", []}
```

The result's column names come from the left query, as in SQL.

## Run It

```crystal
user_names.union(customer_names).all(as: String)  # => ["Ada", "Grace", "Kim", "Linus"]
user_names.except(customer_names).all(as: String) # => ["Kim"]
customer_names.union(user_names).each(as: String) { |name| puts name }
customer_names.union(user_names).explain           # the database's plan, as on a query

# get reads one row; more than one raises DB::Error "more than one row"
AppDB.query.from(:customers).select(:name).where(name: "Ada")
  .union(AppDB.query.from(:users).select(:name).where(name: "Ada"))
  .get(as: String) # => "Ada"
```

## Keep Parameters Bound

Values from both sides are bound as parameters, left first; PostgreSQL numbering continues across operands:

```crystal
in_tulum = AppDB.query.from(:customers).select(:name).where(city: "Tulum")
ada = AppDB.query.from(:users).select(:name).where(email: "ada@example.com")

in_tulum.union(ada).to_sql(for: CQL::Adapter::Postgres)
# => {"SELECT customers.name FROM customers WHERE customers.city = $1
#      UNION SELECT users.name FROM users WHERE users.email = $2", ["Tulum", "ada@example.com"]}
```

## Chain Operations

Chains read left to right, and the combined left side is grouped so its meaning is kept:

```crystal
chain = customer_names.union(user_names).intersect(user_names)

chain.to_sql(for: CQL::Adapter::Postgres) # PostgreSQL, CockroachDB, MySQL: parentheses
# (SELECT customers.name FROM customers UNION SELECT users.name FROM users) INTERSECT SELECT users.name FROM users
chain.to_sql                               # SQLite: no parentheses allowed, so a derived table
# SELECT * FROM (SELECT customers.name FROM customers UNION SELECT users.name FROM users) INTERSECT SELECT ...
```

## Order or Limit an Operand

An operand keeps its own `order` and `limit`, which apply to that operand only; CQL groups it the same way:

```crystal
first_customer = AppDB.query.from(:customers).select(:name).order(name: :asc).limit(1)

first_customer.union(user_names).to_sql(for: CQL::Adapter::Postgres)
# => {"(SELECT customers.name FROM customers ORDER BY customers.name ASC LIMIT $1) UNION SELECT users.name FROM users", [1]}
first_customer.union(user_names).to_sql
# => {"SELECT * FROM (SELECT customers.name FROM customers ORDER BY customers.name ASC LIMIT ?) UNION ...", [1]}
```

`CompoundQuery` has no `order` or `limit` for the combined result: sort or slice the rows in Crystal, or order and limit the operands. An operand that declares CTEs is grouped too; see [Use CTEs and Recursive CTEs](ctes.md).

{% hint style="info" %}
MySQL needs 8.0.31+ for `INTERSECT` and `EXCEPT`. Render for another dialect without a connection with `to_sql(for: CQL::Adapter::MySql)`.
{% endhint %}

## See Also

- [Use CTEs and Recursive CTEs](ctes.md)
- [Use FULL and CROSS Joins](joins-full-cross.md)
- [Build Complex Queries](../querying/complex-queries.md)
- [Inspect Queries with to_sql and explain](../querying/explain-and-to-sql.md)
