---
icon: code
---

# 🌐 CQL API Reference

> **Complete method documentation** - Comprehensive reference for all CQL classes, methods, and features with practical examples

This API reference provides complete documentation for CQL (Crystal Query Language) with practical examples, method signatures, and detailed explanations.

## 📋 Table of Contents

- [🏗️ Schema Definition](#️-schema-definition)
- [🔍 Query Builder](#-query-builder)
- [📦 Active Record](#-active-record)
- [🔗 Relationships](#-relationships)
- [✅ Validations](#-validations)
- [🔄 Callbacks](#-callbacks)
- [🏭 Repository Pattern](#-repository-pattern)
- [💱 Transactions](#-transactions)

---

## 🏗️ Schema Definition

### `CQL::Schema.define`

Creates database schema with connection configuration.

```crystal
UserDB = CQL::Schema.define(
  :user_db,
  adapter: CQL::Adapter::Postgres,
  uri: "postgres://user:pass@localhost:5432/myapp",
  pool_size: 25,
  checkout_timeout: 10.seconds
) do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String, size: 100
    column :email, String, unique: true
    column :active, Bool, default: true
    timestamps

    index [:email], unique: true
    index [:active, :created_at]
  end
end
```

### Table Definition

```crystal
table :posts do
  primary :id, Int64, auto_increment: true
  column :title, String, null: false
  column :content, String, size: 65535
  column :user_id, Int64
  column :published, Bool, default: false
  timestamps

  # Constraints
  foreign_key :user_id, references: :users, on_delete: :cascade
  unique_constraint [:user_id, :title]
  check_constraint "LENGTH(title) > 0"

  # Indexes
  index [:user_id]
  index [:published, :created_at]
  index [:title], where: "published = true"  # Partial index
end
```

---

## 🔍 Query Builder

### Basic Queries

```crystal
# Where conditions
User.where(active: true)
User.where("age > ?", 18)
User.where { (active == true) & (age >= 18) }

# Selecting columns
User.select(:id, :name, :email)
User.select("COUNT(*) as user_count")

# Ordering and limiting
User.order(:name).limit(10).offset(20)
User.order(name: :asc, created_at: :desc)

# Grouping and aggregation
User.group(:role).select(:role, "COUNT(*) as count")
User.group(:role).having("COUNT(*) > ?", 5)

# Joins
User.joins(:posts).where("posts.published = ?", true)
User.join(:profiles, :left).on("users.id = profiles.user_id")
```

### Advanced Queries

```crystal
# Includes (eager loading)
User.join(:posts, :profile).all

# Aggregations
User.count
User.where(active: true).count
Order.sum(:amount)
Order.average(:amount)

# Existence checks
User.exists?(email: "test@example.com")
User.where(active: true).exists?

# Batch processing
User.find_in_batches(batch_size: 1000) do |batch|
  batch.each { |user| process_user(user) }
end
```

---

## 📦 Active Record

### Model Definition

```mermaid
classDiagram
    class User {
        +Int64? id
        +String name
        +String email
        +Bool active
        +Time? created_at
        +Time? updated_at

        +initialize(name, email)
        +save() Bool
        +save!() void
        +update(attrs) Bool
        +delete!() void
        +valid?() Bool
        +errors() ErrorCollection
    }

    class CQLActiveRecordModel {
        <<mixin>>
        +find(id) Model?
        +find!(id) Model
        +create(attrs) Model
        +all() Array(Model)
        +where(conditions) Query
    }

    User --|> CQLActiveRecordModel
```

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)

  db_context UserDB, :users

  property id : Int64?
  property name : String
  property email : String
  property active : Bool = true
  property created_at : Time?
  property updated_at : Time?

  def initialize(@name : String, @email : String)
  end
end
```

### CRUD Operations

```crystal
# Create
user = User.new("John", "john@example.com")
user.save                    # Returns Bool
user.save!                   # Raises on failure

user = User.create(name: "Jane", email: "jane@example.com")
user = User.create!(name: "Bob", email: "bob@example.com")

# Read
user = User.find(1)          # Returns User?
user = User.find!(1)         # Raises if not found
user = User.find_by(email: "test@example.com")
users = User.all

# Update
user.update(name: "New Name")
user.update!(active: false)
user.name = "Updated"
user.save!

# Delete
user.delete!
User.delete(1)
User.where(active: false).delete_all
```

### Scopes

```crystal
struct User
  scope :active, -> { where(active: true) }
  scope :by_role, ->(role : String) { where(role: role) }
  scope :recent, ->(days : Int32) { where { created_at > days.days.ago } }
end

# Usage
User.active.all
User.by_role("admin").recent(7).all
```

---

## 🔗 Relationships

### Association Types

```mermaid
erDiagram
    User ||--o{ Post : "has_many"
    User ||--|| UserProfile : "has_one"
    User }o--o{ Role : "many_to_many"
    Post }o--|| User : "belongs_to"
    UserProfile }o--|| User : "belongs_to"

    User {
        int64 id PK
        string name
        string email
        bool active
    }

    Post {
        int64 id PK
        string title
        string content
        int64 user_id FK
        bool published
    }

    UserProfile {
        int64 id PK
        string bio
        int64 user_id FK
    }

    Role {
        int64 id PK
        string name
        string description
    }

    UserRoles {
        int64 user_id FK
        int64 role_id FK
    }

    User ||--o{ UserRoles : "through"
    Role ||--o{ UserRoles : "through"
```

```crystal
# belongs_to
struct Post
  belongs_to :user, User, foreign_key: :user_id, optional: true
end

# has_one
struct User
  has_one :profile, UserProfile, foreign_key: :user_id, dependent: :destroy
end

# has_many
struct User
  has_many :posts, Post, foreign_key: :user_id, dependent: :destroy
end

# many_to_many
struct User
  many_to_many :roles, Role, join_through: :user_roles
end
```

### Using Associations

```crystal
# belongs_to
post = Post.find!(1)
author = post.user
post.user = User.find!(2)
post.build_user(name: "New")
post.create_user!(name: "New")

# has_many
user = User.find!(1)
posts = user.posts.all
user.posts.create!(title: "New Post")
user.posts.delete(post)
user.posts.clear

# Collection methods
user.posts.count
user.posts.exists?
user.posts.reload
user.posts.where(published: true).all
```

---

## ✅ Validations

### Built-in Validators

```crystal
struct User
  validates :name, presence: true
  validates :email,
    presence: true,
    uniqueness: true,
    format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  validates :age,
    numericality: {greater_than: 0, less_than: 150}

  validates :role,
    inclusion: {in: ["admin", "user", "guest"]}

  validates :password,
    length: {minimum: 8},
    confirmation: true,
    on: :create
end
```

### Custom Validations

```crystal
struct User
  validate :email_domain_allowed

  private def email_domain_allowed
    return unless email

    allowed_domains = ["company.com", "partner.com"]
    domain = email.split("@").last

    unless allowed_domains.includes?(domain)
      errors.add(:email, "domain not allowed")
    end
  end
end
```

### Error Handling

```crystal
user = User.new
user.valid?                    # => false
user.errors.full_messages      # => Array of error messages
user.errors[:email]            # => Array of email errors
user.errors.add(:base, "Custom error")
```

---

## 🔄 Callbacks

### Lifecycle Callbacks

```crystal
struct User
  before_validation :normalize_email
  before_save :set_defaults
  before_create :generate_token
  after_create :send_welcome_email
  after_update :invalidate_cache
  before_destroy :cleanup_data

  private def normalize_email
    self.email = email.downcase.strip if email
  end

  private def send_welcome_email
    WelcomeMailer.new(self).deliver
  end
end
```

### Conditional Callbacks

```crystal
struct User
  before_save :hash_password, if: :password_changed?
  after_update :notify_admin, unless: :admin?

  private def password_changed?
    # Implementation
  end
end
```

---

## 🏭 Repository Pattern

### Repository Implementation

```crystal
struct User
  property id : Int64?
  property name : String
  property email : String

  def initialize(@name : String, @email : String, @id : Int64? = nil)
  end
end

class UserRepository < CQL::Repository(User, Int64)
  def find_active : Array(User)
    query.where(active: true).all(User)
  end

  def find_by_email_domain(domain : String) : Array(User)
    query.where { email.like("%@#{domain}") }.all(User)
  end
end
```

### Repository Usage

```crystal
repo = UserRepository.new

# CRUD operations
user_id = repo.create(name: "John", email: "john@example.com")
user = repo.find!(user_id)
repo.update(user_id, name: "Updated")
repo.delete(user_id)

# Custom queries
active_users = repo.find_active
gmail_users = repo.find_by_email_domain("gmail.com")
```

---

## 💱 Transactions

### Basic Transactions

```crystal
# Schema-level transaction
UserDB.transaction do
  user = User.create!(name: "John", email: "john@example.com")
  profile = UserProfile.create!(user_id: user.id!, bio: "Developer")
end

# Model-level transaction
User.transaction do
  user = User.create!(name: "Jane", email: "jane@example.com")
  user.posts.create!(title: "First Post")
end
```

### Nested Transactions

```crystal
UserDB.transaction do
  user = User.create!(name: "Outer")

  UserDB.transaction do  # Savepoint
    profile = UserProfile.create!(user_id: user.id!)
  end
end
```

### Transaction Control

```mermaid
sequenceDiagram
    participant App as Application
    participant DB as Database
    participant Tx as Transaction

    Note over App,Tx: Transaction Lifecycle
    App->>DB: BEGIN TRANSACTION
    DB-->>Tx: Transaction Started

    App->>Tx: User.create!(name: "Test")
    Tx->>DB: INSERT INTO users...
    DB-->>Tx: Row inserted (not committed)

    App->>App: Check some_condition

    alt Condition Failed
        App->>Tx: tx.rollback
        Tx->>DB: ROLLBACK
        DB-->>App: All changes discarded ❌
    else Condition Passed
        App->>Tx: user.update!(active: true)
        Tx->>DB: UPDATE users...
        DB-->>Tx: Row updated (not committed)
        Tx->>DB: COMMIT
        DB-->>App: All changes saved ✅
    end
```

```crystal
UserDB.transaction do |tx|
  user = User.create!(name: "Test")

  if some_condition
    tx.rollback
    return
  end

  user.update!(active: true)
end
```

---

## 🎯 Quick Reference

### Model Methods

```crystal
# Class methods
User.all, User.count, User.first, User.last
User.find(id), User.find!(id)
User.find_by(attrs), User.find_by!(attrs)
User.where(conditions), User.order(fields)
User.create(attrs), User.create!(attrs)
User.update_all(attrs), User.delete_all

# Instance methods
user.save, user.save!, user.update(attrs), user.update!(attrs)
user.delete!, user.destroy!, user.reload
user.valid?, user.invalid?, user.errors
user.new_record?, user.persisted?, user.changed?
```

### Query Methods

```crystal
# Conditions
.where(field: value)
.where("sql", args)
.where { block }
.where.not(conditions)

# Ordering & Limiting
.order(field: direction)
.limit(count).offset(count)
.group(fields).having(conditions)

# Joins & Includes
.joins(association)
.join(table, join_type) { conditions }

# Aggregations
.count, .sum(field), .average(field)
.minimum(field), .maximum(field)
.exists?
```

### Validation Options

```crystal
presence: true
length: {minimum: 1, maximum: 100, in: 1..100, is: 10}
format: {with: /regex/, without: /regex/}
numericality: {greater_than: 0, less_than: 100, in: 1..5}
inclusion: {in: ["a", "b", "c"]}
exclusion: {in: ["banned"]}
uniqueness: true, uniqueness: {scope: :field}
confirmation: true
```

---

> 🌐 **This reference covers the essential CQL API** - For complete details, refer to the source code and inline documentation.

**Related Guides:**

- **[Getting Started →](getting-started.md)** - Learn CQL basics
- **[Active Record Guide →](active-record-with-cql/README.md)** - Detailed Active Record usage
- **[Relationships Guide →](active-record-with-cql/relations/README.md)** - Association patterns
