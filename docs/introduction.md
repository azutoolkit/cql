---
icon: arrow-right-to-arc
---

# 🚀 Introduction to CQL

> **Crystal Query Language** - A powerful, type-safe ORM that brings the elegance of Crystal to database interactions

Welcome to **CQL (Crystal Query Language)** - the modern Object-Relational Mapping library designed specifically for Crystal developers who demand both performance and developer experience. CQL bridges the gap between raw SQL power and Crystal's compile-time safety, giving you the best of both worlds.

## 🎯 What is CQL?

CQL is a **type-safe, high-performance ORM** that leverages Crystal's static type system and macro capabilities to provide:

- 🔒 **Compile-time Safety** - Catch errors before they reach production
- ⚡ **High Performance** - Zero-cost abstractions with macro-generated code
- 🎨 **Developer Experience** - Intuitive API that feels natural to Crystal developers
- 🔧 **Flexibility** - Support for multiple patterns (Active Record, Repository, Data Mapper)
- 🌐 **Multi-Database** - Works seamlessly with PostgreSQL, MySQL, and SQLite

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

puts "Found #{active_users.size} active adult users"
```

---

## ✨ Key Features & Benefits

### 🔍 **Type-Safe ORM**

Leverages Crystal's static type system for compile-time safety, eliminating common runtime database errors.

```crystal
# Compile-time error if column doesn't exist
user = User.where(nam: "Alice")  # Error: no such column 'nam'

# Type-safe attribute access
user.age.class  # => Int32 (guaranteed!)
```

### 🏗️ **Macro-Powered DSL**

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

### 🗄️ **Multi-Database Support**

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

### 🔄 **Multiple Design Patterns**

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

### 🔗 **Advanced Relationships**

Rich association system with lazy and eager loading capabilities.

```crystal
# Define relationships
class User
  has_many :posts, Post
  has_one :profile, UserProfile
  has_many :comments, Comment
end

class Post
  belongs_to :user, User
  has_many :comments, Comment
  many_to_many :tags, Tag, through: PostTag
end

# Use with ease
user.posts.where(published: true).count
post.comments.join(:user).all  # Eager loading
```

### ✅ **Comprehensive Validations**

Built-in validation system with custom validator support.

```crystal
struct User
  validates :name, presence: true, length: {minimum: 2, maximum: 50}
  validates :email, presence: true, format: EMAIL_REGEX, uniqueness: true
  validates :age, numericality: {greater_than: 0, less_than: 150}

  # Custom validator
  validates :username, with: :username_format

  private def username_format
    unless username.matches?(/\A[a-zA-Z0-9_]+\z/)
      errors.add(:username, "can only contain letters, numbers, and underscores")
    end
  end
end
```

### 🔄 **Lifecycle Callbacks**

Hook into the model lifecycle for custom business logic.

```crystal
struct User
  before_save :normalize_email
  after_create :send_welcome_email
  before_destroy :cleanup_associations

  private def normalize_email
    self.email = email.downcase.strip
  end

  private def send_welcome_email
    WelcomeMailer.new(self).deliver
  end
end
```

### 🗃️ **Database Migrations**

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

### 🔧 **Powerful Query Builder**

Fluent interface for building complex SQL queries with joins and subqueries.

```crystal
# Complex query with joins and conditions
users = User
  .joins(:posts)
  .where { posts.published == true }
  .where { users.created_at > 1.month.ago }
  .group(:id)
  .having { count(posts.id) > 5 }
  .order(name: :asc)
  .limit(20)
  .all

# Raw SQL when needed
User.query("SELECT * FROM users WHERE complex_condition(?)", [param])
```

### 💱 **Transaction Support**

Full transaction support with automatic rollback on exceptions.

```crystal
UserDB.transaction do
  user = User.create!(name: "Alice", email: "alice@example.com")
  profile = UserProfile.create!(user_id: user.id, bio: "Developer")
  Settings.create!(user_id: user.id, theme: "dark")

  # Automatic rollback if any operation fails
end
```

### 🔐 **Optimistic Locking**

Built-in support for optimistic concurrency control.

```crystal
struct Document
  include CQL::ActiveRecord::Model(Int64)

  property lock_version : Int32 = 0
  optimistic_locking  # Enables automatic version checking
end

# Automatic version checking prevents concurrent updates
doc1 = Document.find!(1)
doc2 = Document.find!(1)

doc1.title = "Updated by user 1"
doc1.save!  # ✅ Success

doc2.title = "Updated by user 2"
doc2.save!  # ❌ Raises CQL::StaleObjectError
```

---

## 🎮 Supported Primary Key Types

CQL provides flexibility with multiple primary key types:

| Type       | Use Case                   | Example                                        |
| ---------- | -------------------------- | ---------------------------------------------- |
| **Int32**  | Traditional auto-increment | `include CQL::ActiveRecord::Model(Int32)`      |
| **Int64**  | Large-scale applications   | `include CQL::ActiveRecord::Model(Int64)`      |
| **UUID**   | Distributed systems        | `include CQL::ActiveRecord::Model(UUID)`       |
| **ULID**   | Sortable unique IDs        | `include CQL::ActiveRecord::Model(ULID)`       |
| **Custom** | Domain-specific needs      | `include CQL::ActiveRecord::Model(CustomType)` |

```crystal
# UUID primary keys for microservices
struct User
  include CQL::ActiveRecord::Model(UUID)
  db_context UserDB, :users

  property id : UUID?
  property name : String
end

# ULID for time-sortable IDs
struct Event
  include CQL::ActiveRecord::Model(ULID)
  db_context EventDB, :events

  property id : ULID?
  property event_type : String
  property occurred_at : Time
end
```

---

## 🗄️ Database Support Matrix

CQL works seamlessly across major SQL databases:

| Database       | Support Level | Features                                        |
| -------------- | ------------- | ----------------------------------------------- |
| **PostgreSQL** | 🟢 Full       | JSONB, Arrays, Custom Types, Advanced Indexing  |
| **MySQL**      | 🟢 Full       | Full-text search, Spatial data, JSON columns    |
| **SQLite**     | 🟢 Full       | Perfect for development, testing, embedded apps |

### Database-Specific Features

**PostgreSQL:**

```crystal
# Use PostgreSQL arrays and JSONB
struct User
  property tags : Array(String) = [] of String
  property metadata : JSON::Any = JSON::Any.new({} of String => JSON::Any)
end

# Advanced PostgreSQL features
User.where { tags.contains(["developer", "crystal"]) }
User.where { metadata["role"] == "admin" }
```

**MySQL:**

```crystal
# Full-text search
Post.where { match(title, content).against("crystal programming") }

# JSON column queries
User.where { json_extract(preferences, "$.theme") == "dark" }
```

**SQLite:**

```crystal
# Perfect for development and testing
DevDB = CQL::Schema.define(
  :development,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://./db/dev.db"
)

# Seamless switching between environments
TestDB = CQL::Schema.define(
  :test,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://:memory:"  # In-memory for fast tests
)
```

---

## 🎯 Perfect Use Cases

### 🌐 **Web Applications**

Build robust web APIs and applications with Crystal frameworks like Kemal, Amber, or Lucky.

```crystal
# Clean API endpoints with CQL
get "/users/:id" do |env|
  user = User.find(env.params.url["id"])
  if user
    user.to_json
  else
    env.response.status_code = 404
    {"error" => "User not found"}.to_json
  end
end
```

### 🔬 **Microservices**

Create fast, type-safe microservices with independent data models.

```crystal
# User service
struct User
  include CQL::ActiveRecord::Model(UUID)
  # Service-specific user fields
end

# Order service
struct Order
  include CQL::ActiveRecord::Model(UUID)
  property user_id : UUID  # Reference to user service
end
```

### 🏢 **Enterprise Applications**

Large-scale applications requiring performance, reliability, and maintainability.

```crystal
# Complex business models with validation and callbacks
struct Invoice
  include CQL::ActiveRecord::Model(Int64)

  validates :amount, numericality: {greater_than: 0}
  validates :due_date, presence: true

  before_save :calculate_totals
  after_create :send_notification

  has_many :line_items, LineItem
  belongs_to :customer, Customer
end
```

### 🧪 **Development & Testing**

SQLite support makes CQL perfect for development environments and fast test suites.

```crystal
# Fast in-memory tests
describe User do
  before_each do
    TestDB.migrate!
  end

  after_each do
    TestDB.rollback!
  end

  it "creates users" do
    user = User.create!(name: "Test", email: "test@example.com")
    user.persisted?.should be_true
  end
end
```

### 📊 **Data-Intensive Applications**

Applications requiring complex queries, aggregations, and reporting.

```crystal
# Complex analytics queries
monthly_stats = User
  .joins(:orders)
  .where { created_at >= 1.month.ago }
  .group("DATE_TRUNC('month', users.created_at)")
  .select("COUNT(*) as user_count, SUM(orders.amount) as revenue")
  .all

# Efficient batch processing
User.find_in_batches(batch_size: 1000) do |batch|
  batch.each { |user| process_user(user) }
end
```

---

## 🚀 Getting Started

Ready to dive in? Here's how to get started with CQL:

### 1. **Installation**

Add CQL to your `shard.yml`:

```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: "~> 1.0"
```

### 2. **Quick Setup**

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

puts "Created user: #{user.name} with ID: #{user.id}"
```

### 3. **Next Steps**

- 📖 Read the **[Getting Started Guide](guides/getting-started.md)**
- 🏗️ Learn about **[Core Concepts](core-concepts/README.md)**
- 🔄 Master **[CRUD Operations](core-concepts/crud-operations/README.md)**
- 🔗 Explore **[Relationships](guides/active-record-with-cql/relations/README.md)**

---

## 🌟 Why Choose CQL?

**Performance** ⚡

- Zero-cost abstractions through Crystal macros
- Compile-time optimizations for runtime speed
- Efficient memory usage with value types

**Safety** 🔒

- Compile-time type checking prevents runtime errors
- SQL injection protection built-in
- Validation system ensures data integrity

**Developer Experience** 🎨

- Intuitive API that feels natural to Crystal developers
- Comprehensive error messages and debugging tools
- Extensive documentation with real-world examples

**Flexibility** 🔧

- Multiple design patterns (Active Record, Repository, Data Mapper)
- Works with your preferred Crystal framework
- Easy database switching without code changes

**Community** 🤝

- Active development and community support
- Regular updates and feature improvements
- Comprehensive test suite ensuring reliability

---

## 📚 Documentation Overview

- **[Installation Guide](installation.md)** - Set up CQL in your project
- **[Core Concepts](core-concepts/README.md)** - Understanding CQL fundamentals
- **[Guides](guides/README.md)** - Practical tutorials and examples
- **[API Reference](../api/)** - Complete method documentation
- **[Troubleshooting](troubleshooting.md)** - Solutions to common issues
- **[FAQ](faqs.md)** - Frequently asked questions

---

> 💎 **Built for Crystal developers, by Crystal developers** - CQL brings together the performance and safety of Crystal with the power and flexibility of modern ORM design.

Ready to build something amazing? Let's get started! 🚀
