# Implement Soft Deletes

This guide shows you how to implement soft deletes so records are marked as deleted rather than permanently removed.

## Prerequisites

Your table needs a `deleted_at` timestamp column:

```crystal
schema.table :users do
  primary :id, Int64, auto_increment: true
  column :name, String
  column :deleted_at, Time, null: true
  timestamps
end
schema.users.create!
```

## Enable Soft Deletes

Include the `SoftDeletable` module in your model:

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::SoftDeletable

  db_context MyDB, :users

  property id : Int64?
  property name : String
  property created_at : Time?
  property updated_at : Time?
  # deleted_at is declared by SoftDeletable (property deleted_at : Time?)

  def initialize(@name : String)
  end
end
```

## Soft Delete Records

### Delete a Single Record

```crystal
user = User.find(1)
user.delete!       # Sets deleted_at to current time

user.deleted?      # => true
user.deleted_at    # => 2024-01-15 10:30:00 UTC
```

### Delete by ID

```crystal
User.delete!(user_id)
```

### Delete by Attributes

```crystal
User.delete_by!(email: "spam@example.com")
```

This loads the matching records and soft deletes each one, so `before_destroy`/`after_destroy` callbacks run.

### Delete All Records

```crystal
User.delete_all   # Soft deletes all active users and returns how many
```

Without `before_destroy`/`after_destroy` callbacks this sets `deleted_at` in bulk (one SELECT of the ids, then one
UPDATE per chunk of the database's bind limit). With destroy callbacks it soft deletes record by record so they run.

## Restore Records

### Restore a Single Record

```crystal
user.restore!

user.deleted?      # => false
user.deleted_at    # => nil
```

### Restore by ID

```crystal
User.restore!(user_id)
```

### Restore All Deleted Records

```crystal
User.restore_all   # Returns how many records were restored
```

Restoring runs no callbacks, so `restore_all` clears `deleted_at` in bulk: one SELECT of the ids, then one UPDATE per
chunk.

## Query Records

By default, queries exclude soft-deleted records:

```crystal
User.all           # Only active users
User.count         # Only counts active users
User.find(1)       # Returns nil if user is deleted
```

### Include Deleted Records

```crystal
User.with_deleted.all        # All users including deleted
User.with_deleted.find(1)    # Finds even if deleted
User.with_deleted.count      # Counts all users
User.count_with_deleted      # Same, as a class method
```

### Query Only Deleted Records

```crystal
User.only_deleted.all        # Only deleted users
User.only_deleted.count      # Count of deleted users
User.count_only_deleted      # Same, as a class method
```

`with_deleted` and `only_deleted` are scopes, so you can keep chaining: `User.only_deleted.where(role: "admin").order(deleted_at: :desc).all`.

## Permanently Delete

To actually remove records from the database:

```crystal
user.force_delete!           # Permanently removes from database
User.force_delete!(user_id)  # By ID
User.force_delete_by!(email: "spam@example.com")  # By attributes
User.force_delete_all        # Permanently delete all records
```

## Add Index for Performance

Every query adds `WHERE deleted_at IS NULL`, so add an index on the `deleted_at` column:

```crystal
schema.alter :users do
  create_index :idx_users_deleted_at, [:deleted_at]
end
```

## Cleanup Old Records

Create a job to permanently delete old soft-deleted records:

```crystal
def cleanup_old_deleted_records
  cutoff = 1.year.ago
  old_records = User.only_deleted
    .where { deleted_at < cutoff }
    .all

  old_records.each(&.force_delete!)
  puts "Deleted #{old_records.size} old records"
end
```

## Cascade Soft Deletes

Soft delete related records when a parent is deleted:

```crystal
struct Post
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::SoftDeletable

  db_context MyDB, :posts

  has_many :comments, Comment, foreign_key: :post_id

  after_destroy :soft_delete_comments

  private def soft_delete_comments
    comments.all.each(&.delete!)
    true
  end
end
```

## Verify It Works

```crystal
# Create a user
user = User.create!(name: "John")

# Soft delete
user.delete!
User.count           # => 0
User.with_deleted.count  # => 1

# Restore
user.restore!
User.count           # => 1

# Permanent delete
user.force_delete!
User.with_deleted.count  # => 0
```

## Related

- [Define a Model](define-model.md)
- [Use Callbacks](use-callbacks.md)
- [Add Optimistic Locking](optimistic-locking.md)
