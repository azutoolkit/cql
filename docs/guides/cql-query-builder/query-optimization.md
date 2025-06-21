---
description: >-
  Guide to query optimization in CQL Query Builder.
---

# Query Optimization

This guide covers query caching, index usage, query analysis, profiling, and performance best practices in CQL Query Builder.

## Overview

Optimizing queries is essential for high-performance applications. CQL Query Builder provides features and patterns to help you write efficient, scalable queries.

## Query Caching

CQL supports query result caching to avoid repeated database hits for identical queries.

```crystal
users = User.query.cache(true).where(active: true).all
```

- Use `.cache(true)` to enable caching for a query
- Use `.clear_cache` to clear cached results
- Use `.cache_stats` to inspect cache usage

## Index Usage

Indexes speed up queries on large tables. For best performance:

- Add indexes to columns used in WHERE, JOIN, and ORDER BY clauses
- Use composite indexes for multi-column filters
- Regularly analyze and vacuum your database (for PostgreSQL/SQLite)

```sql
CREATE INDEX idx_users_active ON users(active);
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
```

## Query Analysis

You can inspect the generated SQL and parameters for any query:

```crystal
sql, params = query.from(:users).where(active: true).to_sql
puts "SQL: #{sql}"
puts "Params: #{params}"
```

Use your database's EXPLAIN command to analyze query plans:

```crystal
sql, params = query.from(:users).where(active: true).to_sql
explain_sql = "EXPLAIN #{sql}"
# Run explain_sql in your DB console
```

## Profiling and Monitoring

- Use database logs to monitor slow queries
- Profile query execution time in your application:

```crystal
start = Time.monotonic
users = query.from(:users).all(User)
duration = Time.monotonic - start
puts "Query took #{duration.total_milliseconds}ms"
```

- Use connection pool statistics to monitor DB load

## Best Practices

- Select only the columns you need
- Use LIMIT/OFFSET for pagination
- Avoid N+1 queries by using eager loading (`includes`)
- Batch updates and inserts when possible
- Regularly review and optimize indexes
- Monitor query performance in production

## Example: Optimized Query

```crystal
users = User.select(:id, :name)
            .where(active: true)
            .order(:created_at, :desc)
            .limit(100)
            .cache(true)
            .all
```

This guide provides a comprehensive overview of query optimization in CQL Query Builder. Use it alongside the API reference for method details and the Active Record guides for application-level performance.
