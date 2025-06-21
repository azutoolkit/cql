---
description: >-
  Guide to joins and relations in CQL Query Builder.
---

# Joins and Relations

This guide covers all join types, automatic join inference, manual join specification, table aliasing, and complex join conditions in CQL Query Builder.

## Overview

Joins allow you to combine rows from two or more tables based on related columns. CQL Query Builder provides a fluent, type-safe interface for building joins and working with related data.

## Join Types

### Inner Join

Returns records with matching values in both tables.

```crystal
# CQL Query Builder
query.from(:users).join(:posts)

# Active Record
User.join(:posts)
```

### Left Join

Returns all records from the left table and matched records from the right table (or NULL if no match).

```crystal
# CQL Query Builder
query.from(:users).left(:posts)

# Active Record
User.left(:posts)
```

### Right Join

Returns all records from the right table and matched records from the left table (or NULL if no match).

```crystal
# CQL Query Builder
query.from(:users).right(:posts)

# Active Record
User.right(:posts)
```

## Automatic Join Inference

CQL can automatically infer join conditions based on foreign key relationships defined in your schema.

```crystal
# CQL Query Builder - If posts.user_id references users.id
query.from(:users).join(:posts)
# Generates: SELECT * FROM users INNER JOIN posts ON posts.user_id = users.id

# Active Record
User.join(:posts)
```

## Manual Join Specification

You can specify custom join conditions using a block:

```crystal
# CQL Query Builder
query.from(:users).join(:posts) do |j|
  j.users.id.eq(j.posts.user_id)
end

# Active Record
User.join(:posts) do |j|
  j.users.id.eq(j.posts.user_id)
end
```

## Table Aliasing

Table aliases help disambiguate columns and simplify complex queries.

### Using Hash Syntax

```crystal
# CQL Query Builder
query.from(:users).join(posts: :p)
# Generates: SELECT * FROM users INNER JOIN posts AS p ON p.user_id = users.id

# Active Record
User.join(posts: :p)
```

### Using Named Arguments

```crystal
# CQL Query Builder
query.from(:users).join(posts: :p, comments: :c)

# Active Record
User.join(posts: :p, comments: :c)
```

## Joining Multiple Tables

You can join multiple tables in a single query:

```crystal
# CQL Query Builder
query.from(:orders)
     .join(:customers) { |j| j.orders.customer_id.eq(j.customers.id) }
     .join(:users) { |j| j.customers.user_id.eq(j.users.id) }
     .select(orders: [:id], customers: [:name], users: [:email])

# Active Record
Order.join(:customers) { |j| j.orders.customer_id.eq(j.customers.id) }
     .join(:users) { |j| j.customers.user_id.eq(j.users.id) }
```

## Complex Join Conditions

You can build complex join conditions using blocks:

```crystal
# CQL Query Builder
query.from(:users).join(:address) do |j|
  j.users.id.eq(j.address.user_id) &
    j.users.name.eq("John") &
    j.users.email.eq("john@example.com")
end

# Active Record
User.join(:address) do |j|
  j.users.id.eq(j.address.user_id) &
    j.users.name.eq("John") &
    j.users.email.eq("john@example.com")
end
```

## Using Aliases in Joins

When you define aliases in the `from` clause, subsequent joins use those aliases:

```crystal
# CQL Query Builder
query.from(users: :u)
     .join(:address) # Uses u.id = address.user_id
     .select("u.name", address: [:street])

# Active Record
User.from(users: :u)
    .join(:address)
    .select("u.name", address: [:street])
```

## Chaining Joins with Other Methods

Joins can be chained with other query methods:

```crystal
# CQL Query Builder
query.from(:users)
     .join(:posts)
     .where { users.name.eq("John") | users.id.eq(1) }
     .select(users: [:name, :email], posts: [:title])

# Active Record
User.join(:posts)
    .where(name: "John")
    .order(name: :asc)
    .limit(10)
```

## Different Join Types with Aliases

```crystal
# Left Join with alias
query.from(:customers).left(orders: :ord)
# Generates: SELECT * FROM customers LEFT JOIN orders AS ord ON ord.customer_id = customers.id

# Right Join with alias
query.from(customers: :cust).right(orders: :ord)
# Generates: SELECT * FROM customers AS cust RIGHT JOIN orders AS ord ON ord.customer_id = cust.id
```

## Best Practices

- Use automatic join inference for simple relationships
- Use manual join blocks for custom or complex conditions
- Use table aliases for clarity in multi-table queries
- Always specify join conditions to avoid Cartesian products
- Use eager loading (`includes`) in Active Record for N+1 prevention

## Complete Examples

### Multi-table Join with Complex Conditions

```crystal
# CQL Query Builder
query.from(:orders)
     .join(:customers) { |j| j.orders.customer_id.eq(j.customers.id) }
     .join(:users) { |j| j.customers.user_id.eq(j.users.id) }
     .where { users.name.eq("John") }
     .select(orders: [:id], customers: [:name], users: [:email])
     .all

# Active Record
Order.join(:customers) { |j| j.orders.customer_id.eq(j.customers.id) }
     .join(:users) { |j| j.customers.user_id.eq(j.users.id) }
     .where(users: {name: "John"})
     .select(orders: [:id], customers: [:name], users: [:email])
     .all
```

### Join with Multiple Conditions

```crystal
# CQL Query Builder
query.from(:users)
     .join(:address) do |j|
       j.users.id.eq(j.address.user_id) &
       (j.users.name.eq("John") | j.users.id.eq(1))
     end
     .select(users: [:name, :email], address: [:street, :city])

# Active Record
User.join(:address) do |j|
  j.users.id.eq(j.address.user_id) &
  (j.users.name.eq("John") | j.users.id.eq(1))
end
.select(users: [:name, :email], address: [:street, :city])
```

This guide provides a comprehensive overview of joins and relations in CQL Query Builder. Use it alongside the API reference for method details and the Active Record guides for model-level associations.
