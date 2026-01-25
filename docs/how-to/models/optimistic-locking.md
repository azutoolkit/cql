# Add Optimistic Locking

This guide shows you how to add optimistic locking to prevent concurrent updates from overwriting each other.

## When to Use

Use optimistic locking when:
- Multiple users might edit the same record simultaneously
- Conflicts are rare but data integrity is important
- You want to avoid database-level row locks

## Prerequisites

Your table needs a version column:

```crystal
schema.create :users do
  primary :id, Int64, auto_increment: true
  text :name
  lock_version :version  # Adds integer column with default 1
  timestamps
end
```

Or add to an existing table:

```crystal
class AddVersionToUsers < CQL::Migration(20240115)
  def up
    schema.alter :users do
      add_column :version, Int32, default: 1, null: false
    end
  end

  def down
    schema.alter :users do
      drop_column :version
    end
  end
end
```

## Enable Optimistic Locking

Include the module and configure the version column:

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::OptimisticLocking

  db_context MyDB, :users

  property id : Int64?
  property name : String
  property version : Int32?

  optimistic_locking version_column: :version

  def initialize(@name : String)
  end
end
```

## Handle Updates

Updates automatically check the version:

```crystal
user = User.find!(1)
user.name = "Updated Name"

begin
  user.update!
  puts "Updated! New version: #{user.version}"
rescue CQL::OptimisticLockError
  puts "Someone else updated this record!"
end
```

## Handle Conflicts

When a conflict occurs, reload and retry:

```crystal
user = User.find!(1)
user.name = "My Changes"

begin
  user.update!
rescue CQL::OptimisticLockError
  user.reload!  # Get latest data from database
  user.name = "My Changes"  # Re-apply changes
  user.update!  # Try again
end
```

## Retry with Limit

Implement retry logic with a maximum attempts:

```crystal
def update_with_retry(user, max_retries = 3)
  attempts = 0

  loop do
    attempts += 1
    user.name = "Updated Name"

    begin
      user.update!
      return true
    rescue CQL::OptimisticLockError
      if attempts >= max_retries
        puts "Max retries reached"
        return false
      end

      puts "Conflict, retrying (#{attempts}/#{max_retries})..."
      user.reload!
    end
  end
end
```

## How It Works

1. Record is loaded with current version (e.g., version 5)
2. When updating, CQL generates: `UPDATE users SET name = ?, version = 6 WHERE id = ? AND version = 5`
3. If another process updated first (version is now 6), the WHERE clause matches 0 rows
4. CQL raises `OptimisticLockError`
5. Your code handles by reloading and retrying

## Combine with Soft Deletes

You can use both modules together:

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::SoftDeletable
  include CQL::ActiveRecord::OptimisticLocking

  db_context MyDB, :users

  property id : Int64?
  property name : String
  property version : Int32?

  optimistic_locking version_column: :version

  def initialize(@name : String)
  end
end
```

## Verify It Works

```crystal
# Load same record twice (simulating two users)
user1 = User.find!(1)
user2 = User.find!(1)

# First update succeeds
user1.name = "User 1's change"
user1.update!  # Works, version now 2

# Second update fails
user2.name = "User 2's change"
begin
  user2.update!  # Raises OptimisticLockError
rescue CQL::OptimisticLockError
  puts "Conflict detected!"
end
```

## Best Practices

1. **Always reload after conflict** - Get latest data before retrying
2. **Limit retries** - Avoid infinite loops
3. **Inform users** - In UIs, tell users the data changed
4. **Use for important data** - Not every table needs locking
5. **Test conflict scenarios** - Write tests that simulate concurrent updates

## Related

- [Define a Model](define-model.md)
- [Implement Soft Deletes](soft-delete.md)
- [Use Transactions](../data-operations/transactions.md)
