# Quick Reference

## Configuration

### Zero Configuration (Development)

```crystal
# Just works in development!
CQL.configure do |c|
  c.db = "postgresql://localhost/myapp"
end
```

### Production

```crystal
CQL.configure do |c|
  c.db = ENV["DATABASE_URL"]
  c.env = "production"
  c.pool_size = 25
  c.monitor_performance = true  # Opt-in
end
```

### Common Settings

```crystal
  # Database
  c.db = "postgresql://localhost/myapp"
c.env = "development"  # Auto-detected
  c.pool_size = 10

# Performance (auto-enabled in dev)
  c.monitor_performance = true
c.performance_report_interval = 5.minutes
c.sql_logging = true
c.sql_logging_colorize = true

# Caching
  c.cache.on = true
  c.cache.ttl = 30.minutes
  c.cache.memory_size = 2000

# Schema
c.auto_sync = true  # Auto in dev
c.verify_schema = false
```

## Models

### Definition

```crystal
class User < CQL::Model(User)
  getter id : Int64?
  getter name : String
  getter email : String
  getter active : Bool = true
  getter created_at : Time?
  getter updated_at : Time?

  # Associations
  has_many :posts, Post, foreign_key: :user_id
  has_one :profile, Profile
  belongs_to :team, Team

  # Validations
  validate_presence :name, :email
  validate_uniqueness :email
  validate_format :email, /\A[^@]+@[^@]+\z/

  # Scopes
  scope :active, -> { where(active: true) }
  scope :recent, -> { order(created_at: :desc) }
end
```

## Queries

### Basic CRUD

```crystal
# Create
user = User.create(name: "Alice", email: "alice@example.com")

# Read
user = User.find(1)
user = User.find_by(email: "alice@example.com")
users = User.all

# Update
user.update(name: "Alice Smith")
User.where(active: false).update(active: true)

# Delete
user.delete
User.where(created_at: < 1.year.ago).delete_all
```

### Query Builder

```crystal
# Where conditions
User.where(active: true)
User.where("age > ?", 18)
User.where("email LIKE ?", "%@example.com")

# Ordering
User.order(created_at: :desc)
User.order(name: :asc, created_at: :desc)

# Limiting
User.limit(10)
User.limit(10).offset(20)

# Selecting columns
User.select(:id, :name, :email)

# Joins
User.joins(:posts).where(posts: {published: true})

# Grouping
User.group(:role).count

# Having
User.group(:role).having("COUNT(*) > ?", 10)
```

### Scopes

```crystal
# Define scopes
scope :active, -> { where(active: true) }
scope :with_posts, -> { joins(:posts).distinct }
scope :by_email, ->(email : String) { where(email: email) }

# Use scopes
User.active.with_posts.order(created_at: :desc)
```

## Associations

### Types

```crystal
# Has Many
has_many :posts, Post, foreign_key: :user_id

# Has One
has_one :profile, Profile

# Belongs To
belongs_to :team, Team

# Has Many Through
has_many :tags, Tag, through: :post_tags
```

### Usage

```crystal
# Access associations
user.posts
user.profile
user.team

# Create associated records
user.posts.create(title: "New Post")

# Query through associations
user.posts.where(published: true)
```

## Validations

### Built-in

```crystal
validate_presence :name, :email
validate_uniqueness :email
validate_format :email, /\A[^@]+@[^@]+\z/
validate_length :name, min: 2, max: 100
validate_inclusion :role, in: ["admin", "user"]
```

### Custom

```crystal
validate :custom_validation

def custom_validation
  if email && email.ends_with?("@spam.com")
    errors.add(:email, "is from a blocked domain")
  end
end
```

## Migrations

### Create Migration

```crystal
class CreateUsers < CQL::Migration
  def up
    schema.create_table :users do |t|
      t.primary_key :id
      t.string :name, null: false
      t.string :email, null: false
      t.boolean :active, default: true
      t.timestamps

      t.index [:email], unique: true
    end
  end

  def down
    schema.drop_table :users
  end
end
```

### Run Migrations

```crystal
# Run all pending
migrator.up

# Rollback last
migrator.down

# Rollback to version
migrator.down_to(20240101000000_i64)
```

## Caching

### Query Caching

```crystal
# Cache query results
users = User.where(active: true).cache(5.minutes).all

# Request-scoped caching
CQL.with_request_cache do
  User.find(1)  # Hits DB
  User.find(1)  # From cache
end
```

### Fragment Caching

```crystal
stats = CQL.fragment_cache.fetch("user_stats_#{user.id}", ttl: 1.hour) do
  {
    post_count: user.posts.count,
    comment_count: user.comments.count
  }
end
```

## Performance

### Auto-enabled in Development

```crystal
# You get these automatically:
# ✅ SQL logging
# ✅ N+1 detection
# ✅ Slow query warnings
# ✅ Performance reports every 5 minutes
```

### Manual Control

```crystal
# Disable auto-features
ENV["CQL_NO_SQL_LOG"] = "1"
ENV["CQL_NO_PERF_MONITOR"] = "1"

# Generate report on demand
report = CQL::Performance.monitor.generate_comprehensive_report("text")

# Check N+1 issues
issues = CQL::Performance.monitor.n_plus_one_issues
```

## Transactions

```crystal
User.transaction do
  user = User.create!(name: "Alice")
  Profile.create!(user_id: user.id)
  # Rolls back if any operation fails
end

# Nested transactions
User.transaction do
  User.create!(name: "Bob")

  User.transaction do
    User.create!(name: "Charlie")
    raise "Rollback inner"  # Only rolls back Charlie
  end

  User.create!(name: "David")  # Still created
end
```

## Environment Variables

```crystal
# Control features
CQL_NO_SQL_LOG=1       # Disable SQL logging
CQL_NO_PERF_MONITOR=1  # Disable performance monitoring

# Environment
CRYSTAL_ENV=production  # Set environment
DATABASE_URL=...       # Database connection
```

## Common Patterns

### Batch Operations

```crystal
# Insert many
users_data = [{name: "Alice"}, {name: "Bob"}]
User.insert_many(users_data)

# Update many
User.where(active: false).update_all(active: true)

# Process in batches
User.find_each(batch_size: 100) do |user|
  # Process user
end
```

### Soft Deletes

```crystal
class Post < CQL::Model(Post)
  include CQL::SoftDeletable

  # Adds deleted_at column
  # Changes default scope to exclude deleted
end

post.soft_delete
Post.with_deleted.all  # Include soft deleted
```

### Optimistic Locking

```crystal
class Document < CQL::Model(Document)
  include CQL::OptimisticLocking

  # Adds lock_version column
  # Prevents concurrent updates
end
```

This quick reference covers the most common CQL operations and patterns.
