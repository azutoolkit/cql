---
description: >-
  Guide to query execution in CQL Query Builder.
---

# Query Execution

This guide covers all query execution methods, type casting, result handling, error handling, and connection management in CQL Query Builder.

## Overview

Query execution is the process of running a built query against the database and retrieving results. CQL Query Builder provides several methods for executing queries and handling results in a type-safe way.

## Execution Methods

### all

Returns all results as an array of the specified type.

```crystal
users = query.from(:users).all(User)
```

### first

Returns the first result or nil if no result is found.

```crystal
user = query.from(:users).first(User)
```

### first!

Returns the first result or raises if no result is found.

```crystal
user = query.from(:users).first!(User)
```

### each

Iterates over each result, yielding to a block.

```crystal
query.from(:users).each(User) do |user|
  puts user.name
end
```

### get

Returns a single scalar value (e.g., count, sum, etc.).

```crystal
count = query.from(:users).count.get(Int64)
```

## Type Casting and Result Handling

CQL automatically casts results to the specified type. You can also use named tuples or custom structs for partial selects:

```crystal
# Named tuple result
user_data = query.from(:users).select(:name, :email).all({name: String, email: String})

# Custom struct result
struct UserSummary
  getter name : String
  getter email : String
end
summaries = query.from(:users).select(:name, :email).all(UserSummary)
```

## Error Handling

CQL raises exceptions for query errors, connection issues, and type mismatches. Use standard Crystal error handling:

```crystal
begin
  users = query.from(:users).all(User)
rescue CQL::Error => ex
  puts "Query error: #{ex.message}"
end
```

## Connection Management

CQL manages database connections through the schema context. For long-running applications, use connection pooling and close connections gracefully:

```crystal
# Open a connection
DB.open(ENV["DATABASE_URL"])

# Close a connection
conn.close
```

## Best Practices

- Always specify the result type for type safety
- Use `each` for large result sets to avoid loading all records into memory
- Handle exceptions for robust error reporting
- Use connection pooling for high-concurrency applications
- Close connections when shutting down or after tests

## Example: Full Query Execution

```crystal
schema = CQL::Schema.new
query = CQL::Query.new(schema)

# Get all users
users = query.from(:users).all(User)

# Get the first active user
user = query.from(:users).where(active: true).first(User)

# Count users
count = query.from(:users).count.get(Int64)

# Iterate over users
query.from(:users).each(User) do |user|
  puts user.name
end
```

This guide provides a comprehensive overview of query execution in CQL Query Builder. Use it alongside the API reference for method details and the Active Record guides for model-level operations.
