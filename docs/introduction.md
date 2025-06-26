---
icon: arrow-right-to-arc
---

# Introduction to CQL

> **Crystal Query Language** - A powerful, type-safe ORM that brings the elegance of Crystal to database interactions

Welcome to **CQL (Crystal Query Language)** - the modern Object-Relational Mapping library designed specifically for Crystal developers who demand both performance and developer experience. CQL bridges the gap between raw SQL power and Crystal's compile-time safety, giving you the best of both worlds.

## What is CQL?

CQL is a **type-safe, high-performance ORM** that leverages Crystal's static type system and macro capabilities to provide:

- **Compile-time Safety** - Catch errors before they reach production
- **High Performance** - Zero-cost abstractions with macro-generated code
- **Developer Experience** - Intuitive API that feels natural to Crystal developers
- **Flexibility** - Support for multiple patterns (Active Record, Repository, Data Mapper)
- **Multi-Database** - Works seamlessly with PostgreSQL, MySQL, and SQLite

```crystal
# Clean, type-safe database interactions
user = User.create!(
  name: "Alice Johnson",
  email: "alice@example.com",
  age: 28
)

# Powerful query building with compile-time safety
active_users = User
  .where(active: true)
  .where { age >= 18 }
  .order(created_at: :desc)
  .limit(10)
  .all
```

## Key Features

### Type-Safe ORM

Leverages Crystal's static type system for compile-time safety, eliminating common runtime database errors.

```crystal
# Compile-time error if column doesn't exist
user = User.where(nam: "Alice")  # Error: no such column 'nam'

# Type-safe attribute access
user.age.class  # => Int32 (guaranteed!)
```

### Macro-Powered DSL

Uses Crystal's powerful macro system for clean, declarative model definitions.

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context UserDB, :users

  property id : Int64?
  property name : String
  property email : String
  property active : Bool = true

  validates :email, presence: true, format: EMAIL_REGEX
  has_many :posts, Post
end
```

### Multi-Database Support

Single codebase, multiple databases - switch between PostgreSQL, MySQL, and SQLite without code changes.

```crystal
# PostgreSQL for production
ProductionDB = CQL::Schema.define(
  :production,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
)

# SQLite for development/testing
DevelopmentDB = CQL::Schema.define(
  :development,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://./db/development.db"
)
```

### Multiple Design Patterns

**Active Record Pattern** - For domain-rich applications:

```crystal
user = User.new(name: "Bob")
user.save!
user.posts.create!(title: "My First Post")
```

**Repository Pattern** - For data-centric architectures:

```crystal
users = CQL::Repository(User, Int64).new(MyDB, :users)
user_id = users.create(name: "Carol", email: "carol@example.com")
user = users.find!(user_id)
```

### Advanced Relationships

Rich association system with lazy and eager loading capabilities.

```crystal
# Define relationships
class User
  has_many :posts, Post
  has_one :profile, UserProfile
end

class Post
  belongs_to :user, User
  has_many :comments, Comment
end

# Use with ease
user.posts.where(published: true).count
post.comments.join(:user).all  # Eager loading
```

### Comprehensive Validations

Built-in validation system with custom validator support.

```crystal
struct User
  validates :name, presence: true, length: {minimum: 2, maximum: 50}
  validates :email, presence: true, format: EMAIL_REGEX, uniqueness: true
  validates :age, numericality: {greater_than: 0, less_than: 150}
end
```

### Database Migrations

Version-controlled schema evolution with reversible migrations.

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

## Use Cases

### Web Applications

Build fast, scalable web applications with type-safe database interactions.

### APIs and Microservices

Create robust APIs with automatic serialization and validation.

### Data-Intensive Applications

Handle complex queries, aggregations, and reporting with ease.

### Development & Testing

SQLite support makes CQL perfect for development environments and fast test suites.

## Getting Started

Ready to dive in? Here's how to get started with CQL:

### 1. Installation

Add CQL to your `shard.yml`:

```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: "~> 1.0"
```

### 2. Quick Setup

```crystal
require "cql"

# Define your database schema
UserDB = CQL::Schema.define(
  :userdb,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://./users.db"
) do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String
    column :email, String
    column :active, Bool, default: true
    timestamps
  end
end

# Define your model
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context UserDB, :users

  property id : Int64?
  property name : String
  property email : String
  property active : Bool = true
  property created_at : Time?
  property updated_at : Time?
end

# Build the database
UserDB.build

# Start using it!
user = User.create!(
  name: "Alice",
  email: "alice@example.com"
)
```

## Next Steps

Now that you understand what CQL is and what it offers, here's how to proceed:

### New to CQL? Start Here

1. **[Installation](installation.md)** - Get CQL running in your project
2. **[Core Concepts](core-concepts/README.md)** - Master the fundamentals
3. **[Getting Started](guides/getting-started.md)** - Build your first application
4. **[Active Record with CQL](guides/active-record-with-cql/README.md)** - Learn the most popular pattern

### Coming from Another ORM?

1. **[Feature Comparison](guides/feature-comparison.md)** - See how CQL compares
2. **[Migration Guide](guides/migration-guide.md)** - Transition smoothly
3. **[Architecture Overview](guides/architecture-overview.md)** - Understand the design
4. **[Best Practices](guides/best-practices.md)** - Follow proven patterns

### Ready to Build?

1. **[Configuration](guides/configuration.md)** - Set up for your environment
2. **[Examples](examples/README.md)** - See CQL in action
3. **[Performance Optimization](guides/performance-optimization.md)** - Make it fast
4. **[Security Guide](guides/security-guide.md)** - Keep it secure

---

> Built for Crystal developers, by Crystal developers - CQL brings together the performance and safety of Crystal with the power and flexibility of modern ORM design.

Ready to build something amazing? Let's get started!
