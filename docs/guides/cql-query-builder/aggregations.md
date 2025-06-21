---
description: >-
  Guide to aggregations in CQL Query Builder.
---

# Aggregations

This guide covers all built-in aggregation functions, group by, having, custom expressions, and performance considerations in CQL Query Builder.

## Overview

Aggregations allow you to compute summary values (such as counts, sums, averages, minimums, and maximums) over sets of records. CQL Query Builder provides a fluent, type-safe interface for building aggregation queries.

## Built-in Aggregation Functions

### Count

```crystal
query.from(:users).count.get(Int64) # Total number of users
query.from(:users).where(active: true).count.get(Int64) # Active users
```

### Sum

```crystal
query.from(:orders).sum(:total).get(Float64) # Total sales
```

### Average

```crystal
query.from(:users).avg(:age).get(Float64) # Average age
```

### Minimum

```crystal
query.from(:users).min(:age).get(Int32) # Youngest user
```

### Maximum

```crystal
query.from(:users).max(:age).get(Int32) # Oldest user
```

## Group By

Group results by one or more columns:

```crystal
query.from(:users).group(:role).count.get(Int64) # Count by role
query.from(:orders).group(:customer_id).sum(:total).all({customer_id: Int64, total: Float64})
```

## Having

Filter groups using HAVING:

```crystal
query.from(:users)
     .group(:role)
     .having { |h| h.gt(:count, 5) }
     .count.get(Int64)
```

## Custom Aggregation Expressions

You can build custom aggregation expressions using blocks:

```crystal
query.from(:orders)
     .group(:customer_id)
     .having { |h| h.sum(:total).gt(1000) }
     .sum(:total)
     .all({customer_id: Int64, total: Float64})
```

## Multiple Aggregations

You can select multiple aggregations in a single query:

```crystal
query.from(:orders)
     .group(:customer_id)
     .select(:customer_id)
     .select(total_orders: query.count(:id), total_sales: query.sum(:total))
     .all({customer_id: Int64, total_orders: Int64, total_sales: Float64})
```

## Distinct Aggregations

Count or aggregate distinct values:

```crystal
query.from(:users).count(:role, distinct: true).get(Int64)
```

## Performance Considerations

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
     .all({status: String, order_count: Int64, total_sales: Float64})
```

This guide provides a comprehensive overview of aggregations in CQL Query Builder. Use it alongside the API reference for method details and the Active Record guides for model-level reporting.
