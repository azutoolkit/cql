---
icon: database
---

# 🚀 CQL (Crystal Query Language)

**The High-Performance, Type-Safe ORM for Crystal**

_Build fast, reliable database applications with compile-time safety and exceptional performance._

[![Type Safety](https://img.shields.io/badge/Type_Safety-Compile_Time-blue)](#-type-safety-at-compile-time) [![Database Support](https://img.shields.io/badge/Databases-PostgreSQL%20%7C%20MySQL%20%7C%20SQLite-green)](#-database-support)

---

## ✨ What Makes CQL Special?

CQL brings **compile-time safety** and **performance optimization** to Crystal applications. Unlike traditional ORMs that check for errors at runtime, CQL validates your queries, relationships, and data access patterns **before your code even runs**.

```crystal
# Type-safe queries that catch errors at compile time ✅
users = User.where(active: true)      # ✅ Type checked
           .order(created_at: :desc)  # ✅ Validates column exists
           .limit(10)                 # ✅ Validates parameter type
           .all

# This would fail at COMPILE TIME, not runtime:
# User.where(nonexistent: true)      # ❌ Compile error!
# User.where(age: "invalid")         # ❌ Type mismatch caught early!
```

---

## 🎯 Key Features & Benefits

### ⚡ **Performance Optimized**

- **Zero-allocation Queries** through Crystal's compile-time optimizations
- **Connection Pooling** built-in for high-concurrency applications
- **Query Caching** with multiple cache backends (Memory, Redis)
- **N+1 Query Detection** and performance monitoring tools

### 🔒 **Type Safety at Compile Time**

- **Catch Bugs Early** - Invalid queries fail at compile time
- **IDE Support** - Full autocompletion and refactoring
- **Relationship Safety** - No more runtime association errors
- **Query Validation** - SQL structure validated before deployment

### 🏗️ **Developer Experience**

- **ActiveRecord-style API** - Familiar patterns for Rails developers
- **Automatic Schema Management** - Migrations with rollback support
- **Rich Query DSL** - Expressive and readable database queries
- **Built-in Validations** - Data integrity without boilerplate

### 🌐 **Production Ready**

- **PostgreSQL, MySQL, SQLite** support through Crystal DB drivers
- **Transaction Management** with rollback safety
- **Performance Monitoring** and query analysis tools
- **Multiple Design Patterns** - Active Record, Repository, Data Mapper support

---

## 🚀 Quick Start

Get up and running in **under 5 minutes**:

### 🎯 **Try CQL Interactively**

**Explore CQL features with our interactive examples runner:**

```bash
# Clone the repository
git clone https://github.com/azutoolkit/cql
cd cql

# Run the interactive examples
crystal examples/run_examples.cr
```

**Choose from organized categories:**

- 🚀 **Basic Examples** - Simple caching and core concepts
- 💾 **Advanced Caching** - Enterprise-grade caching patterns
- ⚙️ **Configuration** - Environment setup and best practices
- 🗄️ **Migrations** - Database schema evolution
- 📊 **Performance** - Monitoring and optimization
- 🌐 **Framework Integration** - Web framework examples
- 🎯 **Complete Blog App** - Full-featured application demo

### 1. **Add to Your Project**

```yaml
# shard.yml
dependencies:
  cql:
    github: azutoolkit/cql
    version: ~> 0.0.395
  pg: # PostgreSQL driver
    github: will/crystal-pg
    version: ~> 0.26.0
```

### 2. **Define Your Schema**

```crystal
# Set up your database schema
BlogDB = CQL::Schema.define(
  :blog_schema,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do
  table :users do
    primary :id, Int64
    text :name
    text :email
    boolean :active, default: "1"
    timestamps
  end

  table :posts do
    primary :id, Int64
    text :title
    text :content
    bigint :user_id
    boolean :published, default: "0"
    timestamps
    foreign_key [:user_id], references: :users, references_columns: [:id]
  end
end
```

### 3. **Create Your First Model**

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :users

  getter id : Int64?
  getter name : String
  getter email : String
  getter active : Bool = true
  getter created_at : Time?
  getter updated_at : Time?

  # Type-safe relationships
  has_many :posts, Post, foreign_key: :user_id

  # Built-in validations
  validate :name, presence: true, size: 2..50
  validate :email, presence: true, match: /@/

  def initialize(@name : String, @email : String, @active : Bool = true)
  end
end
```

### 4. **Start Building**

```crystal
# Create records with validation
user = User.create!(name: "Alice", email: "alice@example.com")

# Type-safe queries
active_users = User.where(active: true)
                  .order(created_at: :desc)
                  .limit(50)
                  .all

# Work with relationships
user = User.find!(1)
posts = user.posts.all

puts "User #{user.name} has #{posts.size} posts"
```

---

## 📊 Database Support

**Supported databases with their Crystal DB drivers:**

| Database       | Driver    | Connection String Example             |
| -------------- | --------- | ------------------------------------- |
| **PostgreSQL** | `pg`      | `postgres://user:pass@localhost/mydb` |
| **MySQL**      | `mysql`   | `mysql://user:pass@localhost/mydb`    |
| **SQLite**     | `sqlite3` | `sqlite3://./database.db`             |

---

## 🎨 Advanced Features

### **Relationships Made Simple**

```crystal
# Define relationships with type safety
struct Post
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :posts

  getter id : Int64?
  getter title : String
  getter content : String
  getter user_id : Int64
  getter published : Bool = false

  belongs_to :user, User, foreign_key: :user_id
  has_many :comments, Comment, foreign_key: :post_id

  def initialize(@title : String, @content : String, @user_id : Int64)
  end
end

# Work with relationships efficiently
post = Post.find!(1)
author = post.user                    # Type: User
comments = post.comments.all          # Type: Array(Comment)
```

### **Powerful Query DSL**

```crystal
# Complex queries with full type safety
recent_posts = Post.where(published: true)
                  .where { users.created_at >= 1.month.ago }
                  .order(created_at: :desc)
                  .limit(100)
                  .all

# Use the CQL Query builder for complex joins
posts_with_authors = BlogDB.query
  .from(:posts)
  .join(:users) { |j| j.posts.user_id.eq(j.users.id) }
  .where{ posts.published: true }
  .select(posts: [:title, :content], users: [:name])
  .all({title: String, content: String, name: String})
```

### **Automatic Schema Management**

```crystal
# Migrations with full rollback support
class CreateUsers < CQL::Migration(1)
  def up
    schema.create :users do
      primary :id, Int64, auto_increment: true
      text :name, null: false
      text :email, null: false
      boolean :active, default: true
      timestamps
    end

    schema.alter :users do
      create_index :idx_users_email, [:email], unique: true
    end

    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end
```

### **Built-in Validations**

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :users

  # ... properties ...

  # Comprehensive validation support
  validate :name, presence: true, size: 2..50
  validate :email, required: true, match: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  validate :age, gt: 0, lt: 120
  validate :password_confirmation, confirmation: :password
  validate :terms, accept: true

  def initialize(@name : String, @email : String)
  end
end

# Validate before saving
user = User.new(name: "Alice", email: "alice@example.com")
if user.valid?
  user.save!
else
  puts user.errors.messages
end
```

---

## 🛠️ Why Choose CQL?

### **✅ For High-Performance Applications**

- APIs serving high request volumes
- Real-time applications requiring low latency
- Data-intensive processing applications
- Microservices architecture

### **✅ For Enterprise Development**

- Large team collaboration with type safety
- Long-term maintenance requirements
- Complex business logic with data integrity
- Compliance and audit requirements

### **✅ For Modern Development**

- Type-safe development practices
- DevOps and CI/CD pipeline integration
- Container-based deployment strategies
- Cloud-native architecture patterns

---

## 📚 Complete Documentation

### **🚦 Getting Started**

| **New to CQL?**                                                              | **Migrating?**                                        |
| ---------------------------------------------------------------------------- | ----------------------------------------------------- |
| 🎮 [Interactive Examples](../examples/) (`crystal examples/run_examples.cr`) | 🔄 [From ActiveRecord](guides/migration-guide.md)     |
| 📖 [Installation](installation.md)                                           | 🔄 [From Other ORMs](guides/migration-guide.md)       |
| 🎯 [Getting Started](guides/getting-started.md)                              | ⚖️ [Feature Comparison](guides/feature-comparison.md) |
| 🏗️ [First Application](guides/active-record-with-cql/)                       | 📚 [Complete Examples](../examples/)                  |

### **🏗️ Core Features**

| **Foundation**                            | **Active Record**                                                 | **Advanced**                                      |
| ----------------------------------------- | ----------------------------------------------------------------- | ------------------------------------------------- |
| [Configuration](guides/configuration.md)  | [Models & CRUD](guides/active-record-with-cql/defining-models.md) | [Performance](guides/performance-optimization.md) |
| [Schemas](core-concepts/schemas.md)       | [Querying](guides/active-record-with-cql/queryable.md)            | [Caching](guides/caching-guide.md)                |
| [Migrations](core-concepts/migrations.md) | [Relationships](guides/active-record-with-cql/relations/)         | [Security](guides/security-guide.md)              |

### **⚡ Quick Reference**

| **I want to...**                    | **Go to...**                                                                                                       |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| **Set up a new project**            | [Installation](installation.md) → [Getting Started](guides/getting-started.md)                                     |
| **Define models and relationships** | [Models](guides/active-record-with-cql/defining-models.md) → [Relations](guides/active-record-with-cql/relations/) |
| **Build complex queries**           | [Queryable](guides/active-record-with-cql/queryable.md) → [Performance](guides/performance-optimization.md)        |
| **Handle database changes**         | [Migrations](guides/active-record-with-cql/migrations.md) → [Schema Management](core-concepts/schemas.md)          |
| **Deploy to production**            | [Security](guides/security-guide.md) → [Best Practices](guides/best-practices.md)                                  |

---

## 🎯 Ready to Get Started?

```crystal
# Try the interactive examples first
crystal examples/run_examples.cr

# Or install CQL and start building
shards install

# Your next type-safe application awaits! 🚀
```

**👉 [Try Interactive Examples →](../examples/) • [Start with Installation →](installation.md)**

---

<div align="center">

**Built with Crystal's performance and safety in mind**

_All examples are tested with the latest CQL version_

[📖 **Documentation**](guides/getting-started.md) • [🔧 **Examples**](examples/) • [❓ **FAQ**](faqs.md) • [🐛 **Issues**](troubleshooting.md)

</div>
