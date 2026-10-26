# Use Raw SQL Fragments Safely

This guide shows you how to write a piece of SQL by hand inside a query (`lower(name) = ?`, a database function, a JSON operator) while every value is still bound as a parameter.

## Add a fragment to where

```crystal
AppDB.query.from(:customers).select(:name)
  .where("lower(customers.name) = ? AND customers.balance > ?", "ada", 10)
  .to_sql
```

```crystal
# => {"SELECT customers.name FROM customers WHERE lower(customers.name) = ? AND customers.balance > ?",
#     ["ada", 10]}
```

The values travel in the parameter array, never in the SQL text. A hostile value stays a value:

```crystal
query.where("customers.name = ?", "x'; DROP TABLE customers; --")
# SQL text unchanged, params: ["x'; DROP TABLE customers; --"]
```

**The fragment itself must be a literal that you wrote.** Never build it from user input with `#{}` or `+`; pass user input as a bound value.

## Placeholders

### Positional `?`

Values are matched in order. An array expands to a comma-separated list, which is what `IN (?)` needs:

```crystal
query.where("customers.id IN (?)", [1, 2, 3])
# WHERE customers.id IN (?, ?, ?)   params: [1, 2, 3]
```

### Named `:name`

Pass named arguments. A name used twice is bound twice:

```crystal
query.where("balance BETWEEN :min AND :max OR credit > :min", min: 5, max: 9)
# WHERE balance BETWEEN ? AND ? OR credit > ?   params: [5, 9, 5]

query.where("id IN (:ids)", ids: [4, 5])
# WHERE id IN (?, ?)
```

Do not mix `?` and `:name` in one fragment.

### What is left alone

- `??` is a literal `?` (for PostgreSQL's jsonb operator): `where("data ?? 'key' AND id = ?", 1)` renders `data ? 'key' AND id = $1` on PostgreSQL.
- `::` is a cast: `where("customers.id::text = :id", id: "7")`.
- Text inside quoted strings, quoted identifiers and comments (`-- ...`, `/* ... */`) is never treated as a placeholder.

## Combine with other conditions

Fragments are ANDed with the rest of the `where` and numbered correctly on PostgreSQL:

```crystal
query.where(city: "Tulum").where("balance > ? AND balance < ?", 1, 9).to_sql(Expression::Generator.new(CQL::Adapter::Postgres))
# ... WHERE (customers.city = $1) AND (balance > $2 AND balance < $3)
```

## Use a fragment inside a where block

Inside `where { }`, `raw(...)` builds a fragment you can combine with `&`, `|` and the typed conditions:

```crystal
query.where { raw("lower(customers.name) = ?", "ada") | (customers.id == 1) }
# WHERE (lower(customers.name) = ?) OR (customers.id = ?)   params: ["ada", 1]
```

Outside a block, `CQL.raw(sql, *positional, **named)` returns the same condition, and `where(condition)` accepts it:

```crystal
query.where(CQL.raw("balance > :b", b: 3))
```

## Models, Update and Delete

The same string form works on model queries, query builders, `Update` and `Delete`:

```crystal
User.where("age > ?", 18).all
User.query.where("age > :a", a: 18).where("name = ?", "x")
User.where("name IN (?)", ["ada", "grace"]).all

AppDB.update.table(:customers).set(city: "X").where("balance > :b", b: 3)
AppDB.delete.from(:customers).where("balance > ?", 3)
```

Update parameters are ordered `SET` values first, then the fragment's (`["X", 3]`).

## NULL

In a raw fragment `nil` binds as `NULL`, so `name = ?` never matches it (the hash form `where(city: nil)` emits `IS NULL` for you). Use the null-safe comparison:

```crystal
query.where("customers.city IS NOT DISTINCT FROM ?", nil)
```

## Mistakes are errors, not silent

| Mistake | Result |
| --- | --- |
| Too few or too many positional values | `ArgumentError` "expects 2 value(s), got 1" |
| Missing or unused named value | `ArgumentError` "Missing value for :max" / "Unused named value(s): :extra" |
| Named values for a fragment without `:name` placeholders, or positional values for a `:name` fragment | `ArgumentError` naming the style mismatch |
| Mixing `?` and `:name` | `ArgumentError` |
| An empty array | `ArgumentError` ("Cannot bind an empty array"); guard the condition instead |
| A NUL byte in the fragment | `ArgumentError` |
| A value type that cannot be a parameter | compile-time error listing the bindable types |

## Limits

- Only `where` accepts fragments (not `having`).
- PostgreSQL `$$...$$` strings, MySQL backslash escapes and array slices such as `a[1:n]` are not understood by the placeholder scanner.
- A column literally named `sql` still works with `where(sql: "abc")`.

## Related

- [Filter with Where Clauses](filter-records.md)
- [Write Typed Queries](typed-where-dsl.md)
- [Query JSON and Geospatial Columns](json-and-geo-predicates.md)
- [The query DSL: before and after](../../explanation/dsl-before-after.md)
