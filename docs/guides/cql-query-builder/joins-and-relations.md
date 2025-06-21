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
query.from(:users).join(:posts)
```

### Left Join

Returns all records from the left table and matched records from the right table (or NULL if no match).

```crystal
query.from(:users).left(:posts)
```

### Right Join

Returns all records from the right table and matched records from the left table (or NULL if no match).

```crystal
query.from(:users).right(:posts)
```

## Automatic Join Inference

CQL can automatically infer join conditions based on foreign key relationships defined in your schema.

```crystal
# If posts.user_id references users.id, this will join on posts.user_id = users.id
query.from(:users).join(:posts)
```

## Manual Join Specification

You can specify custom join conditions using a block:

```crystal
query.from(:users).join(:posts) do |j|
  j.on(:id, :user_id) # users.id = posts.user_id
end
```

You can also join with table aliases:

```crystal
query.from(users: :u, posts: :p).join(:posts) do |j|
  j.on(:id, :user_id)
end
```

## Table Aliasing

Table aliases help disambiguate columns and simplify complex queries.

```crystal
query.from(users: :u, posts: :p)
     .select(u: [:name], p: [:title])
     .join(:posts)
```

## Joining Multiple Tables

You can join multiple tables in a single query:

```crystal
query.from(:users)
     .join(:posts)
     .join(:comments)
     .where(posts: {published: true}, comments: {approved: true})
```

## Complex Join Conditions

You can build complex join conditions using blocks:

```crystal
query.from(:users).join(:posts) do |j|
  j.on(:id, :user_id)
  j.and(:active, true)
end
```

## Nested and Chained Joins

You can chain joins for deep relationships:

```crystal
query.from(:users)
     .join(:posts)
     .join(:comments)
     .where(comments: {approved: true})
```

## Best Practices

- Use automatic join inference for simple relationships
- Use manual join blocks for custom or complex conditions
- Use table aliases for clarity in multi-table queries
- Always specify join conditions to avoid Cartesian products
- Use eager loading (`includes`) in Active Record for N+1 prevention

## Example: Multi-table Join

```crystal
query.from(users: :u, posts: :p, comments: :c)
     .join(:posts) { |j| j.on(:id, :user_id) }
     .join(:comments) { |j| j.on(:id, :post_id) }
     .where(u: {active: true}, p: {published: true}, c: {approved: true})
     .select(u: [:name], p: [:title], c: [:body])
     .all
```

This guide provides a comprehensive overview of joins and relations in CQL Query Builder. Use it alongside the API reference for method details and the Active Record guides for model-level associations.
