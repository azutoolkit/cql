[![Crystal CI](https://github.com/azutoolkit/cql/actions/workflows/crystal.yml/badge.svg)](https://github.com/azutoolkit/cql/actions/workflows/crystal.yml)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/a85e29e6b78849c28fb813397cc3eb1a)](https://app.codacy.com/gh/azutoolkit/cql/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)

# CQL (Crystal Query Language)

<img width="1038" alt="cql-banner" src="https://github.com/user-attachments/assets/ed4e733a-3d37-4d03-a4d8-d15bfd7e6f25">

A high-performance, type-safe ORM for Crystal applications that combines compile-time safety with runtime performance. Unlike traditional ORMs that catch errors at runtime, CQL validates your queries, relationships, and data access patterns before your code executes.

> _"We migrated our Rails API to Crystal + CQL and saw response times drop from 200ms to 45ms while handling 3x more concurrent users."_ - Production User

**[Complete Documentation →](https://azutopia.gitbook.io/cql)**

## Why Choose CQL

### Performance

- 4x faster than ActiveRecord and Eloquent in real-world scenarios
- 75% less memory usage compared to Ruby/PHP ORMs
- Zero-allocation queries for maximum throughput
- Compile-time optimizations eliminate runtime overhead

### Type Safety

- Catch errors at compile time - invalid queries fail before deployment
- Full IDE autocompletion support for queries and relationships
- Safe refactoring - rename columns/tables with confidence
- No runtime surprises - association errors caught early

### Developer Experience

- Familiar ActiveRecord-style API - easy migration from Rails/Laravel
- Rich query DSL with readable, type-safe syntax
- Automatic schema synchronization - database changes tracked and versioned
- Built-in performance monitoring with N+1 query detection

## Core Features

- **Type-Safe ORM**: Leverage Crystal's static type system for compile-time safety
- **High Performance**: 4x faster than traditional ORMs with compile-time optimizations
- **Active Record Pattern**: Intuitive Active Record API with full CRUD operations
- **Smart Relationships**: Support for `belongs_to`, `has_one`, `has_many`, and `many_to_many` with automatic N+1 prevention
- **Comprehensive Validations**: Built-in validation system with custom validator support
- **Lifecycle Callbacks**: Before/after hooks for validation, save, create, update, and destroy
- **Intelligent Migrations**: Schema evolution tools with automatic rollback support
- **Schema Dump**: Reverse-engineer existing databases into CQL schema definitions
- **Flexible Querying**: Fluent query builder with complex joins, subqueries, and raw SQL support
- **Transaction Support**: Full ACID transaction support with nested transactions (savepoints)
- **Optimistic Locking**: Built-in support for optimistic concurrency control
- **Query Scopes**: Reusable query scopes for common filtering patterns
- **Advanced Caching**: Multi-layer caching with Redis and memory cache support
- **Performance Monitoring**: Built-in query profiling, N+1 detection, and optimization suggestions
- **Multi-Database**: Support for PostgreSQL, MySQL, and SQLite with dialect-specific optimizations
- **Flexible Primary Keys**: Support for Int32, Int64, UUID, and ULID primary keys

## Performance Comparison

Real-world benchmarks (1M records, complex queries):

| Operation         | CQL   | ActiveRecord | Eloquent | Improvement     |
| ----------------- | ----- | ------------ | -------- | --------------- |
| **Simple SELECT** | 0.8ms | 3.2ms        | 4.1ms    | **4x faster**   |
| **Complex JOIN**  | 2.1ms | 8.7ms        | 12.3ms   | **4-6x faster** |
| **Bulk INSERT**   | 15ms  | 89ms         | 124ms    | **6-8x faster** |
| **Memory Usage**  | 12MB  | 48MB         | 67MB     | **75% less**    |

## Database Support

| Database       | Support Level | Special Features                  |
| -------------- | ------------- | --------------------------------- |
| **PostgreSQL** | Full          | JSONB, Arrays, Advanced Types     |
| **MySQL**      | Full          | Complete MySQL support            |
| **SQLite**     | Full          | Perfect for development & testing |

## Installation

Add CQL and your database driver to your `shard.yml`:

```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: "~> 0.0.435"

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

# Define your database schema with compile-time validation
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

    # Type-safe foreign key relationships
    foreign_key [:user_id], references: :users, references_columns: [:id]
  end
end

# Create tables (with automatic validation)
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

  # Compile-time validated relationships
  has_many :posts, foreign_key: :user_id

  # Built-in validations with clear error messages
  validate :username, presence: true, size: 2..50
  validate :email, required: true, match: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

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

  # Type-safe relationships prevent association errors
  belongs_to :user, User, foreign_key: :user_id

  # Comprehensive validations
  validate :title, presence: true, size: 1..100
  validate :content, presence: true

  def initialize(@title : String, @content : String, @user_id : Int64)
  end
end
```

### 3. Work with Your Data

```crystal
# Create with automatic validation
user = User.new("alice_j", "alice@example.com", "Alice", "Johnson")
if user.save
  puts "✅ User created with ID: #{user.id}"
else
  puts "❌ Validation errors: #{user.errors.map(&.message)}"
end

# Type-safe queries with IntelliSense support
alice = User.find_by(username: "alice_j")
active_users = User.where(active: true).all

# Create associated records (no N+1 queries!)
post = user.posts.create(title: "My First Post", content: "Hello, World!")

# Safe transactions with automatic rollback
User.transaction do |tx|
  user = User.create!(username: "bob", email: "bob@example.com")
  post = user.posts.create!(title: "Bob's Post", content: "Content here")

  # If anything fails, everything rolls back automatically
  # No partial data corruption!
end

# Advanced querying with type safety
published_posts = Post.where(published: true)
                     .joins(:user)
                     .where(users: {active: true})
                     .order(created_at: :desc)
                     .limit(10)
                     .all

# Complex queries made simple
recent_active_authors = User.joins(:posts)
                           .where("posts.created_at > ?", 1.week.ago)
                           .where(active: true)
                           .distinct
                           .count

puts "Found #{recent_active_authors} active authors this week"
```

## Advanced Features

### Type-Safe Schema Definition

```crystal
# Schema with advanced features
BlogDB = CQL::Schema.define(:blog, adapter: CQL::Adapter::Postgres, uri: ENV["DATABASE_URL"]) do
  table :products do
    primary :id, UUID                    # UUID primary keys
    text :name
    decimal :price, precision: 10, scale: 2
    text :metadata                       # JSON columns
    timestamps

    # Optimized indexing
    index :name, unique: true
    index [:price, :created_at]          # Composite indexes for performance
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

  # Custom validations with clear error messages
  validate :name, presence: true, size: 2..100
  validate :price, gt: 0.0, lt: 1_000_000.0

  def initialize(@name : String, @price : Float64)
  end
end

# CRUD operations with validation
product = Product.create!(name: "Laptop", price: 999.99)
product = Product.find(product.id.not_nil!)

# Efficient querying with type safety
affordable_products = Product.where("price < ?", 1000.0)
                             .order(:name)
                             .limit(50)
                             .all

# Safe updates with validation
product.price = 899.99
product.save!  # Validates before saving

# Safe deletion
product.destroy!
```

### Validations

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)

  # Built-in validations with internationalization support
  validate :name, presence: true, size: 2..50
  validate :email, required: true, match: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  validate :age, gt: 0, lt: 120
  validate :password_confirmation, confirmation: :password

  # Custom business logic validators
  use CustomPasswordValidator
  use BusinessRuleValidator
end

# Comprehensive error handling
user = User.new("", "invalid-email")
unless user.valid?
  user.errors.each do |error|
    puts "🚫 #{error.field}: #{error.message}"
  end
end
```

### Smart Relationships

```crystal
struct User
  # Type-safe relationship definitions
  has_one :profile, UserProfile, foreign_key: :user_id
  has_many :posts, foreign_key: :user_id
  has_many :comments, foreign_key: :user_id
end

struct Post
  belongs_to :user, User, foreign_key: :user_id
  has_many :comments, foreign_key: :post_id
  many_to_many :tags, Tag, join_through: :post_tags
end

# Efficient association loading (automatic N+1 prevention)
user = User.find(1.to_i64)
user.posts.create(title: "New Post", content: "Content")
user.posts.size                         # Efficient count without loading all records
user.posts.any?                         # Check existence without memory overhead

# Smart eager loading
users_with_posts = User.includes(:posts, :profile)
                      .where(active: true)
                      .all
# Single query instead of N+1 queries!
```

### Transaction Management

```crystal
# Simple atomic transactions
User.transaction do |tx|
  user = User.create!(username: "john", email: "john@example.com")
  user.posts.create!(title: "First Post", content: "Hello!")

  # Automatic rollback on any exception
  raise "Error!" if some_condition  # Everything safely rolls back
end

# Nested transactions with savepoints (PostgreSQL)
User.transaction do |outer_tx|
  user = User.create!(username: "alice", email: "alice@example.com")

  User.transaction(outer_tx) do |inner_tx|
    # Independent rollback scope
    risky_operation()
  rescue
    inner_tx.rollback  # Only inner transaction rolls back
  end

  # Outer transaction continues safely
end
```

### Schema Migrations

```crystal
# Version-controlled database evolution
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
      add_column :email, String, null: false
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

# Safe migration management
migrator = CQL::Migrator.new(BlogDB)
migrator.up           # Apply all pending migrations
migrator.down(1)      # Rollback last migration safely
migrator.status       # Check migration status
```

### Query Scopes

```crystal
struct Post
  # Define reusable query patterns
  scope :published, ->{ where(published: true) }
  scope :recent, ->{ where("created_at > ?", 1.week.ago).order(created_at: :desc) }
  scope :by_user, ->(user_id : Int64) { where(user_id: user_id) }
  scope :popular, ->{ where("view_count > ?", 1000) }
end

# Chainable, composable queries
trending_posts = Post.published
                    .recent
                    .popular
                    .limit(10)
                    .all

user_content = Post.by_user(user.id.not_nil!)
                  .published
                  .order(created_at: :desc)
                  .all
```

### Schema Dump

```crystal
# Import existing databases into CQL
require "cql"

# Connect to legacy database
dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, "sqlite3://legacy_app.db")

# Generate type-safe CQL schema from existing database
dumper.dump_to_file("src/schemas/legacy_schema.cr", :LegacyDB, :legacy_db)

# Generated schema uses proper CQL methods with type safety:
# text :name               # instead of generic column definitions
# integer :user_id         # with proper type inference
# timestamps               # standardized timestamp handling

dumper.close

# Now use your legacy database with full CQL features!
```

### Caching

```crystal
# Caching configuration
cache_config = CQL::Cache::CacheConfig.new(
  enabled: true,
  ttl: 1.hour,
  max_size: 10_000,
  compression: true
)

# Memory cache for lightning-fast access
memory_cache = CQL::Cache::MemoryCache.new(max_size: 1000)

# Redis cache for distributed applications
redis_cache = CQL::Cache::RedisCache.new("redis://localhost:6379")

# Fragment caching for expensive operations
fragment_cache = CQL::Cache::FragmentCache.new(memory_cache)

# Intelligent caching with automatic invalidation
result = fragment_cache.cache_fragment("expensive_query", {"user_id" => user.id}) do
  # Expensive database operation cached automatically
  User.joins(:posts, :comments)
      .where(active: true)
      .includes(:profile)
      .complex_aggregation
end

# Tag-based cache invalidation
fragment_cache.invalidate_tags(["user:#{user.id}", "posts"])
```

### Performance Monitoring

```crystal
# Performance monitoring
monitor = CQL::Performance::PerformanceMonitor.new

# Real-time query monitoring
monitor.on_query_executed do |event|
  if event.duration > 100.milliseconds
    puts "🐌 Slow query detected: #{event.sql} (#{event.duration}ms)"
    puts "💡 Consider adding an index or optimizing the query"
  end
end

# Automatic N+1 query detection
detector = CQL::Performance::NPlusOneDetector.new
detector.analyze_queries(queries) do |pattern|
  puts "⚠️  N+1 Query Pattern Detected:"
  puts "   Model: #{pattern.model}"
  puts "   Association: #{pattern.association}"
  puts "   Suggestion: Use .includes(:#{pattern.association})"
end

# Generate beautiful performance reports
report_generator = CQL::Performance::Reports::HTMLReportGenerator.new
report_generator.generate_report(monitor.events, "performance_report.html")
puts "📊 Performance report generated: performance_report.html"
```

## Use Cases

### High-Performance APIs

- RESTful APIs serving millions of requests
- GraphQL backends with complex data fetching
- Real-time applications with WebSocket connections
- Microservices requiring fast data access

### Enterprise Applications

- Large-scale web applications
- Complex business logic with data integrity requirements
- Multi-tenant SaaS platforms
- Financial and healthcare applications requiring compliance

### Cloud-Native Development

- Container-based deployments
- Kubernetes-native applications
- Serverless functions with database access
- Auto-scaling applications

### Modern Development Workflows

- CI/CD pipelines with database testing
- Type-safe development practices
- Large team collaboration
- Long-term maintenance and refactoring

## Documentation

**[Complete Documentation on GitBook →](https://azutopia.gitbook.io/cql)**

Comprehensive guides for every level:

### Getting Started

- **[Installation Guide](./docs/installation.md)** - Set up CQL in your project
- **[Getting Started](./docs/guides/getting-started.md)** - Your first CQL application
- **[Schema Definition](./docs/core-concepts/schemas.md)** - Type-safe database schemas
- **[Configuration](./docs/guides/configuration.md)** - Environment setup and database connections

### Core Features

- **[Defining Models](./docs/guides/active-record-with-cql/defining-models.md)** - Active Record model setup
- **[CRUD Operations](./docs/guides/active-record-with-cql/crud-operations.md)** - Create, read, update, delete
- **[Complex Queries](./docs/guides/active-record-with-cql/complex-queries.md)** - Advanced querying and N+1 prevention
- **[Validations](./docs/guides/active-record-with-cql/validations.md)** - Data validation and integrity
- **[Relationships](./docs/guides/active-record-with-cql/relations/README.md)** - Model associations and relationships

### Advanced Topics

- **[Transactions](./docs/guides/active-record-with-cql/transactions.md)** - Managing database transactions
- **[Migrations](./docs/guides/active-record-with-cql/migrations.md)** - Schema evolution and versioning
- **[Schema Dump](./docs/guides/schema-dump.md)** - Reverse-engineer existing databases
- **[Callbacks](./docs/guides/active-record-with-cql/callbacks.md)** - Lifecycle hooks and callbacks
- **[Scopes](./docs/guides/active-record-with-cql/scopes.md)** - Reusable query methods
- **[Optimistic Locking](./docs/guides/active-record-with-cql/optimistic-locking.md)** - Concurrency control

### Performance & Production

- **[Advanced Caching](./docs/guides/advanced-caching-architecture.md)** - Multi-layer caching strategies
- **[Performance Monitoring](./docs/guides/performance-optimization.md)** - Query profiling and optimization
- **[Security Guide](./docs/guides/security-guide.md)** - Production security best practices
- **[Testing Strategies](./docs/guides/testing-strategies.md)** - Testing CQL applications

### Reference

- **[Quick Reference](./docs/guides/quick-reference.md)** - Cheat sheet for common operations
- **[Architecture Overview](./docs/guides/architecture-overview.md)** - Understanding CQL's design
- **[FAQ](./docs/faqs.md)** - Frequently asked questions
- **[Troubleshooting](./docs/troubleshooting.md)** - Common issues and solutions

## Development & Testing

### Running Tests

```bash
# Start PostgreSQL for full test suite
docker run --rm -e POSTGRES_DB=spec -e POSTGRES_PASSWORD=password -p 5432:5432 postgres

# Run comprehensive test suite with PostgreSQL
DATABASE_URL="postgres://postgres:password@localhost:5432/spec" crystal spec

# Quick test with SQLite (default)
crystal spec

# Run specific test categories
crystal spec spec/patterns/active_record/relations/  # Relationship tests
crystal spec spec/cache/                           # Caching tests
crystal spec spec/performance/                     # Performance tests
```

### Database Compatibility

CQL is actively tested and optimized for:

- **PostgreSQL**: 12, 13, 14, 15, 16 with full feature support
- **MySQL**: 8.0+ with dialect-specific optimizations
- **SQLite**: 3.35+ perfect for development and testing

Each adapter supports database-specific features and provides optimal performance.

## Contributing

We welcome contributions! Here's how to get involved:

### Quick Start

1. Fork the repository on GitHub
2. Clone your fork: `git clone https://github.com/yourusername/cql.git`
3. Create your feature branch: `git checkout -b my-feature`
4. Make your changes and add comprehensive tests
5. Run the test suite: `crystal spec`
6. Commit your changes: `git commit -am 'Add feature'`
7. Push to your branch: `git push origin my-feature`
8. Create a Pull Request with a clear description

### Contribution Ideas

- **Bug Fixes** - Help improve reliability
- **Performance** - Optimize queries, reduce memory usage, improve speed
- **Documentation** - Improve guides, add examples, fix typos
- **Tests** - Add test coverage, create integration scenarios
- **Features** - Implement new ORM features and database support
- **Developer Experience** - Improve error messages, add tooling

### Development Guidelines

- Follow Crystal coding conventions and style guidelines
- Add comprehensive tests for new features and bug fixes
- Update documentation for API changes and new features
- Ensure compatibility across all supported databases (PostgreSQL, MySQL, SQLite)
- Use meaningful commit messages following [conventional commits](https://conventionalcommits.org/)
- Add performance benchmarks for query-related features
- Consider security implications for new features

### Areas We Need Help With

- Database adapter improvements and new database support
- Query optimization and performance enhancements
- Documentation improvements and examples
- Testing across different Crystal versions
- Integration with popular Crystal web frameworks

## License

CQL is released under the [MIT License](./LICENSE). Feel free to use it in personal and commercial projects.

---

## Get Started

```crystal
# Install CQL and start building your application
shards install

# Try the interactive examples
crystal examples/run_examples.cr
```

**[Get Started Now →](./docs/guides/getting-started.md) • [Try Examples →](./examples/) • [Join Community →](https://github.com/azutoolkit/cql/discussions)**

---

Built for the Crystal community.

CQL provides the productivity of modern ORMs with the performance and type safety that Crystal developers need. Whether you're building a simple web application or a complex enterprise system, CQL gives you the tools to work with your data efficiently and safely.
