# Querying with CQL

CQL provides a powerful query interface through the `CQL::Query` class, which can be accessed via `Model.query`. This guide covers how to use this interface to build and execute database queries.

## Basic Query Building

Start a query using `Model.query`:

```crystal
# Get a base query for the User model
query = User.query

# Execute the query
users = query.all(User)
```

## Selecting Columns

### Basic Selection

```crystal
# Select specific columns
User.query.select(:name, :email).all(User)

# Select all columns from a specific table
User.query.select(users: [:name, :email, :age]).all(User)

# Select with table aliases
User.query.from(users: :u).select(u: [:name, :email]).all(User)
```

### Aggregate Functions

```crystal
# Count records
User.query.count(:id)

# Other aggregates
User.query.sum(:age)
User.query.avg(:age)
User.query.min(:age)
User.query.max(:age)
```

## Filtering Records

### Basic Conditions

```crystal
# Simple equality conditions
User.query.where(name: "John", active: true).all(User)

# Using block syntax for complex conditions
User.query.where { (age > 18) & (active == true) }.all(User)

# Multiple conditions
User.query.where(name: "John")
       .where(active: true)
       .all(User)
```

### Advanced Conditions

```crystal
# IN clauses
User.query.where { role.in(["admin", "moderator"]) }.all(User)

# LIKE conditions
User.query.where { name.like("J%") }.all(User)

# Complex logical expressions
User.query.where { (role == "admin") & ((status == "active") | (status == "pending")) }.all(User)
```

## Joining Tables

### Basic Joins

```crystal
# Inner join
User.query.join(Post) { users.id == posts.user_id }.all(User)

# Left join
User.query.left_join(Post) { users.id == posts.user_id }.all(User)

# Right join
User.query.right_join(Post) { users.id == posts.user_id }.all(User)
```

### Multiple Joins

```crystal
User.query.join(Post) { users.id == posts.user_id }
         .join(Comment) { posts.id == comments.post_id }
         .all(User)
```

### Join with Aliases

```crystal
User.query.from(users: :u)
         .join({posts: :p}) { u.id == p.user_id }
         .all(User)
```

## Ordering Results

```crystal
# Single column ordering
User.query.order(:name).all(User)                    # ASC by default
User.query.order(name: :desc).all(User)             # Explicit DESC

# Multiple columns
User.query.order(:created_at, name: :desc).all(User)

# Using block syntax
User.query.order { created_at.desc }.all(User)
```

## Grouping and Aggregation

```crystal
# Basic grouping
User.query.group_by(:role).all(User)

# Grouping with aggregates
User.query.select { [role, count(id).as("total")] }
         .group_by(:role)
         .all(User)

# Having clause
User.query.select { [role, count(id).as("total")] }
         .group_by(:role)
         .having { count(id) > 5 }
         .all(User)
```

## Pagination

```crystal
# Limit results
User.query.limit(10).all(User)

# Offset and limit
User.query.offset(20).limit(10).all(User)

# Common pagination pattern
page = 2
per_page = 10
User.query.offset((page - 1) * per_page)
      .limit(per_page)
      .all(User)
```

## Distinct Results

```crystal
# Distinct on all columns
User.query.distinct.all(User)

# Distinct on specific columns
User.query.distinct(:name, :email).all(User)
```

## Executing Queries

### Retrieving Results

```crystal
# Get all records
users = User.query.all(User)

# Get first record
user = User.query.first(User)

# Get first record (raises if not found)
user = User.query.first!(User)

# Get scalar value
count = User.query.count(:id).get(Int64)
```

### Iterating Over Results

```crystal
# Process each record
User.query.each(User) do |user|
  puts user.name
end
```

## Query Inspection

```crystal
# Get the generated SQL
query = User.query.where(active: true).order(:name)
sql, params = query.to_sql
puts "SQL: #{sql}"
puts "Parameters: #{params}"
```

## Best Practices

1. **Use Table Aliases**

   ```crystal
   # Instead of
   User.query.join(Post).where("users.name = posts.author")

   # Use
   User.query.from(users: :u)
           .join({posts: :p})
           .where { u.name == p.author }
   ```

2. **Select Only Needed Columns**

   ```crystal
   # Instead of
   User.query.all(User)

   # Use
   User.query.select(:id, :name, :email).all(User)
   ```

3. **Use Block Syntax for Complex Conditions**

   ```crystal
   # Instead of
   User.query.where("age > ? AND (status = ? OR status = ?)", 18, "active", "pending")

   # Use
   User.query.where { (age > 18) & ((status == "active") | (status == "pending")) }
   ```

4. **Chain Methods for Readability**

   ```crystal
   User.query
       .where(active: true)
       .order(:name)
       .limit(10)
       .all(User)
   ```

5. **Use Meaningful Aliases**
   ```crystal
   User.query.from(users: :u)
           .join({posts: :p}) { u.id == p.user_id }
           .join({comments: :c}) { p.id == c.post_id }
   ```
