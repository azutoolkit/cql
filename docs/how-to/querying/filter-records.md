# Filter with Where Clauses

This guide shows you how to filter records using where clauses.

## Basic Where

```crystal
active_users = User.where(active: true).all
```

## Multiple Conditions

```crystal
users = User.where(active: true, role: "admin").all
```

## Chain Where Clauses

```crystal
users = User
  .where(active: true)
  .where(role: "admin")
  .all
```

## Comparison Operators

Use blocks for comparisons. Inside the block, bare names are the model's typed columns, so `age > "old"` or an unknown column fails to compile:

```crystal
# Greater than
adults = User.where { age > 18 }.all

# Less than
young = User.where { age < 30 }.all

# Greater than or equal
User.where { age >= 18 }.all

# Less than or equal
User.where { age <= 65 }.all

# Not equal
User.where { status != "banned" }.all
```

## Range Queries

```crystal
# Between, from a hash condition
User.where(age: 18..65).all

# IN, from a hash condition (Array value)
User.where(role: ["admin", "moderator"]).all

# Between, from a block
User.where { age.between(18, 65) }.all

# In a set, from a block
User.where { role.in(["admin", "moderator"]) }.all
```

## Date Comparisons

```crystal
# Records from last week
User.where { created_at > 1.week.ago }.all

# Records from specific date
User.where { created_at > Time.utc(2024, 1, 1) }.all

# Records between dates
Post.where { published_at.between(start_date, end_date) }.all
```

## NULL Checks

```crystal
# Where null: a nil value emits `deleted_at IS NULL`
User.where(deleted_at: nil).all

# Where not null (use block)
User.where { deleted_at != nil }.all

# Equivalent null helpers
User.where { deleted_at.null }.all
User.where { deleted_at.not_null }.all
```

A schema query's block, which names columns through their table, works the same way: `Northwind.query.from(:customers).where { customers.city == city }` emits `customers.city IS NULL` when `city` is nil and binds the value otherwise, and `!= nil` emits `IS NOT NULL`. So do `eq(nil)` and `neq(nil)`, and the blocks of `update.where { }` and `delete.where { }`.

A nil value in `where`, `find_by`, `exists?`, `delete_by!` or `update_by`, or compared with `==` in a `where` block, matches the rows whose column is NULL, so reject a nil that comes from untrusted input before using it as a filter. An index on the column serves `IS NULL`; a partial index declared `WHERE col IS NOT NULL` does not.

## LIKE Queries

```crystal
# Contains
User.where { name.like("%john%") }.all

# Starts with
User.where { email.like("admin%") }.all

# Ends with
User.where { email.like("%@example.com") }.all

# Case-insensitive
User.where { name.ilike("%john%") }.all

# Without a block
User.where_like(:name, "%john%").all
```

## OR Conditions

```crystal
User.where { (role == "admin") | (role == "moderator") }.all
```

## AND Conditions

```crystal
User.where { (age > 18) & (active == true) }.all
```

## Combine Hash and Block

```crystal
User.where(active: true).where { age > 18 }.all
```

## NOT Conditions

```crystal
User.where { (status == "banned").not }.all
User.where { role.not_in(["admin", "moderator"]) }.all
```

## Raw SQL Fragments

When the typed DSL is not enough, add a fragment with bound values (`?` positional, `:name` named):

```crystal
User.where("lower(email) = ? AND age > :age", "john@example.com", age: 18).all
```

## Order Results

```crystal
User.where(active: true)
    .order(created_at: :desc)
    .all
```

## Limit Results

```crystal
User.where(active: true)
    .limit(10)
    .all
```

## Count Results

```crystal
count = User.where(active: true).count
puts "Active users: #{count}"
```

## Verify Filtering Works

```crystal
User.create!(name: "John", email: "john@example.com", age: 25, active: true)
User.create!(name: "Jane", email: "jane@example.com", age: 30, active: false)

User.where(active: true).count  # => 1
User.where { age > 20 }.count   # => 2
```

## Related

- [Typed Where DSL](typed-where-dsl.md)
- [Find Records](find-records.md)
- [Build Complex Queries](complex-queries.md)
- [Create Query Scopes](scopes.md)
