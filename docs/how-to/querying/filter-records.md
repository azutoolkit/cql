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

Use blocks for comparisons:

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
# Between
User.where { age.between(18, 65) }.all

# In a set
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
# Where null
User.where(deleted_at: nil).all

# Where not null (use block)
User.where { deleted_at != nil }.all
```

## LIKE Queries

```crystal
# Contains
User.where { name.like("%john%") }.all

# Starts with
User.where { email.like("admin%") }.all

# Ends with
User.where { email.like("%@example.com") }.all
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

- [Find Records](find-records.md)
- [Build Complex Queries](complex-queries.md)
- [Create Query Scopes](scopes.md)
