---
description: >-
  Master CQL's raw CRUD operations with the core CQL classes. Learn to Create,
  Read, Update, and Delete records using CQL::Insert, CQL::Query, CQL::Update,
  and CQL::Delete for direct, type-safe database interactions.
---

# CRUD Operations

> **Create, Read, Update, Delete** – The fundamental building blocks of database interactions using CQL's core classes

CQL provides powerful, type-safe CRUD operations through its core classes that work seamlessly across PostgreSQL, MySQL, and SQLite. These low-level operations give you direct control over SQL generation while maintaining type safety and database abstraction.

## Quick Start

First, let's set up a basic schema to work with:

```crystal
# Example schema for demonstrations
require "cql"

schema = CQL::Schema.new(
  adapter: CQL::Adapter.new({
    uri: "postgresql://user:password@localhost/mydb"
  })
)

schema.define do
  table :users do
    primary_key :id, Int64, auto_increment: true
    column :name, String, size: 255
    column :email, String, size: 255
    column :age, Int32
    column :active, Bool, default: true
    column :created_at, Time
    column :updated_at, Time

    index :email, unique: true
    index [:active, :created_at]
  end
end
```

---

## 🆕 Create Operations

### Basic Insert with `CQL::Insert`

The `CQL::Insert` class provides methods for inserting data into tables:

```crystal
# Create a new insert operation
insert = CQL::Insert.new(schema)

# Insert a single record using hash syntax
result = insert
  .into(:users)
  .values(
    name: "Alice Johnson",
    email: "alice@example.com",
    age: 28,
    created_at: Time.utc,
    updated_at: Time.utc
  )
  .commit

puts "✅ Record inserted, affected rows: #{result.rows_affected}"

# Insert using keyword arguments
insert = CQL::Insert.new(schema)
  .into(:users)
  .values(
    name: "Bob Smith",
    email: "bob@example.com",
    age: 35,
    active: true,
    created_at: Time.utc,
    updated_at: Time.utc
  )

# Get the last inserted ID (PostgreSQL, MySQL, SQLite)
last_id = insert.last_insert_id
puts "🆔 New user ID: #{last_id}"
```

### Bulk Insert Operations

```crystal
# Insert multiple records at once
users_data = [
  {
    name: "Carol Davis",
    email: "carol@example.com",
    age: 42,
    created_at: Time.utc,
    updated_at: Time.utc
  },
  {
    name: "David Wilson",
    email: "david@example.com",
    age: 31,
    created_at: Time.utc,
    updated_at: Time.utc
  }
]

result = CQL::Insert.new(schema)
  .into(:users)
  .values(users_data)
  .commit

puts "📦 Inserted #{result.rows_affected} users"
```

### Insert with Query Data

```crystal
# Insert data from another query
source_query = CQL::Query.new(schema)
  .select(:name, :email, :age)
  .from(:temp_users)
  .where(active: true)

result = CQL::Insert.new(schema)
  .into(:users)
  .query(source_query)
  .commit

puts "📋 Copied #{result.rows_affected} records from temp_users"
```

### Insert with Returning Values

```crystal
# Return specific columns after insert (PostgreSQL)
insert = CQL::Insert.new(schema)
  .into(:users)
  .values(
    name: "Emma Thompson",
    email: "emma@example.com",
    age: 29,
    created_at: Time.utc,
    updated_at: Time.utc
  )
  .back(:id, :name, :created_at)

query, params = insert.to_sql
puts "SQL: #{query}"
puts "Params: #{params}"

result = insert.commit
# Access returned values using appropriate query methods
```

---

## 📖 Read Operations

### Basic Queries with `CQL::Query`

The `CQL::Query` class provides comprehensive methods for reading data:

```crystal
# Create a new query
query = CQL::Query.new(schema)

# Select all columns from users
users = query
  .select(:id, :name, :email, :age, :active)
  .from(:users)
  .all(NamedTuple(id: Int64, name: String, email: String, age: Int32, active: Bool))

users.each do |user|
  puts "👤 #{user[:name]} (#{user[:email]}) - Age: #{user[:age]}"
end

# Select specific columns
names = CQL::Query.new(schema)
  .select(:name)
  .from(:users)
  .where(active: true)
  .all(NamedTuple(name: String))

puts "Active users: #{names.map(&.[:name]).join(", ")}"
```

### Where Conditions

```crystal
# Basic where conditions using hash
active_users = CQL::Query.new(schema)
  .select(:name, :email)
  .from(:users)
  .where(active: true, age: 25)
  .all(NamedTuple(name: String, email: String))

# Where conditions using keyword arguments
young_users = CQL::Query.new(schema)
  .select(:name, :age)
  .from(:users)
  .where(active: true)
  .where(age: 18..30) # Range conditions
  .all(NamedTuple(name: String, age: Int32))

# Complex where conditions using block syntax
query = CQL::Query.new(schema)
  .select(:name, :email, :age)
  .from(:users)
  .where { |w| w.active == true && w.age > 21 }

users = query.all(NamedTuple(name: String, email: String, age: Int32))
```

### Array and IN Conditions

```crystal
# IN conditions with arrays
target_ages = [25, 30, 35, 40]
users = CQL::Query.new(schema)
  .select(:name, :age)
  .from(:users)
  .where(age: target_ages, active: true)
  .all(NamedTuple(name: String, age: Int32))

# String array conditions
emails = ["alice@example.com", "bob@example.com", "carol@example.com"]
users = CQL::Query.new(schema)
  .select(:name, :email)
  .from(:users)
  .where(email: emails)
  .all(NamedTuple(name: String, email: String))
```

### LIKE Patterns

```crystal
# LIKE pattern matching
gmail_users = CQL::Query.new(schema)
  .select(:name, :email)
  .from(:users)
  .where_like(:email, "%@gmail.com")
  .all(NamedTuple(name: String, email: String))
```

### Ordering and Limiting

```crystal
# Order by single column
users = CQL::Query.new(schema)
  .select(:name, :age)
  .from(:users)
  .order(:age) # ASC by default
  .all(NamedTuple(name: String, age: Int32))

# Order by multiple columns with direction
users = CQL::Query.new(schema)
  .select(:name, :age, :created_at)
  .from(:users)
  .order(age: :desc, created_at: :asc)
  .all(NamedTuple(name: String, age: Int32, created_at: Time))

# Limit and offset
paginated_users = CQL::Query.new(schema)
  .select(:name, :email)
  .from(:users)
  .order(:name)
  .limit(10)
  .offset(20)
  .all(NamedTuple(name: String, email: String))
```

### Aggregations

```crystal
# Count records
total_users = CQL::Query.new(schema)
  .from(:users)
  .count(:id)
  .get(Int64)

puts "Total users: #{total_users}"

# Multiple aggregations
query = CQL::Query.new(schema)
  .from(:users)
  .where(active: true)

query.count(:id)
query.avg(:age)
query.min(:age)
query.max(:age)

# Get aggregated data
result = query.all(NamedTuple(
  count_id: Int64,
  avg_age: Float64,
  min_age: Int32,
  max_age: Int32
))
```

### Group By and Having

```crystal
# Group by with aggregations
age_groups = CQL::Query.new(schema)
  .select(:age)
  .from(:users)
  .where(active: true)
  .group(:age)
  .count(:id)
  .having { |h| h.count(:id) > 5 }
  .all(NamedTuple(age: Int32, count_id: Int64))

age_groups.each do |group|
  puts "Age #{group[:age]}: #{group[:count_id]} users"
end
```

### First Record and Single Values

```crystal
# Get first matching record
oldest_user = CQL::Query.new(schema)
  .select(:name, :age)
  .from(:users)
  .where(active: true)
  .order(age: :desc)
  .first(NamedTuple(name: String, age: Int32))

if oldest_user
  puts "Oldest user: #{oldest_user[:name]} (#{oldest_user[:age]})"
end

# Get a single scalar value
max_age = CQL::Query.new(schema)
  .from(:users)
  .max(:age)
  .get(Int32)

puts "Maximum age: #{max_age || 0}"
```

---

## ✏️ Update Operations

### Basic Updates with `CQL::Update`

The `CQL::Update` class provides methods for updating existing records:

```crystal
# Update using hash syntax
result = CQL::Update.new(schema)
  .table(:users)
  .set(
    name: "Alice Johnson-Smith",
    age: 29,
    updated_at: Time.utc
  )
  .where(email: "alice@example.com")
  .commit

puts "✅ Updated #{result.rows_affected} user(s)"

# Update using keyword arguments
result = CQL::Update.new(schema)
  .table(:users)
  .set(active: false, updated_at: Time.utc)
  .where(age: 65..100)
  .commit

puts "🔄 Deactivated #{result.rows_affected} senior users"
```

### Complex Update Conditions

```crystal
# Update with multiple conditions
result = CQL::Update.new(schema)
  .table(:users)
  .set(active: false)
  .where(active: true)
  .where { |w| w.age < 18 }
  .commit

# Update with array conditions
inactive_emails = ["user1@example.com", "user2@example.com"]
result = CQL::Update.new(schema)
  .table(:users)
  .set(active: false, updated_at: Time.utc)
  .where(email: inactive_emails)
  .commit
```

### Optimistic Locking

```crystal
# Update with optimistic locking
current_version = 5
result = CQL::Update.new(schema)
  .table(:users)
  .set(name: "Updated Name", updated_at: Time.utc)
  .where(id: 1)
  .with_optimistic_lock(version: current_version, column: :version)
  .commit

if result.rows_affected == 0
  puts "❌ Record was modified by another process"
else
  puts "✅ Update successful with version check"
end
```

### Update with Returning Values

```crystal
# Return updated values (PostgreSQL)
update = CQL::Update.new(schema)
  .table(:users)
  .set(active: true, updated_at: Time.utc)
  .where(active: false)
  .back(:id, :name, :updated_at)

query, params = update.to_sql
puts "SQL: #{query}"

result = update.commit
puts "Updated #{result.rows_affected} users"
```

---

## 🗑️ Delete Operations

### Basic Deletes with `CQL::Delete`

The `CQL::Delete` class provides methods for removing records:

```crystal
# Delete specific records
result = CQL::Delete.new(schema)
  .from(:users)
  .where(active: false)
  .commit

puts "🗑️ Deleted #{result.rows_affected} inactive users"

# Delete with multiple conditions
result = CQL::Delete.new(schema)
  .from(:users)
  .where(active: false, age: 100..150)
  .commit

puts "🗑️ Deleted #{result.rows_affected} inactive senior users"
```

### Complex Delete Conditions

```crystal
# Delete using block syntax
result = CQL::Delete.new(schema)
  .from(:users)
  .where { |w| w.active == false && w.age > 65 }
  .commit

# Delete with array conditions
spam_emails = ["spam1@example.com", "spam2@example.com", "spam3@example.com"]
result = CQL::Delete.new(schema)
  .from(:users)
  .where(email: spam_emails)
  .commit

puts "🗑️ Deleted #{result.rows_affected} spam accounts"
```

### Delete with USING clause

```crystal
# Delete using another table (PostgreSQL/MySQL)
result = CQL::Delete.new(schema)
  .from(:users)
  .using(:user_sessions)
  .where { |w| w.users.id == w.user_sessions.user_id && w.user_sessions.expired_at < Time.utc }
  .commit

puts "🗑️ Deleted #{result.rows_affected} users with expired sessions"
```

### Delete with Returning Values

```crystal
# Return deleted values (PostgreSQL)
delete_op = CQL::Delete.new(schema)
  .from(:users)
  .where(active: false)
  .back(:id, :name, :email)

query, params = delete_op.to_sql
puts "SQL: #{query}"

result = delete_op.commit
puts "Deleted #{result.rows_affected} users"
```

---

## 🔄 CRUD Flow Diagram

```mermaid
graph TD
    A[Start] --> B{Operation Type}

    B -->|Create| C[CQL::Insert.new]
    B -->|Read| D[CQL::Query.new]
    B -->|Update| E[CQL::Update.new]
    B -->|Delete| F[CQL::Delete.new]

    C --> C1[.into(:table)]
    C1 --> C2[.values(data)]
    C2 --> C3[.commit / .last_insert_id]

    D --> D1[.select(:columns)]
    D1 --> D2[.from(:table)]
    D2 --> D3[.where(conditions)]
    D3 --> D4[.all / .first / .get]

    E --> E1[.table(:table)]
    E1 --> E2[.set(values)]
    E2 --> E3[.where(conditions)]
    E3 --> E4[.commit]

    F --> F1[.from(:table)]
    F1 --> F2[.where(conditions)]
    F2 --> F3[.commit]

    C3 --> G[Result]
    D4 --> G
    E4 --> G
    F3 --> G

    style A fill:#e1f5fe
    style G fill:#c8e6c9
    style C fill:#fff3e0
    style D fill:#e8f5e8
    style E fill:#f3e5f5
    style F fill:#ffebee
```

---

## 🏃‍♂️ Performance Tips

### Query Optimization

```crystal
# Use specific column selection instead of SELECT *
efficient_query = CQL::Query.new(schema)
  .select(:id, :name, :email) # Only select what you need
  .from(:users)
  .where(active: true)
  .limit(100)

# Generate SQL to inspect query
query, params = efficient_query.to_sql
puts "Optimized SQL: #{query}"
puts "Parameters: #{params}"
```

### Batch Operations

```crystal
# Process large datasets in batches
batch_size = 1000
offset = 0

loop do
  batch = CQL::Query.new(schema)
    .select(:id, :email)
    .from(:users)
    .where(active: false)
    .limit(batch_size)
    .offset(offset)
    .all(NamedTuple(id: Int64, email: String))

  break if batch.empty?

  # Process batch
  batch.each do |user|
    # Do something with inactive user
    puts "Processing inactive user: #{user[:email]}"
  end

  offset += batch_size
end
```

### Connection Management

```crystal
# Use transactions for multiple operations
schema.transaction do |conn|
  # All operations within this block use the same connection

  insert_result = CQL::Insert.new(schema)
    .into(:users)
    .values(name: "Test User", email: "test@example.com", age: 25)
    .commit

  update_result = CQL::Update.new(schema)
    .table(:users)
    .set(active: true)
    .where(email: "test@example.com")
    .commit

  # Transaction automatically commits if no exceptions
  # or rolls back if any operation fails
end
```

---

## 🎯 Best Practices

### Type Safety

```crystal
# Always specify return types for queries
struct UserData
  include DB::Serializable

  property id : Int64
  property name : String
  property email : String
  property age : Int32
  property active : Bool
end

# Use custom structs for type-safe results
users = CQL::Query.new(schema)
  .select(:id, :name, :email, :age, :active)
  .from(:users)
  .where(active: true)
  .all(UserData)

users.each do |user|
  puts "#{user.name} (#{user.email}) - Active: #{user.active}"
end
```

### Error Handling

```crystal
begin
  result = CQL::Insert.new(schema)
    .into(:users)
    .values(name: "Test", email: "duplicate@example.com")
    .commit

  puts "✅ Insert successful"
rescue DB::Error => ex
  puts "❌ Database error: #{ex.message}"
rescue Exception => ex
  puts "💥 Unexpected error: #{ex.message}"
end
```

### SQL Inspection

```crystal
# Always inspect generated SQL during development
insert = CQL::Insert.new(schema)
  .into(:users)
  .values(name: "Debug User", email: "debug@example.com")

query, params = insert.to_sql
puts "Generated SQL: #{query}"
puts "Parameters: #{params.inspect}"

# Then execute
result = insert.commit
```

---

## 🔗 Further Reading

For more advanced CQL operations and patterns:

- **[Schema Definitions](../schemas.md)** - Table and column definitions
- **[Migrations](../migrations.md)** - Database schema evolution
- **[Query Performance](../../advanced-topics/performance-optimization.md)** - Optimization techniques
- **[Patterns](../patterns/)** - Active Record and Repository patterns
- **[Transactions](../../guides/active-record-with-cql/transactions.md)** - ACID compliance

---

> 💡 **Tip**: These raw CQL operations provide the foundation for higher-level patterns like Active Record. Understanding them helps you write more efficient and maintainable database code!
