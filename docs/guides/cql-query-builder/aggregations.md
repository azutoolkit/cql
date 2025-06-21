---
description: >-
  Guide to aggregations in CQL Query Builder.
---

# Aggregations

This guide covers all built-in aggregation functions, group by, having, and best practices in CQL Query Builder and Active Record style.

## Overview

Aggregations allow you to compute summary values (such as counts, sums, averages, minimums, and maximums) over sets of records. CQL Query Builder provides a fluent, type-safe interface for building aggregation queries.

## Built-in Aggregation Functions

### Count

```crystal
# Query Builder
query.from(:users).count.get(Int64) # Total number of users
query.from(:users).where(active: true).count.get(Int64) # Active users

# Active Record
User.count # All users
User.where(active: true).count # Active users
```

### Sum

```crystal
# Query Builder
query.from(:orders).sum(:total).get(Int64) # Total sales

# Active Record
User.sum(:age) # Total age of all users
Order.sum(:total) # Total sales
Order.where(status: "completed").sum(:total)
```

### Average

```crystal
# Query Builder
query.from(:users).avg(:age).get(Float64) # Average age

# Active Record
User.average(:age) # Average age of all users
User.where(active: true).average(:age)
```

### Minimum

```crystal
# Query Builder
query.from(:users).min(:age).get(Int32) # Youngest user

# Active Record
User.minimum(:age) # Youngest user
User.where(active: true).minimum(:age)
```

### Maximum

```crystal
# Query Builder
query.from(:users).max(:age).get(Int32) # Oldest user

# Active Record
User.maximum(:age) # Oldest user
User.where(active: true).maximum(:age)
```

## Group By

Group results by one or more columns:

```crystal
# Query Builder
query.from(:users).group(:role).count.get(Int64) # Count by role
query.from(:orders).group(:customer_id).sum(:total).all({customer_id: Int64, total: Int64})

# Active Record
User.group(:role).count # Count by role
Order.group(:customer_id).sum(:total)
```

## Having

Filter groups using HAVING. The block receives a builder for aggregate functions:

```crystal
# Query Builder
query.from(:users)
     .group(:role)
     .having { |h| h.count(:id) > 5 }
     .count.get(Int64)

# With multiple aggregates
query.from(:orders)
     .group(:customer_id)
     .having { |h| h.sum(:total) > 1000 }
     .sum(:total)
     .all({customer_id: Int64, total: Int64})
```

## Multiple Aggregations

You can select multiple aggregations in a single query:

```crystal
query.from(:orders)
     .group(:customer_id)
     .select(:customer_id)
     .select(order_count: query.count(:id), total_sales: query.sum(:total))
     .all({customer_id: Int64, order_count: Int64, total_sales: Int64})
```

## Distinct Values

To get distinct values for a column:

```crystal
# Query Builder
query.from(:users).select(:role).distinct.all(as: String)

# Active Record
User.distinct(:role)
```

## Aggregation with Pluck

Extract values directly:

```crystal
# Active Record
names = User.pluck(:name, as: String)
ages = User.where(active: true).pluck(:age, as: Int32)
results = User.pluck(:name, :age, as: {String, Int32})
```

## Best Practices

- Use indexes on columns used in GROUP BY and WHERE for faster aggregations
- Limit the number of groups for large datasets
- Use HAVING only for filtering on aggregated values
- Avoid selecting unnecessary columns in aggregation queries

## Example: Aggregation Report

```crystal
query.from(:orders)
     .group(:status)
     .select(:status)
     .select(order_count: query.count(:id), total_sales: query.sum(:total))
     .all({status: String, order_count: Int64, total_sales: Int64})
```

This guide provides a comprehensive overview of aggregations in CQL Query Builder. Use it alongside the API reference for method details and the Active Record guides for model-level reporting.
