---
description: >-
  Comprehensive guide to CQL's Query Builder - a powerful, type-safe SQL query construction system for Crystal applications.
---

# CQL Query Builder

The CQL Query Builder provides a powerful, type-safe way to construct SQL queries in Crystal applications. It offers a fluent interface for building complex queries while maintaining compile-time safety and excellent performance.

## Overview

The `CQL::Query` class is the core component of the query builder system. It provides:

- **Type-safe query construction** with compile-time checks
- **Fluent interface** for building complex queries
- **Multiple database support** (PostgreSQL, MySQL, SQLite)
- **Automatic parameter binding** for security
- **Query optimization** and caching capabilities
- **Integration with Active Record** patterns

## Key Features

### 🔍 **Query Construction**

- Select specific columns or all columns
- Filter records with complex conditions
- Order and group results
- Limit and offset for pagination
- Distinct queries for unique results

### 🔗 **Joins and Relations**

- Automatic join inference based on foreign keys
- Manual join specification with custom conditions
- Left, right, and inner joins
- Table aliasing for complex queries

### 📊 **Aggregations**

- Count, sum, average, min, max operations
- Group by clauses with having conditions
- Complex aggregation expressions

### ⚡ **Performance**

- Query caching for repeated operations
- Lazy evaluation for optimal performance
- Connection pooling support
- Query optimization hints

## Quick Start

```crystal
require "cql"

# Create a schema and query
schema = CQL::Schema.new
query = CQL::Query.new(schema)

# Basic query
users = query.select(:name, :email)
             .from(:users)
             .where(active: true)
             .order(:created_at)
             .all(User)

# Complex query with joins
posts = query.select(users: [:name], posts: [:title, :body])
             .from(users: :u, posts: :p)
             .join(:posts)
             .where(posts: {published: true})
             .order(posts: {created_at: :desc})
             .limit(10)
             .all(Post)
```

## Documentation Sections

### [Basic Querying](./basic-querying.md)

Learn the fundamentals of building queries with CQL:

- Creating and configuring queries
- Selecting columns and filtering records
- Basic ordering and limiting
- Working with different data types

### [Advanced Querying](./advanced-querying.md)

Explore advanced query building techniques:

- Complex where conditions with blocks
- Subqueries and nested expressions
- Dynamic query building
- Query composition and reuse

### [Joins and Relations](./joins-and-relations.md)

Master the art of joining tables:

- Automatic join inference
- Manual join specification
- Table aliasing strategies
- Complex join conditions

### [Aggregations](./aggregations.md)

Work with aggregated data:

- Built-in aggregation functions
- Group by and having clauses
- Custom aggregation expressions
- Performance considerations

### [Query Execution](./query-execution.md)

Execute and work with query results:

- Different execution methods (all, first, each)
- Type casting and result handling
- Error handling and debugging
- Connection management

### [Query Optimization](./query-optimization.md)

Optimize your queries for performance:

- Query caching strategies
- Index usage and optimization
- Query analysis and profiling
- Best practices for performance

## Integration with Active Record

The Query Builder integrates seamlessly with CQL's Active Record implementation:

```crystal
# Using Query Builder directly
query = CQL::Query.new(schema)
users = query.select(:name, :email).from(:users).all(User)

# Using Active Record query interface
users = User.select(:name, :email).all

# Combining both approaches
query = User.query.select(:name, :email)
users = query.all
```

## Database Support

CQL Query Builder supports multiple database systems:

- **PostgreSQL**: Full feature support with JSONB and advanced types
- **MySQL**: Comprehensive support with JSON and spatial types
- **SQLite**: Lightweight support for embedded applications

Each database adapter provides optimized SQL generation and type mapping.

## Type Safety

CQL leverages Crystal's type system to provide compile-time safety:

```crystal
# Type-safe column selection
query.select(:name, :email)  # Compile-time validation

# Type-safe conditions
query.where(age: 18..65)     # Range validation
query.where(active: true)    # Boolean validation

# Type-safe results
users = query.all(User)      # Automatic type casting
```

## Next Steps

- Start with [Basic Querying](./basic-querying.md) to learn the fundamentals
- Check out the [API Reference](../../api-reference/query-builder-api.md) for complete method documentation
- Review [Query Optimization](./query-optimization.md) for performance best practices

The CQL Query Builder provides a powerful foundation for building robust, type-safe database queries in Crystal applications. Whether you're building simple CRUD operations or complex analytical queries, CQL has you covered.
