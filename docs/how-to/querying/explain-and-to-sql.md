---
description: "See the SQL and parameters a query will run, render it for another database, and ask the database for its execution plan."
---

# Inspect Queries with to_sql and explain

## See the SQL and Its Parameters

`to_sql` renders for the schema's dialect and executes nothing. Values are never in the SQL text, only in the parameters:

```crystal
query = AppDB.query.from(:customers).select(:name).where(city: "Tulum").limit(5)

sql, params = query.to_sql
# sql:    "SELECT customers.name FROM customers WHERE customers.city = ? LIMIT ?"
# params: ["Tulum", 5]
```

`QueryBuilder` (`User.query`, `User.where`) has two forms, plus the underlying `CQL::Query`:

```crystal
User.where(name: "Ada").to_sql              # "SELECT users.id, ... FROM users WHERE users.name = ?" (String)
User.where(name: "Ada").to_sql_with_params  # {"SELECT users.id, ...", ["Ada"]}
User.where(name: "Ada").query.to_sql(for: CQL::Adapter::Postgres) # {"... WHERE users.name = $1", ["Ada"]}
```

## Render for Another Dialect

`to_sql(for: adapter)` needs no connection to that database. It works on `CQL::Query` and on set operations (`CQL::CompoundQuery`):

```crystal
query.to_sql(for: CQL::Adapter::Postgres)
# => {"SELECT customers.name FROM customers WHERE customers.city = $1 LIMIT $2", ["Tulum", 5]}
query.to_sql(for: CQL::Adapter::MySql)       # ... WHERE customers.city = ? LIMIT ?
query.to_sql(for: CQL::Adapter::CockroachDB) # ... WHERE customers.city = $1 LIMIT $2
query.to_sql(for: CQL::Adapter::SQLite)      # the same as to_sql on this SQLite schema

query.union(AppDB.query.from(:users).select(:name)).to_sql(for: CQL::Adapter::Postgres)
# => {"(SELECT customers.name FROM customers WHERE customers.city = $1 LIMIT $2) UNION SELECT users.name FROM users", ...}

# The schema's quote_identifiers setting carries over
# (QuotedDB = CQL::Schema.define(:quoted_db, ..., quote_identifiers: true) with a table :order)
QuotedDB.query.from(:order).select(:id).to_sql(for: CQL::Adapter::Postgres) # {"SELECT \"order\".\"id\" FROM \"order\"", []}
```

`Insert`, `Update` and `Delete` take a generator instead of `for:`:

```crystal
AppDB.insert.into(:accounts).values(email: "a@x.io", name: "Ada")
  .on_conflict(:email).do_update(:name)
  .to_sql(Expression::Generator.new(CQL::Adapter::Postgres))
# => {"INSERT INTO accounts (email, name) VALUES ($1, $2) ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name", [...]}

AppDB.update.table(:customers).set(city: "X").where(id: 1).to_sql(Expression::Generator.new(CQL::Adapter::Postgres))
# => {"UPDATE customers SET city = $1 WHERE customers.id = $2", ["X", 1]}
AppDB.delete.from(:customers).where(id: 1).to_sql(Expression::Generator.new(CQL::Adapter::MySql))
# => {"DELETE FROM customers WHERE customers.id = ?", [1]}
```

Features a dialect lacks raise `CQL::DialectError` while its SQL is generated, such as `lock` on SQLite or `full` on MySQL, so rendering with `for:` finds them before production does.

## Ask the Database for Its Plan

`explain` runs the database's `EXPLAIN` with the parameters bound and returns the plan, one line per plan row:

```crystal
puts AppDB.query.from(:users).select(:name).where(name: "ada").explain

names = AppDB.query.from(:users).select(:name)
puts names.union(names).explain            # set operations too
puts User.where(name: "Ada").query.explain # QueryBuilder: through .query

query.explain(analyze: true) # EXPLAIN ANALYZE: runs the statement and times it
```

{% tabs %}
{% tab title="SQLite" %}
`explain` runs `EXPLAIN QUERY PLAN` and returns each plan row's detail column:

```text
SCAN users
```

`analyze: true` raises `CQL::DialectError` ("SQLite does not support EXPLAIN ANALYZE").
{% endtab %}

{% tab title="PostgreSQL, CockroachDB" %}
`explain` runs `EXPLAIN`, or `EXPLAIN ANALYZE` with `analyze: true`, and returns the plan text, one line per plan line, such as `Seq Scan on users ...`.
{% endtab %}

{% tab title="MySQL" %}
`explain` runs `EXPLAIN` and joins each plan row's columns with `" | "`. `analyze: true` runs `EXPLAIN ANALYZE`, which needs MySQL 8.0.18+.
{% endtab %}
{% endtabs %}

<details>

<summary>SQLite plan of names.union(names)</summary>

```text
COMPOUND QUERY
LEFT-MOST SUBQUERY
SCAN users
UNION USING TEMP B-TREE
SCAN users
```

</details>

{% hint style="warning" %}
`analyze: true` executes the statement, so never point it at one whose side effects you do not want.
{% endhint %}

{% hint style="info" %}
Plans are diagnostics: `explain` is not cached and not counted by the performance monitor. Telemetry reports it with the operation `:explain` (see [Telemetry](../observability/telemetry.md)). Plan text differs per database, so do not parse it in application code.
{% endhint %}

## See Also

- [Optimize Queries](../performance/optimize-queries.md)
- [Telemetry](../observability/telemetry.md)
- [Combine Queries with Set Operations](../advanced-sql/set-operations.md)
- [Upsert Records](../data-operations/upsert.md)
- [Lock Rows](../data-operations/row-locking.md)
