# Soft Deletes in CQL Active Record

CQL Active Record provides comprehensive soft delete functionality through the `SoftDeletable` module, which implements "paranoid" deletion behavior similar to Rails' `acts_as_paranoid` gem.

## Overview

Soft deletes allow you to mark records as deleted without actually removing them from the database. This is useful for:

- **Data recovery**: Accidentally deleted records can be restored
- **Audit trails**: Maintain complete history of all records
- **Compliance**: Meet regulatory requirements for data retention
- **Referential integrity**: Avoid orphaned records in related tables

## Quick Start

> **Important:** This module is NOT automatically included when you use `CQL::ActiveRecord::Model`.
> You must explicitly include it in models that need soft delete functionality.

```crystal
struct User
  include CQL::ActiveRecord::Model(Int32)
  include CQL::ActiveRecord::SoftDeletable

  db_context AppDB, :users

  property name : String
  property email : String
  # deleted_at property is automatically added by SoftDeletable
end
```

## Basic Setup

### 1. Database Schema

First, ensure your table includes a `deleted_at` timestamp column:

```crystal
AppDB = CQL::Schema.define(
  :app_database,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://app.db"
) do
  table :users do
    primary :id, Int32
    column :name, String
    column :email, String
    column :deleted_at, Time, null: true  # Required for soft deletes
    timestamps
  end
end
```

### 2. Model Definition

Include the `SoftDeletable` module in your Active Record model:

```crystal
class User
  include CQL::ActiveRecord::Model(Int32)
  include CQL::ActiveRecord::SoftDeletable

  db_context schema: AppDB, table: :users

  property name : String
  property email : String
  property created_at : Time?
  property updated_at : Time?

  def initialize(@name, @email)
  end
end
```

## Core Features

### Automatic Filtering

Once `SoftDeletable` is included, all queries automatically exclude soft-deleted records:

```crystal
user = User.new("John", "john@example.com")
user.create!

# Normal queries exclude soft-deleted records
User.all.size  # => 1
User.count     # => 1

user.delete!   # Soft delete

User.all.size  # => 0 (soft-deleted records excluded)
User.count     # => 0
```

### Soft Delete Operations

#### Instance Methods

```crystal
user = User.create!(name: "Alice", email: "alice@example.com")

# Check if record is soft deleted
user.deleted?  # => false

# Soft delete the record
user.delete!   # => true
user.deleted?  # => true
user.deleted_at  # => 2024-01-01 12:00:00 UTC

# Restore a soft-deleted record
user.restore!  # => true
user.deleted?  # => false
user.deleted_at  # => nil

# Permanently delete (actually removes from database)
user.force_delete!  # => true
# Record is now completely gone from database
```

#### Class Methods

```crystal
# Soft delete by ID
User.delete!(user_id)  # => DB::ExecResult

# Soft delete by attributes
User.delete_by!(email: "spam@example.com")  # => DB::ExecResult

# Restore by ID
User.restore!(user_id)  # => true

# Force delete by ID (permanent)
User.force_delete!(user_id)  # => DB::ExecResult

# Batch operations
User.delete_all      # Soft delete all records
User.restore_all     # Restore all soft-deleted records
User.force_delete_all  # Permanently delete all records
```

## Scopes

### with_deleted

Include soft-deleted records in queries:

```crystal
# Returns all users, including soft-deleted ones
all_users = User.with_deleted.all

# Can be chained with other query methods
User.with_deleted.where(name: "John").all
User.with_deleted.count  # Count including deleted records
```

### only_deleted

Query only soft-deleted records:

```crystal
# Returns only soft-deleted users
deleted_users = User.only_deleted.all

# Can be chained
User.only_deleted.where(email: "test@example.com").first
User.only_deleted.count  # Count only deleted records
```

## Counting Methods

```crystal
User.count                # Active records only
User.count_with_deleted   # All records (including deleted)
User.count_only_deleted   # Soft-deleted records only
```

## Query Integration

Soft delete filtering integrates seamlessly with all query methods:

```crystal
# All these automatically exclude soft-deleted records
User.find(1)
User.find_by(email: "user@example.com")
User.where(name: "John")
User.first
User.last
User.all
User.exists?(id: 1)
User.pluck(:name)

# Use scopes to include deleted records
User.with_deleted.find(1)
User.only_deleted.find_by(name: "John")
```

## Advanced Usage

### Checking Model Configuration

```crystal
User.acts_as_paranoid?  # => true (if SoftDeletable is included)
```

### Custom Queries

The `where_not_nil` method is available for custom queries:

```crystal
# Equivalent to only_deleted scope
User.with_deleted.where_not_nil(:deleted_at).all
```

### Callback Integration

Soft deletes work with Active Record callbacks:

```crystal
class User
  include CQL::ActiveRecord::Model(Int32)
  include CQL::ActiveRecord::SoftDeletable

  before_destroy :log_deletion
  after_destroy :send_notification

  private def log_deletion
    puts "User #{name} is being deleted"
    true
  end

  private def send_notification
    puts "User deletion notification sent"
    true
  end
end

user.delete!  # Triggers both callbacks
```

## Best Practices

### 1. Database Indexes

Add indexes on `deleted_at` for better query performance:

```crystal
schema.alter :users do
  create_index :deleted_at_idx, [:deleted_at]
end
```

### 2. Regular Cleanup

Consider implementing a cleanup job for old soft-deleted records:

```crystal
# Delete records soft-deleted more than 1 year ago
old_deleted = User.only_deleted
  .where("deleted_at < ?", 1.year.ago)
  .all

old_deleted.each(&.force_delete!)
```

### 3. Testing

Test both active and deleted record scenarios:

```crystal
describe User do
  it "excludes soft-deleted records from queries" do
    user = User.create!(name: "Test", email: "test@example.com")
    user.delete!

    User.all.should be_empty
    User.with_deleted.all.size.should eq(1)
  end

  it "allows restoring soft-deleted records" do
    user = User.create!(name: "Test", email: "test@example.com")
    user.delete!
    user.restore!

    user.deleted?.should be_false
    User.all.size.should eq(1)
  end
end
```

### 4. Documentation

Always document which models use soft deletes in your API documentation:

```crystal
# @note This model uses soft deletes. Use `with_deleted` scope to include deleted records.
class User
  include CQL::ActiveRecord::SoftDeletable
  # ...
end
```

## Migration from Hard Deletes

If you're adding soft deletes to an existing model:

### Complete Migration Example

```crystal
class AddSoftDeletesToUsers < CQL::Migration(20240120)
  def up
    schema.alter :users do
      add_column :deleted_at, Time, null: true
    end

    # Add index for query performance
    schema.alter :users do
      create_index :idx_users_deleted_at, [:deleted_at]
    end
  end

  def down
    schema.alter :users do
      drop_index :idx_users_deleted_at
      drop_column :deleted_at
    end
  end
end
```

Run the migration:

```crystal
migrator = CQL::Migrator.new(AppDB)
migrator.up
```

### Migration Checklist

1. Add the `deleted_at` column with the migration above
2. Include the `SoftDeletable` module in your model
3. Update any direct SQL queries to account for soft deletes
4. Test thoroughly to ensure existing functionality isn't broken

## Relationships and Soft Deletes

### Querying Associations

When a parent model uses soft deletes, associations need special handling:

```crystal
struct Post
  include CQL::ActiveRecord::Model(Int32)
  include CQL::ActiveRecord::SoftDeletable

  db_context AppDB, :posts

  has_many :comments, Comment, foreign_key: :post_id

  property title : String
end

# Normal query excludes soft-deleted posts
user.posts.all  # Only active posts

# Include soft-deleted posts
Post.with_deleted.where(user_id: user.id).all
```

### Cascading Soft Deletes

To soft-delete associated records when a parent is soft-deleted:

```crystal
struct Post
  include CQL::ActiveRecord::Model(Int32)
  include CQL::ActiveRecord::SoftDeletable

  db_context AppDB, :posts

  has_many :comments, Comment, foreign_key: :post_id

  after_destroy :soft_delete_comments

  private def soft_delete_comments
    comments.each(&.delete!)
    true
  end
end
```

## Combining with OptimisticLocking

You can use both modules together for maximum data integrity:

```crystal
struct User
  include CQL::ActiveRecord::Model(Int32)
  include CQL::ActiveRecord::SoftDeletable
  include CQL::ActiveRecord::OptimisticLocking

  db_context AppDB, :users

  property name : String
  property email : String
  property version : Int32?

  optimistic_locking version_column: :version
end
```

Required schema:

```crystal
table :users do
  primary :id, Int32
  column :name, String
  column :email, String
  column :deleted_at, Time, null: true
  lock_version :version
  timestamps
end
```

## Limitations

- **Performance**: Queries become slightly more complex due to additional WHERE clauses
- **Storage**: Deleted records continue to consume storage space
- **Unique constraints**: Soft-deleted records may interfere with uniqueness constraints
- **Relationships**: Related models need careful handling of soft-deleted associations

## Related Features

- [Active Record Models](./defining-models.md)
- [Callbacks](./callbacks.md)
- [Scopes](./scopes.md)
- [Validations](./validations.md)
