---
icon: lightbulb
---

# Core Concepts

> **Master the fundamentals** - Essential building blocks for effective CQL development

Welcome to the **Core Concepts** section! This is your comprehensive guide to understanding CQL's fundamental architecture and features. Whether you're new to ORMs or transitioning from other frameworks, these concepts will give you the solid foundation needed to build robust Crystal applications with CQL.

## What You'll Master

This section covers the essential building blocks that make CQL powerful and developer-friendly:

- **Schema Definition** - Type-safe database structure design
- **Database Initialization** - Connection setup and management
- **Schema Alterations** - Evolving your database structure
- **Migrations** - Systematic schema evolution and versioning
- **CRUD Operations** - Create, Read, Update, Delete mastery
- **Design Patterns** - Active Record, Repository, and Data Mapper approaches

## Learning Path

**Recommended Path:**

1. **Schema Definition** → Learn how to define your database structure
2. **Database Initialization** → Set up connections and build your schema
3. **CRUD Operations** → Master basic database interactions
4. **Schema Alterations** → Understand how to modify existing structures
5. **Migrations** → Implement systematic schema evolution
6. **Design Patterns** → Choose the right architectural approach
7. **Active Record Guide** → Apply concepts to real applications

## Schema Definition

> **Type-safe database structure design with Crystal's macro system**

CQL's schema definition system leverages Crystal's powerful macro capabilities to provide compile-time safety and intuitive database structure design.

### Key Features

- **Type Safety** - Compile-time validation of schema structure
- **Multi-Database Support** - Works with PostgreSQL, MySQL, and SQLite
- **Declarative DSL** - Clean, readable schema definitions
- **Constraint Support** - Foreign keys, unique constraints, and check constraints

### Quick Example

```crystal
# Define a complete schema with relationships
UserSchema = CQL::Schema.define(
  :user_app,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do

  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String, size: 100
    column :email, String, size: 255
    column :age, Int32
    column :active, Bool, default: true
    timestamps

    # Constraints
    unique_constraint [:email]
    check_constraint "age >= 0 AND age <= 150"
  end

  table :posts do
    primary :id, Int64, auto_increment: true
    column :title, String, size: 255
    column :content, String
    column :user_id, Int64
    column :published, Bool, default: false
    timestamps

    # Foreign key relationship
    foreign_key :user_id, references: :users, on_delete: :cascade
    index [:user_id, :published]
  end
end
```

### What You'll Learn

- **Table Structure** - Defining columns, types, and constraints
- **Relationships** - Foreign keys and referential integrity
- **Indexing Strategy** - Performance optimization through proper indexing
- **Database-Specific Features** - Leveraging unique database capabilities

**👉 [Learn Schema Definition →](schemas.md)**

## Database Initialization

> **Efficient connection management and schema building**

Learn how to initialize your database connections, configure adapters, and build your schema for optimal performance and reliability.

### Key Concepts

- **Connection Pooling** - Efficient database connection management
- **Environment Configuration** - Development, testing, and production setups
- **Schema Building** - Converting definitions to actual database tables
- **Error Handling** - Robust connection error management

### Quick Example

```crystal
# Environment-specific database setup
case ENV["CRYSTAL_ENV"]?
when "production"
  MyDB = CQL::Schema.define(
    :production_db,
    adapter: CQL::Adapter::Postgres,
    uri: ENV["DATABASE_URL"],
    pool_size: 20,
    checkout_timeout: 10.seconds
  )

when "test"
  MyDB = CQL::Schema.define(
    :test_db,
    adapter: CQL::Adapter::SQLite,
    uri: "sqlite3://:memory:",  # Fast in-memory testing
    pool_size: 1
  )

else # development
  MyDB = CQL::Schema.define(
    :dev_db,
    adapter: CQL::Adapter::SQLite,
    uri: "sqlite3://./db/development.db",
    pool_size: 5
  )
end

# Build the actual database schema
MyDB.build
```

### What You'll Learn

- **Adapter Configuration** - Setting up PostgreSQL, MySQL, and SQLite
- **Connection Strategies** - Pool sizing and timeout management
- **Environment Management** - Development vs production configurations
- **Health Checks** - Monitoring connection status

**👉 [Learn Database Initialization →](initializing-the-database.md)**

## CRUD Operations

> **Master Create, Read, Update, Delete operations with type safety**

CRUD operations are the foundation of database interactions. CQL provides both **Active Record** and **Repository** patterns for maximum flexibility.

### Core Capabilities

- **Type-Safe Operations** - Compile-time validation of data operations
- **Multiple Patterns** - Active Record and Repository approaches
- **Advanced Querying** - Complex WHERE conditions and joins
- **Batch Operations** - Efficient bulk operations
- **Transaction Support** - ACID compliance with automatic rollback

### Quick Examples

**Active Record Pattern:**

```crystal
# Create
user = User.create!(
  name: "Alice Johnson",
  email: "alice@example.com",
  age: 28
)

# Read
users = User.where(active: true).all
user = User.find!(user.id)

# Update
user.update!(age: 29)

# Delete
user.destroy!
```

**Repository Pattern:**

```crystal
users = CQL::Repository(User, Int64).new(MyDB, :users)

# Create
user_id = users.create(name: "Bob", email: "bob@example.com")

# Read
user = users.find!(user_id)
active_users = users.where(active: true).all

# Update
users.update(user_id, age: 30)

# Delete
users.delete(user_id)
```

### What You'll Learn

- **Basic CRUD** - Create, read, update, delete operations
- **Query Building** - Complex WHERE conditions and joins
- **Batch Operations** - Efficient bulk data operations
- **Error Handling** - Graceful error management

**👉 [Learn CRUD Operations →](crud-operations/README.md)**

## Schema Alterations

> **Evolving your database structure safely and efficiently**

Learn how to modify existing database schemas without losing data or causing downtime.

### Key Concepts

- **Safe Alterations** - Modify tables without data loss
- **Constraint Management** - Add, modify, and remove constraints
- **Index Optimization** - Improve query performance
- **Migration Integration** - Work with CQL's migration system

### Quick Example

```crystal
# Alter existing table
MyDB.alter_table :users do |t|
  # Add new column
  t.add_column :phone, String, size: 20

  # Modify existing column
  t.modify_column :email, String, size: 255, null: false

  # Add constraint
  t.add_unique_constraint [:email, :phone]

  # Add index
  t.add_index [:created_at, :active]
end
```

### What You'll Learn

- **Column Operations** - Add, modify, and remove columns
- **Constraint Management** - Foreign keys, unique constraints, checks
- **Index Strategy** - Performance optimization
- **Data Migration** - Safely transforming existing data

**👉 [Learn Schema Alterations →](altering-the-schema.md)**

## Migrations

> **Version-controlled schema evolution for team development**

Migrations provide a systematic way to evolve your database schema over time, ensuring consistency across all environments.

### Key Features

- **Version Control** - Track schema changes over time
- **Reversible Operations** - Rollback changes when needed
- **Team Collaboration** - Consistent schema across environments
- **Environment Management** - Different schemas for dev, test, prod

### Quick Example

```crystal
class CreateUsers < CQL::Migration
  def up
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.integer :age
      t.boolean :active, default: true
      t.timestamps

      t.index :email, unique: true
    end
  end

  def down
    drop_table :users
  end
end
```

### What You'll Learn

- **Migration Structure** - Creating and organizing migrations
- **Schema Operations** - Table creation, modification, and deletion
- **Data Migrations** - Transforming existing data
- **Rollback Strategy** - Reversing changes safely

**👉 [Learn Migrations →](migrations.md)**

## Design Patterns

> **Choose the right architectural approach for your application**

CQL supports multiple design patterns, allowing you to choose the approach that best fits your application's needs.

### Available Patterns

- **Active Record** - Domain-rich applications with business logic in models
- **Repository** - Data-centric architectures with clean separation
- **Data Mapper** - Complex domain models with flexible mapping

### Pattern Comparison

| Pattern           | Best For                               | Complexity | Flexibility |
| ----------------- | -------------------------------------- | ---------- | ----------- |
| **Active Record** | CRUD-heavy apps, rapid prototyping     | Low        | Medium      |
| **Repository**    | Complex business logic, testability    | Medium     | High        |
| **Data Mapper**   | Complex domains, multiple data sources | High       | Very High   |

### What You'll Learn

- **Pattern Selection** - Choosing the right approach
- **Implementation** - How to implement each pattern
- **Best Practices** - When and how to use each pattern
- **Migration Between Patterns** - Switching approaches as needed

**👉 [Learn Design Patterns →](patterns/README.md)**

## Next Steps

Now that you understand the core concepts, you're ready to build real applications! Here's what to explore next:

### Ready to Build?

- **[Getting Started Guide](../guides/getting-started.md)** - Build your first CQL application
- **[Active Record with CQL](../guides/active-record-with-cql/README.md)** - Learn the most popular pattern
- **[Configuration Guide](../guides/configuration.md)** - Set up for your environment

### Need More Details?

- **[Architecture Overview](../guides/architecture-overview.md)** - Deep dive into CQL's design
- **[Best Practices](../guides/best-practices.md)** - Follow proven patterns
- **[Examples](../examples/README.md)** - See CQL in action

### Getting Stuck?

- **[Troubleshooting Guide](../troubleshooting.md)** - Solve common problems
- **[FAQ](../faqs.md)** - Find quick answers
- **[Community](../guides/community.md)** - Get help from others

---

> The concepts you've learned here form the foundation for everything else in CQL. Take your time to understand them well - they'll make the advanced topics much easier to grasp!

> Try building a simple application using these concepts before moving to the advanced guides. The [Examples](../examples/README.md) section has great starting points!
