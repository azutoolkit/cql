---
description: >-
  Learn the fundamentals of building queries with CQL Query Builder - from basic selects to filtering and ordering.
---

# Basic Querying

This guide covers the fundamental aspects of building queries with CQL Query Builder. You'll learn how to create queries, select columns, filter records, and work with different data types.

## Creating Queries

### Basic Query Setup

```crystal
require "cql"

# Create a schema and query instance
schema = CQL::Schema.new
query = CQL::Query.new(schema)
```

### Schema Configuration

Before building queries, you need to configure your schema with table definitions:

```crystal
# Define tables in your schema
schema.table :users do |t|
  t.column :id, :bigint, primary_key: true
  t.column :name, :varchar
  t.column :email, :varchar
  t.column :age, :int
  t.column :active, :boolean, default: true
  t.column :created_at, :timestamp
end

schema.table :posts do |t|
  t.column :id, :bigint, primary_key: true
  t.column :title, :varchar
  t.column :body, :text
  t.column :user_id, :bigint
  t.column :published, :boolean, default: false
  t.column :created_at, :timestamp
end
```

## Selecting Columns

### Select All Columns

```crystal
# Select all columns from a table
query.from(:users).all(User)
```

### Select Specific Columns

```crystal
# Select specific columns
query.select(:name, :email).from(:users).all(User)

# Select with table prefix
query.select(users: [:name, :email]).from(:users).all(User)
```

### Select with Aliases

```crystal
# Select columns with aliases
query.select(:name, :email)
     .from(users: :u)
     .all(User)
```

### Hash-based Selection

```crystal
# Select using hash syntax for multiple tables
query.select(
  users: [:name, :email],
  posts: [:title, :created_at]
).from(:users, :posts).all(User)
```

## Filtering Records

### Basic Where Conditions

```crystal
# Simple equality conditions
query.from(:users).where(active: true).all(User)

# Multiple conditions
query.from(:users)
     .where(active: true, age: 18..65)
     .all(User)
```

### Hash-based Conditions

```crystal
# Using hash syntax
query.from(:users)
     .where(**{active: true, age: 25})
     .all(User)

# With table prefixes
query.from(:users, :posts)
     .where(users: {active: true}, posts: {published: true})
     .all(User)
```

### Block-based Conditions

```crystal
# Using blocks for complex conditions
query.from(:users).where do |filter|
  filter.gt(:age, 18)
        .and
        .eq(:active, true)
        .or
        .eq(:admin, true)
end.all(User)
```

### Pattern Matching

```crystal
# LIKE queries for pattern matching
query.from(:users)
     .where_like(:name, "John%")
     .all(User)

# Case-insensitive search
query.from(:users)
     .where_like(:email, "%@gmail.com")
     .all(User)
```

### Range Conditions

```crystal
# Numeric ranges
query.from(:users)
     .where(age: 18..65)
     .all(User)

# Date ranges
query.from(:posts)
     .where(created_at: 1.week.ago..Time.utc)
     .all(Post)
```

### Array Conditions

```crystal
# IN conditions
query.from(:users)
     .where(role: ["admin", "moderator"])
     .all(User)

# NOT IN conditions
query.from(:users)
     .where.not_in(:status, ["banned", "suspended"])
     .all(User)
```

## Ordering Results

### Basic Ordering

```crystal
# Order by single column
query.from(:users)
     .order(:name)
     .all(User)

# Order by multiple columns
query.from(:users)
     .order(:active, :name)
     .all(User)
```

### Directional Ordering

```crystal
# Ascending order (default)
query.from(:users)
     .order(:name, :asc)
     .all(User)

# Descending order
query.from(:users)
     .order(:created_at, :desc)
     .all(User)
```

### Hash-based Ordering

```crystal
# Using hash syntax for complex ordering
query.from(:users)
     .order(**{active: :desc, name: :asc})
     .all(User)

# With table prefixes
query.from(:users, :posts)
     .order(users: {name: :asc}, posts: {created_at: :desc})
     .all(User)
```

### Reordering

```crystal
# Override previous ordering
query.from(:users)
     .order(:name)
     .reorder(:created_at, :desc)
     .all(User)

# Reverse current ordering
query.from(:users)
     .order(:name, :created_at)
     .reverse_order
     .all(User)
```

## Limiting and Pagination

### Basic Limiting

```crystal
# Limit results
query.from(:users)
     .limit(10)
     .all(User)

# Limit with ordering
query.from(:users)
     .order(:created_at, :desc)
     .limit(5)
     .all(User)
```

### Offset for Pagination

```crystal
# Basic pagination
query.from(:users)
     .order(:created_at)
     .limit(20)
     .offset(40)  # Skip first 40 records
     .all(User)

# Page-based pagination
page = 3
per_page = 20
offset = (page - 1) * per_page

query.from(:users)
     .order(:created_at)
     .limit(per_page)
     .offset(offset)
     .all(User)
```

## Distinct Queries

### Remove Duplicates

```crystal
# Select distinct values
query.from(:users)
     .select(:role)
     .distinct
     .all(User)

# Distinct with multiple columns
query.from(:users)
     .select(:role, :department)
     .distinct
     .all(User)
```

## Working with Different Data Types

### String Operations

```crystal
# String equality
query.from(:users)
     .where(name: "John Doe")
     .all(User)

# String pattern matching
query.from(:users)
     .where_like(:email, "%@company.com")
     .all(User)
```

### Numeric Operations

```crystal
# Integer comparisons
query.from(:users)
     .where(age: 25)
     .all(User)

# Range queries
query.from(:users)
     .where(age: 18..65)
     .all(User)

# Greater than/less than
query.from(:users).where do |filter|
  filter.gt(:age, 18)
        .and
        .lt(:age, 65)
end.all(User)
```

### Boolean Operations

```crystal
# Boolean values
query.from(:users)
     .where(active: true)
     .all(User)

# Null checks
query.from(:users)
     .where(admin: nil)
     .all(User)
```

### Date and Time

```crystal
# Date comparisons
query.from(:posts)
     .where(created_at: 1.week.ago..Time.utc)
     .all(Post)

# Specific date
query.from(:posts)
     .where(created_at: Time.utc(2023, 1, 1))
     .all(Post)
```

## Query Execution

### Different Execution Methods

```crystal
# Get all results
users = query.from(:users).all(User)

# Get first result
user = query.from(:users).first(User)

# Get first result (raises if not found)
user = query.from(:users).first!(User)

# Iterate over results
query.from(:users).each(User) do |user|
  puts user.name
end

# Get scalar value
count = query.from(:users).count.get(Int64)
```

### Type Casting

```crystal
# Automatic type casting
users = query.from(:users).all(User)

# Manual type specification
user_data = query.from(:users)
                 .select(:name, :email)
                 .all({name: String, email: String})
```

## Error Handling

### Basic Error Handling

```crystal
begin
  users = query.from(:users).all(User)
rescue ex : CQL::Error
  puts "Query error: #{ex.message}"
end
```

### Query Validation

```crystal
# Check if query is valid before execution
if query.valid?
  users = query.all(User)
else
  puts "Invalid query configuration"
end
```

## Best Practices

### Query Composition

```crystal
# Build queries incrementally
base_query = query.from(:users).where(active: true)

# Add conditions based on logic
if admin_only
  base_query = base_query.where(admin: true)
end

if age_filter
  base_query = base_query.where(age: 18..65)
end

users = base_query.order(:name).all(User)
```

### Performance Considerations

```crystal
# Use specific columns instead of *
query.select(:name, :email).from(:users).all(User)

# Add appropriate limits
query.from(:users).limit(1000).all(User)

# Use indexes effectively
query.from(:users).where(active: true).order(:created_at).all(User)
```

### Query Reuse

```crystal
# Create reusable query builders
def active_users_query
  query.from(:users).where(active: true)
end

# Use in different contexts
recent_users = active_users_query
               .order(:created_at, :desc)
               .limit(10)
               .all(User)

admin_users = active_users_query
              .where(admin: true)
              .all(User)
```

## Next Steps

- Explore [Advanced Querying](./advanced-querying.md) for complex query patterns
- Learn about [Joins and Relations](./joins-and-relations.md) for multi-table queries
- Check out [Aggregations](./aggregations.md) for grouped data operations
- Review the [API Reference](../../api-reference/query-builder-api.md) for complete method documentation

The basic querying capabilities provide a solid foundation for most database operations. As you become comfortable with these concepts, you can move on to more advanced features for complex data scenarios.
