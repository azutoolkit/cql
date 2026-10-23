# What is an ORM?

An Object-Relational Mapping (ORM) is a programming technique that lets you interact with a relational database using your programming language's native objects, rather than writing raw SQL queries.

## The Problem ORMs Solve

Without an ORM, you would write code like this:

```crystal
# Raw SQL approach
user_id, user_name, user_email = db.query_one(
  "SELECT id, name, email FROM users WHERE id = ?", 1,
  as: {Int64, String, String}
)
```

With an ORM like CQL:

```crystal
# ORM approach
user = User.find(1)
puts user.name
puts user.email
```

The ORM handles:
- Translating method calls into SQL queries
- Mapping database columns to object properties
- Type conversions between database and Crystal types
- Connection management

## Key Concepts

### Models

A model is a Crystal class that represents a database table. Each instance of the model represents a row in that table.

```crystal
class User                            # Represents the 'users' table
  include CQL::ActiveRecord::Model(Int64) # Provides `id : Int64?` (column: id)
  db_context MyDB, :users

  property name : String              # Column: name
  property email : String             # Column: email

  def initialize(@name : String, @email : String)
  end
end
```

### Queries

The ORM provides methods that translate to SQL:

| ORM Method | SQL Equivalent |
|------------|---------------|
| `User.find(1)` | `SELECT ... FROM users WHERE id = ? LIMIT 1` |
| `User.where(active: true).all` | `SELECT ... FROM users WHERE active = ?` |
| `User.count` | `SELECT COUNT(*) FROM users` |
| `user.save` | `INSERT INTO users ...` or `UPDATE users ...` |

### Relationships

ORMs express table relationships as object associations:

```crystal
# Database: posts table has a user_id column
# ORM: Post belongs_to User

post = Post.find(1)
author = post.user  # No SQL needed in your code!
```

## Benefits of Using an ORM

### 1. Type Safety

CQL leverages Crystal's type system to catch errors at compile time:

```crystal
user.name = 123      # Compile error: expected String, got Int32
user.age = "thirty"  # Compile error: expected Int32, got String
```

### 2. Security

ORMs automatically parameterize queries, preventing SQL injection:

```crystal
# Safe - CQL parameterizes the value
User.where(email: user_input)

# Dangerous raw SQL
db.exec("SELECT * FROM users WHERE email = '#{user_input}'")
```

### 3. Productivity

Write less code and focus on business logic:

```crystal
# Create user with validation
user = User.create!(
  name: "John",
  email: "john@example.com"
)

# Instead of:
# 1. Write INSERT SQL
# 2. Handle errors
# 3. Get the inserted ID
# 4. Validate before insert
# etc.
```

### 4. Database Portability

The same model code works with different databases:

```crystal
# Works with PostgreSQL, MySQL, SQLite, or CockroachDB
User.where(active: true).order(created_at: :desc).all
```

### 5. Maintainability

Changes to your data model are centralized:

```crystal
# Add a new field - one place to change
class User
  property phone : String?  # Add property (and a column in a migration)
end

# All code using User automatically has access to phone
```

## When NOT to Use an ORM

ORMs aren't always the best choice:

- **Complex analytical queries**: Raw SQL may be clearer
- **Performance-critical operations**: Direct SQL might be faster
- **Bulk operations**: ORM overhead can add up
- **Database-specific features**: Some features don't translate

CQL lets you drop to raw SQL when needed:

```crystal
rows = MyDB.exec_query do |conn|
  conn.query_all(<<-SQL, as: {String, Int64})
    SELECT u.name, COUNT(p.id) AS post_count
    FROM users u
    LEFT JOIN posts p ON p.user_id = u.id
    GROUP BY u.id, u.name
    HAVING COUNT(p.id) > 10
  SQL
end
```

`exec_query` hands you the schema's pooled `DB::Connection` (or the current transaction's), so raw statements and model calls can share a transaction. Where possible, prefer bound parameters over string interpolation.

## ORM Patterns

### Active Record

CQL primarily uses the Active Record pattern, where:
- Objects carry both data and behavior
- Models know how to persist themselves
- Business logic lives in the model

```crystal
user = User.new("John", "john@example.com")
user.save  # The user object saves itself
```

### Other Patterns

CQL also supports:
- **Repository Pattern**: `CQL::Repository(T, Pk)` separates persistence from plain domain objects

See [Design Patterns](../design-patterns/active-record.md) for more details.

## Summary

An ORM like CQL:
- Maps database tables to Crystal objects
- Translates method calls to SQL
- Provides type safety and security
- Increases productivity
- Makes code more maintainable

While ORMs have overhead, they're excellent for most application development tasks, especially CRUD operations and working with relationships.
