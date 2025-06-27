[![Crystal CI](https://github.com/azutoolkit/cql/actions/workflows/crystal.yml/badge.svg)](https://github.com/azutoolkit/cql/actions/workflows/crystal.yml)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/a85e29e6b78849c28fb813397cc3eb1a)](https://app.codacy.com/gh/azutoolkit/cql/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)

# CQL (Crystal Query Language)

<img width="1038" alt="cql-banner" src="https://github.com/user-attachments/assets/ed4e733a-3d37-4d03-a4d8-d15bfd7e6f25">

CQL is a powerful Object-Relational Mapping (ORM) library for the Crystal programming language. It provides a type-safe, high-performance interface for interacting with SQL databases, combining the flexibility of raw SQL with the safety and clarity of Crystal's static type system.

## Features

- **🔒 Type-Safe ORM**: Leverage Crystal's static type system for compile-time safety
- **⚡ High Performance**: Compile-time optimizations for excellent runtime performance
- **🏗️ Active Record Pattern**: Intuitive Active Record API with full CRUD operations
- **🔗 Advanced Relationships**: Support for `belongs_to`, `has_one`, `has_many`, and `many_to_many` associations
- **✅ Comprehensive Validations**: Built-in validation system with custom validator support
- **🔄 Lifecycle Callbacks**: Before/after hooks for validation, save, create, update, and destroy
- **🗄️ Database Migrations**: Schema evolution tools for managing database changes
- **📋 Schema Dump**: Reverse-engineer existing databases into CQL schema definitions
- **🔍 Flexible Querying**: Fluent query builder with complex joins and subqueries
- **💾 Transaction Support**: Full ACID transaction support with nested transactions (savepoints)
- **🔐 Optimistic Locking**: Built-in support for optimistic concurrency control
- **🎯 Query Scopes**: Reusable query scopes for common filtering patterns
- **🚀 Advanced Caching**: Multi-layer caching with Redis and memory cache support
- **📊 Performance Monitoring**: Built-in query profiling and N+1 detection
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
    version: "~> 0.0.374"

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
BlogDB = CQL::Schema.define(
  :blog_database,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://db/blog.db"
) do
  table :users do
    primary :id, Int64
    text :username
    text :email
    text :first_name, null: true
    text :last_name, null: true
    boolean :active, default: "1"
    timestamps
  end

  table :posts do
    primary :id, Int64
    text :title
    text :content
    boolean :published, default: "0"
    bigint :user_id
    timestamps

    foreign_key [:user_id], references: :users, references_columns: [:id]
  end
end

# Create tables
BlogDB.users.create!
BlogDB.posts.create!
```

### 2. Create Models

```crystal
struct User
  getter id : Int64?
  getter username : String
  getter email : String
  getter first_name : String?
  getter last_name : String?
  getter? active : Bool = true
  getter created_at : Time?
  getter updated_at : Time?

  # Validations
  validate :username, presence: true, size: 2..50
  validate :email, required: true, match: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  # Relationships
  has_many :posts, Post, foreign_key: :user_id

  def initialize(@username : String, @email : String,
                 @first_name : String? = nil, @last_name : String? = nil)
  end

  def full_name
    if first_name && last_name
      "#{first_name} #{last_name}"
    else
      username
    end
  end
end

struct Post
  getter id : Int64?
  getter title : String
  getter content : String
  getter? published : Bool = false
  getter user_id : Int64
  getter created_at : Time?
  getter updated_at : Time?

  # Validations
  validate :title, presence: true, size: 1..100
  validate :content, presence: true

  # Relationships
  belongs_to :user, User, :user_id

  def initialize(@title : String, @content : String, @user_id : Int64)
  end
end
```

### 3. Work with Your Data

```crystal
# Create a new user
user = User.new("alice_j", "alice@example.com", "Alice", "Johnson")
if user.save
  puts "User created with ID: #{user.id}"
else
  puts "Validation errors: #{user.errors.map(&.message)}"
end

# Find users
alice = User.find_by(username: "alice_j")
active_users = User.where(active: true).all

# Create associated records
post = user.posts.create(title: "My First Post", content: "Hello, World!")

# Use transactions for complex operations
User.transaction do |tx|
  user = User.create!(username: "bob", email: "bob@example.com")
  post = user.posts.create!(title: "Bob's Post", content: "Content here")

  # If anything fails, everything rolls back automatically
end

# Advanced querying with joins
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
BlogDB = CQL::Schema.define(:blog, adapter: CQL::Adapter::Postgres, uri: ENV["DATABASE_URL"]) do
  table :products do
    primary :id, UUID                    # UUID primary keys
    text :name
    decimal :price
    text :metadata                       # JSON columns
    timestamps

    index :name, unique: true
    index [:price, :created_at]          # Composite indexes
  end
end
```

### Active Record Pattern

```crystal
struct Product
  include CQL::ActiveRecord::Model(UUID)
  db_context BlogDB, :products

  getter id : UUID?
  getter name : String
  getter price : Float64
  getter created_at : Time?
  getter updated_at : Time?

  def initialize(@name : String, @price : Float64)
  end
end

# Create
product = Product.create!(name: "Laptop", price: 999.99)

# Read
product = Product.find(product.id.not_nil!)
products = Product.where("price < ?", 1000.0).order(:name).all

# Update
product.price = 899.99
product.save!

# Delete
product.destroy!
```

### Comprehensive Validations

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)

  # Built-in validations
  validate :name, presence: true, size: 2..50
  validate :email, required: true, match: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  validate :age, gt: 0, lt: 120
  validate :password_confirmation, confirmation: :password

  # Custom validators
  use CustomPasswordValidator
end

# Check validity
user = User.new("", "invalid-email")
unless user.valid?
  user.errors.each { |error| puts "#{error.field}: #{error.message}" }
end
```

### Powerful Relationships

```crystal
struct User
  has_one :profile, UserProfile
  has_many :posts, Post, foreign_key: :user_id
  has_many :comments, Comment
end

struct Post
  belongs_to :user, User, :user_id
  has_many :comments, Comment
  many_to_many :tags, Tag, join_through: :post_tags
end

# Work with associations efficiently (avoids N+1 queries)
user = User.find(1.to_i64)
user.posts.create(title: "New Post", content: "Content")
user.posts.size                         # Efficient count without loading
user.posts.any?                         # Check existence without loading
```

### Database Transactions

```crystal
# Simple transactions
User.transaction do |tx|
  user = User.create!(username: "john", email: "john@example.com")
  user.posts.create!(title: "First Post", content: "Hello!")

  # Automatic rollback on exceptions
  raise "Error!" if some_condition  # Everything rolls back
end

# Nested transactions (savepoints)
User.transaction do |outer_tx|
  user = User.create!(username: "alice", email: "alice@example.com")

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
migrator = CQL::Migrator.new(BlogDB)
migrator.up           # Apply all pending migrations
migrator.down(1)      # Rollback last migration
```

### Query Scopes

```crystal
struct Post
  scope :published, ->{ where(published: true) }
  scope :recent, ->{ where("created_at > ?", 1.week.ago).order(created_at: :desc) }
  scope :by_user, ->(user_id : Int64) { where(user_id: user_id) }
end

# Use scopes
recent_posts = Post.published.recent.limit(10).all
user_posts = Post.by_user(user.id.not_nil!).published.all
```

### Schema Dump

```crystal
# Reverse-engineer existing databases into CQL schemas
require "cql"

# Connect to existing database
dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, "sqlite3://legacy_app.db")

# Generate CQL schema from existing database
dumper.dump_to_file("src/schemas/legacy_schema.cr", :LegacyDB, :legacy_db)

# Generated schema uses proper CQL methods:
# text :name               # instead of column :name, String
# integer :user_id         # instead of column :user_id, Int32
# timestamps               # instead of individual created_at/updated_at

dumper.close
```

### Advanced Caching

```crystal
# Configure multi-layer caching
cache_config = CQL::Cache::CacheConfig.new(
  enabled: true,
  ttl: 1.hour,
  max_size: 10_000
)

# Memory cache for high-speed access
memory_cache = CQL::Cache::MemoryCache.new(max_size: 1000)

# Redis cache for distributed applications
redis_cache = CQL::Cache::RedisCache.new("redis://localhost:6379")

# Fragment caching for expensive operations
fragment_cache = CQL::Cache::FragmentCache.new(memory_cache)

result = fragment_cache.cache_fragment("expensive_query", {"user_id" => user.id}) do
  # Expensive database operation
  User.joins(:posts).where(active: true).complex_calculation
end

# Tag-based invalidation
fragment_cache.invalidate_tags(["user:#{user.id}"])
```

### Performance Monitoring

```crystal
# Enable performance monitoring
monitor = CQL::Performance::PerformanceMonitor.new

# Monitor query execution
monitor.on_query_executed do |event|
  if event.duration > 100.milliseconds
    puts "Slow query detected: #{event.sql} (#{event.duration}ms)"
  end
end

# N+1 query detection
detector = CQL::Performance::NPlusOneDetector.new
detector.analyze_queries(queries) # Automatically detects N+1 patterns

# Generate performance reports
report_generator = CQL::Performance::Reports::HTMLReportGenerator.new
report_generator.generate_report(monitor.events, "performance_report.html")
```

## Documentation

The complete documentation is available in the [docs](./docs) directory:

### Quick Links

- **[Installation Guide](./docs/installation.md)** - Setting up CQL in your project
- **[Introduction](./docs/introduction.md)** - Core concepts and philosophy
- **[Getting Started](./docs/guides/getting-started.md)** - Your first CQL application
- **[Schema Definition](./docs/core-concepts/schemas.md)** - Defining database schemas
- **[Defining Models](./docs/guides/active-record-with-cql/defining-models.md)** - Active Record model setup
- **[CRUD Operations](./docs/guides/active-record-with-cql/crud-operations.md)** - Create, read, update, delete
- **[Complex Queries](./docs/guides/active-record-with-cql/complex-queries.md)** - Advanced querying and N+1 prevention
- **[Validations](./docs/guides/active-record-with-cql/validations.md)** - Data validation and integrity
- **[Relationships](./docs/guides/active-record-with-cql/relations/README.md)** - Model associations and relationships
- **[Transactions](./docs/guides/active-record-with-cql/transactions.md)** - Managing database transactions
- **[Migrations](./docs/guides/active-record-with-cql/migrations.md)** - Schema evolution and versioning
- **[Schema Dump](./docs/guides/schema-dump.md)** - Reverse-engineer database schemas from existing databases
- **[Callbacks](./docs/guides/active-record-with-cql/callbacks.md)** - Lifecycle hooks and callbacks
- **[Scopes](./docs/guides/active-record-with-cql/scopes.md)** - Reusable query methods
- **[Optimistic Locking](./docs/guides/active-record-with-cql/optimistic-locking.md)** - Concurrency control
- **[Advanced Caching](./docs/guides/advanced-caching-architecture.md)** - Multi-layer caching strategies
- **[Performance Monitoring](./docs/guides/performance-optimization.md)** - Query profiling and optimization
- **[Core Concepts](./docs/core-concepts/README.md)** - Understanding CQL's architecture
- **[Patterns](./docs/core-concepts/patterns/README.md)** - Active Record, Repository, and more
- **[Troubleshooting](./docs/troubleshooting.md)** - Common issues and solutions

## Development

### Running Tests

```bash
# Start PostgreSQL for full test suite
docker run --rm -e POSTGRES_DB=spec -e POSTGRES_PASSWORD=password -p 5432:5432 postgres

# Run tests with PostgreSQL
DATABASE_URL="postgres://postgres:password@localhost:5432/spec" crystal spec

# Run with SQLite (default)
crystal spec

# Run specific test files
crystal spec spec/patterns/active_record/relations/
crystal spec spec/cache/
```

### Database Support

CQL is actively tested against:

- **PostgreSQL**: 12, 13, 14, 15, 16
- **MySQL**: 8.0+
- **SQLite**: 3.35+

Each database adapter supports dialect-specific features and optimizations.

## Contributing

We welcome contributions! Here's how to get started:

1. **Fork** the repository
2. **Create** your feature branch: `git checkout -b my-new-feature`
3. **Make** your changes and add comprehensive tests
4. **Run** the test suite: `crystal spec`
5. **Update** documentation for any API changes
6. **Commit** your changes: `git commit -am 'Add some feature'`
7. **Push** to your branch: `git push origin my-new-feature`
8. **Create** a Pull Request

### Development Guidelines

- Follow Crystal coding conventions and style guidelines
- Add comprehensive tests for new features and bug fixes
- Update documentation for API changes and new features
- Ensure all tests pass across all supported databases
- Use meaningful commit messages following conventional commits
- Add performance tests for query-related features

## License

CQL is released under the [MIT License](./LICENSE).

---

**Built with ❤️ for the Crystal community**

CQL provides the productivity of modern ORMs with the performance and type safety of Crystal. Whether you're building a simple web application or a complex enterprise system, CQL gives you the tools to work with your data efficiently and safely.
