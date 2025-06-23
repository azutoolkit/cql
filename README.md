[![Crystal CI](https://github.com/azutoolkit/cql/actions/workflows/crystal.yml/badge.svg)](https://github.com/azutoolkit/cql/actions/workflows/crystal.yml)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/a85e29e6b78849c28fb813397cc3eb1a)](https://app.codacy.com/gh/azutoolkit/cql/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)

# CQL (Crystal Query Language)

<img width="1038" alt="cql-banner" src="https://github.com/user-attachments/assets/ed4e733a-3d37-4d03-a4d8-d15bfd7e6f25">

CQL is a powerful Object-Relational Mapping (ORM) library for the Crystal programming language. It provides a type-safe, high-performance interface for interacting with SQL databases, combining the flexibility of raw SQL with the safety and clarity of Crystal's static type system.

## Table of Contents

- [CQL (Crystal Query Language)](#cql-crystal-query-language)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [Supported Databases](#supported-databases)
  - [Installation](#installation)
  - [Quick Start](#quick-start)
    - [1. Define Your Schema](#1-define-your-schema)
    - [2. Create Models](#2-create-models)
    - [3. Work with Your Data](#3-work-with-your-data)
  - [Core Features](#core-features)
    - [Type-Safe Schema Definition](#type-safe-schema-definition)
    - [Active Record Pattern](#active-record-pattern)
    - [Comprehensive Validations](#comprehensive-validations)
    - [Powerful Relationships](#powerful-relationships)
    - [Database Transactions](#database-transactions)
    - [Schema Migrations](#schema-migrations)
    - [Query Scopes](#query-scopes)
  - [Advanced Features](#advanced-features)
  - [Documentation](#documentation)
    - [Quick Links](#quick-links)
  - [Development](#development)
    - [Running Tests](#running-tests)
    - [Database Support](#database-support)
  - [Contributing](#contributing)
    - [Development Guidelines](#development-guidelines)
  - [License](#license)

## Features

- **🔒 Type-Safe ORM**: Leverage Crystal's static type system for compile-time safety
- **⚡ High Performance**: Compile-time optimizations for excellent runtime performance
- **🏗️ Active Record Pattern**: Intuitive Active Record API with full CRUD operations
- **🔗 Advanced Relationships**: Support for `belongs_to`, `has_one`, `has_many`, and `many_to_many` associations
- **✅ Comprehensive Validations**: Built-in validation system with custom validator support
- **🔄 Lifecycle Callbacks**: Before/after hooks for validation, save, create, update, and destroy
- **🗄️ Database Migrations**: Schema evolution tools for managing database changes
- **🔍 Flexible Querying**: Fluent query builder with complex joins and subqueries
- **💾 Transaction Support**: Full ACID transaction support with nested transactions (savepoints)
- **🔐 Optimistic Locking**: Built-in support for optimistic concurrency control
- **🎯 Query Scopes**: Reusable query scopes for common filtering patterns
- **🌐 Multi-Database**: Support for PostgreSQL, MySQL, and SQLite
- **🔑 Flexible Primary Keys**: Support for Int32, Int64, UUID, and ULID primary keys

## Supported Databases

- **PostgreSQL**: Full support with advanced features like JSONB and arrays
- **MySQL**: Complete MySQL support with proper dialect handling
- **SQLite**: Perfect for development, testing, and embedded applications

## Installation

Add CQL and your database driver to your `shard.yml`:

```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: "~> 0.0.266"

  # Choose your database driver:
  pg: # For PostgreSQL
    github: will/crystal-pg
  mysql: # For MySQL
    github: crystal-lang/crystal-mysql
  sqlite3: # For SQLite
    github: crystal-lang/crystal-sqlite3
```

Then install dependencies:

```bash
shards install
```

## Quick Start

### 1. Define Your Schema

```crystal
require "cql"
require "sqlite3"  # or "pg" or "mysql"

# Define your database schema
AppDB = CQL::Schema.define(
  :app_database,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://db/app.db"
) do
  table :users do
    primary :id, Int32
    column :name, String
    column :email, String
    column :active, Bool, default: true
    timestamps
  end

  table :posts do
    primary :id, Int32
    column :title, String
    column :body, String
    column :published, Bool, default: false
    column :user_id, Int32, null: true
    timestamps

    foreign_key [:user_id], references: :users, references_columns: [:id]
  end
end

# Create tables
AppDB.users.create!
AppDB.posts.create!
```

### 2. Create Models

```crystal
class User
  include CQL::ActiveRecord::Model(Int32)
  db_context AppDB, :users

  property id : Int32?
  property name : String
  property email : String
  property active : Bool = true
  property created_at : Time?
  property updated_at : Time?

  # Validations
  validate :name, presence: true, size: 2..50
  validate :email, required: true, match: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  # Relationships
  has_many :posts, Post, foreign_key: :user_id, dependent: :destroy

  def initialize(@name : String, @email : String)
  end
end

class Post
  include CQL::ActiveRecord::Model(Int32)
  db_context AppDB, :posts

  property id : Int32?
  property title : String
  property body : String
  property published : Bool = false
  property user_id : Int32?
  property created_at : Time?
  property updated_at : Time?

  # Validations
  validate :title, presence: true, size: 1..100
  validate :body, presence: true

  # Relationships
  belongs_to :user, User, :user_id, optional: true

  def initialize(@title : String, @body : String, @user_id : Int32? = nil)
  end
end
```

### 3. Work with Your Data

```crystal
# Create a new user
user = User.new("Alice Johnson", "alice@example.com")
if user.save
  puts "User created with ID: #{user.id}"
else
  puts "Validation errors: #{user.errors.map(&.message)}"
end

# Find users
alice = User.find_by(email: "alice@example.com")
all_active_users = User.where(active: true).all

# Create associated records
post = user.posts.create(title: "My First Post", body: "Hello, World!")

# Use transactions for complex operations
User.transaction do |tx|
  user = User.create!(name: "Bob", email: "bob@example.com")
  post = user.posts.create!(title: "Bob's Post", body: "Content here")

  # If anything fails, everything rolls back automatically
end

# Advanced querying
published_posts = Post.where(published: true)
                     .joins(:user)
                     .where(users: {active: true})
                     .order(created_at: :desc)
                     .limit(10)
                     .all
```

## Core Features

### Type-Safe Schema Definition

```crystal
AppDB = CQL::Schema.define(:app, adapter: CQL::Adapter::Postgres, uri: ENV["DATABASE_URL"]) do
  table :products do
    primary :id, UUID                    # UUID primary keys
    column :name, String
    column :price, Float64
    column :metadata, JSON::Any          # JSON columns
    column :tags, Array(String)          # Array columns (PostgreSQL)
    timestamps

    index :name, unique: true
    index [:price, :created_at]          # Composite indexes
  end
end
```

### Active Record Pattern

```crystal
class Product
  include CQL::ActiveRecord::Model(UUID)
  db_context AppDB, :products

  property id : UUID?
  property name : String
  property price : Float64
  property metadata : JSON::Any
  property created_at : Time?
  property updated_at : Time?

  def initialize(@name : String, @price : Float64, @metadata = JSON::Any.new({}))
  end
end

# Create
product = Product.create!(name: "Laptop", price: 999.99)

# Read
product = Product.find(product.id)
products = Product.where("price < ?", 1000).order(:name).all

# Update
product.price = 899.99
product.save!

# Delete
product.destroy!
```

### Comprehensive Validations

```crystal
class User
  include CQL::ActiveRecord::Model(Int32)

  # Built-in validations
  validate :name, presence: true, size: 2..50
  validate :email, required: true, match: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  validate :age, gt: 0, lt: 120
  validate :role, in: ["user", "admin", "moderator"]

  # Custom validations
  use CustomPasswordValidator
end

# Check validity
user = User.new("", "invalid-email", -5)
unless user.valid?
  user.errors.each { |error| puts "#{error.field}: #{error.message}" }
end
```

### Powerful Relationships

```crystal
class User
  has_one :profile, UserProfile, dependent: :destroy
  has_many :posts, Post, foreign_key: :author_id
  has_many :comments, Comment, dependent: :destroy
end

class Post
  belongs_to :author, User, :author_id
  has_many :comments, Comment, dependent: :destroy
  many_to_many :tags, Tag, join_through: :post_tags
end

# Work with associations
user = User.find(1)
user.posts.create(title: "New Post", body: "Content")
user.posts.where(published: true).count
user.profile.update!(bio: "Updated bio")
```

### Database Transactions

```crystal
# Simple transactions
User.transaction do |tx|
  user = User.create!(name: "John", email: "john@example.com")
  user.posts.create!(title: "First Post", body: "Hello!")

  # Automatic rollback on exceptions
  raise "Error!" if some_condition  # Everything rolls back
end

# Nested transactions (savepoints)
User.transaction do |outer_tx|
  user = User.create!(name: "Alice", email: "alice@example.com")

  User.transaction(outer_tx) do |inner_tx|
    # This can be rolled back independently
    risky_operation()
  rescue
    inner_tx.rollback  # Only inner transaction rolls back
  end
end
```

### Schema Migrations

```crystal
class CreateUsersTable < CQL::Migration(20240101120000)
  def up
    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end

class AddEmailToUsers < CQL::Migration(20240102120000)
  def up
    schema.alter :users do
      add_column :email, String
      create_index :idx_users_email, [:email], unique: true
    end
  end

  def down
    schema.alter :users do
      drop_index :idx_users_email
      drop_column :email
    end
  end
end

# Run migrations
migrator = CQL::Migrator.new(AppDB)
migrator.up           # Apply all pending migrations
migrator.down(1)      # Rollback last migration
migrator.print_applied_migrations  # Show status
```

### Query Scopes

```crystal
class Post
  scope :published, ->{ where(published: true) }
  scope :recent, ->{ where("created_at > ?", 1.week.ago).order(created_at: :desc) }
  scope :by_author, ->(author_id : Int32) { where(author_id: author_id) }
end

# Use scopes
recent_posts = Post.published.recent.limit(10).all
author_posts = Post.by_author(user.id).published.all
```

## Advanced Features

- **Optimistic Locking**: Prevent concurrent update conflicts
- **Callbacks**: `before_save`, `after_create`, `before_destroy`, etc.
- **Query Caching**: Automatic query result caching
- **Connection Pooling**: Efficient database connection management
- **Multi-Database**: Work with multiple databases simultaneously
- **Raw SQL**: Execute raw SQL when needed with full type safety
- **Database Introspection**: Runtime schema inspection capabilities

## Documentation

Comprehensive documentation is available at:

**📚 [CQL Documentation](https://azutopia.gitbook.io/cql/)**

### Quick Links

- [Installation Guide](https://azutopia.gitbook.io/cql/installation)
- [Getting Started](https://azutopia.gitbook.io/cql/guides/getting-started)
- [Schema Definition](https://azutopia.gitbook.io/cql/core-concepts/schemas)
- [Active Record Models](https://azutopia.gitbook.io/cql/guides/active-record-with-cql/defining-models)
- [Validations](https://azutopia.gitbook.io/cql/guides/active-record-with-cql/validations)
- [Relationships](https://azutopia.gitbook.io/cql/guides/active-record-with-cql/relations)
- [Transactions](https://azutopia.gitbook.io/cql/guides/active-record-with-cql/transactions)
- [Migrations](https://azutopia.gitbook.io/cql/guides/active-record-with-cql/migrations)

## Development

### Running Tests

```bash
# Start PostgreSQL
docker run --rm -e POSTGRES_DB=spec -e POSTGRES_PASSWORD=password -p 5432:5432 postgres

# Run tests
DATABASE_URL="postgres://postgres:password@localhost:5432/spec" crystal spec

# Run with SQLite (default)
crystal spec
```

### Database Support

CQL is tested against:

- PostgreSQL 12+
- MySQL 8.0+
- SQLite 3.35+

## Contributing

We welcome contributions! Here's how to get started:

1. **Fork** the repository
2. **Create** your feature branch: `git checkout -b my-new-feature`
3. **Make** your changes and add tests
4. **Run** the test suite: `crystal spec`
5. **Commit** your changes: `git commit -am 'Add some feature'`
6. **Push** to your branch: `git push origin my-new-feature`
7. **Create** a Pull Request

### Development Guidelines

- Follow Crystal coding conventions
- Add tests for new features
- Update documentation for API changes
- Ensure all tests pass across all supported databases

## License

CQL is released under the [MIT License](./LICENSE).

---

**Built with ❤️ for the Crystal community**

CQL provides the productivity of modern ORMs with the performance and type safety of Crystal. Whether you're building a simple web application or a complex enterprise system, CQL gives you the tools to work with your data efficiently and safely.
