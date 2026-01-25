# Callback Hooks Reference

Complete reference for lifecycle callbacks in CQL Active Record models.

## Overview

Callbacks allow you to trigger logic at specific points in a record's lifecycle:

```
┌──────────────┐
│  before_save │ ─── Runs before INSERT or UPDATE
├──────────────┤
│    save      │ ─── Database operation
├──────────────┤
│  after_save  │ ─── Runs after INSERT or UPDATE
└──────────────┘
```

## Available Callbacks

### before_save

Runs before any save operation (create or update).

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)

  before_save :normalize_email

  private def normalize_email
    @email = @email.downcase.strip
    true  # Must return true to continue
  end
end
```

**Use cases:**
- Data normalization
- Setting computed fields
- Validation that requires database access

### after_save

Runs after any successful save operation.

```crystal
struct Order
  after_save :update_inventory

  private def update_inventory
    order_items.each do |item|
      item.product.decrement_stock!(item.quantity)
    end
    true
  end
end
```

**Use cases:**
- Triggering side effects
- Updating related records
- Sending notifications
- Cache invalidation

### before_create

Runs only before INSERT operations (new records).

```crystal
struct User
  before_create :set_defaults

  private def set_defaults
    @role ||= "member"
    @created_at = Time.utc
    true
  end
end
```

**Use cases:**
- Setting default values
- Generating tokens or UUIDs
- Recording creation metadata

### after_create

Runs only after successful INSERT operations.

```crystal
struct User
  after_create :send_welcome_email

  private def send_welcome_email
    Mailer.welcome(@email).deliver
    true
  end
end
```

**Use cases:**
- Sending welcome emails
- Creating related records
- Notifying other systems

### before_update

Runs only before UPDATE operations (existing records).

```crystal
struct Post
  before_update :track_changes

  private def track_changes
    @previous_status = @status_was if status_changed?
    true
  end
end
```

**Use cases:**
- Tracking changes
- Validating state transitions
- Incrementing version numbers

### after_update

Runs only after successful UPDATE operations.

```crystal
struct Post
  after_update :notify_subscribers

  private def notify_subscribers
    if @published && !@published_was
      subscribers.each do |sub|
        Mailer.new_post(sub, self).deliver
      end
    end
    true
  end
end
```

**Use cases:**
- Change notifications
- Audit logging
- Syncing with external systems

### before_destroy

Runs before DELETE operations.

```crystal
struct User
  before_destroy :check_can_delete

  private def check_can_delete
    if posts.any?
      errors.add(:base, "Cannot delete user with posts")
      return false
    end
    true
  end
end
```

**Use cases:**
- Validation before deletion
- Checking dependencies
- Preventing deletion of protected records

### after_destroy

Runs after successful DELETE operations.

```crystal
struct User
  after_destroy :cleanup_files

  private def cleanup_files
    FileUtils.rm_rf("/uploads/users/#{@id}")
    true
  end
end
```

**Use cases:**
- Cleaning up files
- Removing from search indexes
- Cascade deletes not handled by database

## Return Values

**Important:** Callbacks must return `true` to continue the operation.

```crystal
# Stops the save operation
private def validate_something
  if some_condition_fails
    errors.add(:field, "error message")
    return false  # Halts operation
  end
  true  # Continues operation
end
```

## Callback Order

When saving a new record:
1. `before_save`
2. `before_create`
3. (database INSERT)
4. `after_create`
5. `after_save`

When updating an existing record:
1. `before_save`
2. `before_update`
3. (database UPDATE)
4. `after_update`
5. `after_save`

When deleting:
1. `before_destroy`
2. (database DELETE)
3. `after_destroy`

## Complete Example

```crystal
struct Article
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :articles

  property id : Int64?
  property title : String
  property slug : String?
  property body : String
  property published : Bool = false
  property published_at : Time?
  property view_count : Int32 = 0

  # Before any save
  before_save :generate_slug

  # Only on create
  before_create :set_defaults
  after_create :notify_admin

  # Only on update
  before_update :check_publish_state
  after_update :invalidate_cache

  # On destroy
  before_destroy :archive_content
  after_destroy :cleanup

  private def generate_slug
    @slug = @title.downcase.gsub(/[^a-z0-9]+/, "-")
    true
  end

  private def set_defaults
    @view_count = 0
    true
  end

  private def notify_admin
    AdminMailer.new_article(self).deliver
    true
  end

  private def check_publish_state
    if @published && !published_was
      @published_at = Time.utc
    end
    true
  end

  private def invalidate_cache
    Cache.delete("article:#{@id}")
    Cache.delete("articles:list")
    true
  end

  private def archive_content
    Archive.create!(content: to_json, type: "Article")
    true
  end

  private def cleanup
    Cache.delete("article:#{@id}")
    true
  end
end
```

## See Also

- [Use Callbacks](../../how-to/models/use-callbacks.md)
- [Define a Model](../../how-to/models/define-model.md)
- [Add Validations](../../how-to/models/add-validations.md)
