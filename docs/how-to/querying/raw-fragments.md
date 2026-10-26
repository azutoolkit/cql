# Use Raw SQL Fragments Safely

Write a piece of SQL by hand inside a query (`lower(name) = ?`, a database function, a JSON operator) while every value stays a bound parameter.

## Add a Fragment to where

```crystal
def customer_names # a fresh query for each example
  AppDB.query.from(:customers).select(:name)
end

customer_names.where("lower(customers.name) = ? AND customers.balance > ?", "ada", 10).to_sql
# => {"SELECT customers.name FROM customers WHERE lower(customers.name) = ? AND customers.balance > ?", ["ada", 10]}

# A hostile value stays a value: the SQL text is unchanged
customer_names.where("customers.name = ?", "x'; DROP TABLE customers; --")
# ... WHERE customers.name = ?   params: ["x'; DROP TABLE customers; --"]
```

{% hint style="danger" %}
The fragment itself must be a literal you wrote. Never build it from user input with `#{}` or `+`; pass user input as a bound value.
{% endhint %}

## Bind Values

```crystal
# Positional ?: values in order; an Array expands for IN (?)
customer_names.where("customers.id IN (?)", [1, 2, 3])
# ... WHERE customers.id IN (?, ?, ?)   params: [1, 2, 3]

# Named :name: a name used twice is bound twice
customer_names.where("balance BETWEEN :min AND :max OR balance > :min", min: 5, max: 9)
# ... WHERE balance BETWEEN ? AND ? OR balance > ?   params: [5, 9, 5]
customer_names.where("id IN (:ids)", ids: [4, 5])     # ... WHERE id IN (?, ?)

# Left alone: ?? is a literal ? (PostgreSQL jsonb), :: is a cast,
# and quoted strings, quoted identifiers and comments are never placeholders
customer_names.where("data ?? 'key' AND id = ?", 1)   # PostgreSQL: ... WHERE data ? 'key' AND id = $1
customer_names.where("customers.id::text = :id", id: "7")
customer_names.where("name = 'what? :not_a_bind' AND id = ? -- really? :x", 1) # params: [1]
```

## Combine with Other Conditions

```crystal
# Fragments are ANDed with the rest and numbered in order on PostgreSQL
customer_names.where(city: "Tulum").where("balance > ? AND balance < ?", 1, 9).to_sql(for: CQL::Adapter::Postgres)
# ... WHERE (customers.city = $1) AND (balance > $2 AND balance < $3)

# Inside where { }, raw builds a condition for & and | (on a model's typed block, write CQL.raw)
customer_names.where { raw("lower(customers.name) = ?", "ada") | (customers.id == 1) }
# ... WHERE (lower(customers.name) = ?) OR (customers.id = ?)   params: ["ada", 1]

customer_names.where(CQL.raw("balance > :b", b: 3))  # CQL.raw(sql, *positional, **named) outside a block
```

## Use Fragments on Models, Update and Delete

```crystal
User.where("age > ?", 18).all
User.query.where("age > :a", a: 18).where("name = ?", "x")  # ... WHERE (age > ?) AND (name = ?)
User.where("name IN (?)", ["ada", "grace"]).all

AppDB.update.table(:customers).set(city: "X").where("balance > :b", b: 3) # params: ["X", 3], SET first
AppDB.delete.from(:customers).where("balance > ?", 3)
```

## Match NULL

```crystal
customer_names.where("customers.city = ?", nil)                    # binds NULL, so it never matches
customer_names.where("customers.city IS NOT DISTINCT FROM ?", nil) # null-safe; the hash form where(city: nil) emits IS NULL
```

## Avoid These Errors

```crystal
customer_names.where("a = ? AND b = ?", 1)            # ArgumentError: Fragment expects 2 value(s), got 1
customer_names.where("a < :max", min: 1)              # ArgumentError: Missing value for :max
customer_names.where("a < :max", max: 1, extra: 2)    # ArgumentError: Unused named value(s): :extra
customer_names.where("a = 1", tenant: 5)              # ArgumentError: Fragment has no :name placeholders but got named value(s): :tenant
customer_names.where("a = :x", 5, x: 1)               # ArgumentError: Fragment uses :name placeholders but got 1 positional value(s)
customer_names.where("a = ? AND b = :b", 1, b: 2)     # ArgumentError: Cannot mix ? and :name placeholders in one fragment
customer_names.where("id IN (?)", [] of Int32)        # ArgumentError: Cannot bind an empty array; guard the condition instead
customer_names.where("a = ?\0", 1)                    # ArgumentError: A SQL fragment cannot contain a NUL byte
# A value type that cannot be a parameter fails to compile
```

{% hint style="warning" %}
Only `where` accepts fragments, not `having`. The placeholder scanner does not understand PostgreSQL `$$...$$` strings, MySQL backslash escapes or array slices such as `a[1:n]`.
{% endhint %}

A column literally named `sql` still filters with `where(sql: "abc")`.

## See Also

- [Filter with Where Clauses](filter-records.md)
- [Write Typed Queries](typed-where-dsl.md)
- [Query JSON and Geospatial Columns](json-and-geo-predicates.md)
- [The query DSL: before and after](../../explanation/dsl-before-after.md)
