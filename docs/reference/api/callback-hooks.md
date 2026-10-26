# Callback Hooks Reference

Complete reference for lifecycle callbacks in CQL Active Record models.

## Overview

Callbacks allow you to trigger logic at specific points in a record's lifecycle:

```
┌───────────────────┐
│ before_validation │ ─── Runs first
├───────────────────┤
│ after_validation  │ ─── Runs before the validation rules are evaluated
├───────────────────┤
│    validations    │ ─── Raise ValidationError when invalid
├───────────────────┤
│    before_save    │ ─── Runs before INSERT or UPDATE
├───────────────────┤
│       save        │ ─── Database operation
├───────────────────┤
│    after_save     │ ─── Runs after INSERT or UPDATE
└───────────────────┘
```

Each callback is registered with a macro that takes a method name as a symbol (`before_save :normalize_email`). There are no block, `if:` or `unless:` forms. Callbacks run for `save`, `save!` and the instance `delete!`; `create!`, `update!`, `touch` and the class-level `delete!`, `delete_all`, `delete_by!` and `update_all` skip them; `delete_all` on a query runs each record's destroy callbacks, in one transaction, when the model declares any (or declares `dependent:` associations), and otherwise deletes in bulk. Several callbacks for one event run in the order they were declared.

## Available Callbacks

### before_validation

Runs first when saving, before anything else.

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)

  before_validation :strip_name

  private def strip_name
    @name = @name.strip
    true
  end
end
```

**Use cases:**
- Normalizing input before validation rules look at it

### after_validation

Runs right after `before_validation` and before the validation rules are evaluated, so it cannot see the validation result. Use `before_save` for logic that must only run on valid records.

```crystal
struct User
  after_validation :log_attempt

  private def log_attempt
    Log.debug { "validating #{@email}" }
    true
  end
end
```

### before_save

Runs before any save operation (create or update).

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)

  before_save :normalize_email

  private def normalize_email
    @email = @email.downcase.strip
    true  # Return anything but false to continue
  end
end
```

**Use cases:**
- Data normalization
- Setting computed fields
- Guarding the save with a database lookup (return `false` to halt)

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
    @api_token = Random::Secure.hex(16)
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
  before_update :stamp_edit

  private def stamp_edit
    @edited_at = Time.utc
    true
  end
end
```

**Use cases:**
- Recording edit metadata
- Validating state transitions
- Incrementing counters

Include the opt-in [`CQL::ActiveRecord::DirtyTracking`](../../how-to/models/dirty-tracking.md) (after `Model`) for `changed?`, `changes` (`{old, new}` per attribute) and `attribute_changed?(name)`; there are no `*_was` readers. Without it, load the stored row with `Post.find(id)` inside the callback.

### after_update

Runs only after successful UPDATE operations.

```crystal
struct Post
  after_update :notify_subscribers

  private def notify_subscribers
    if @published
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

Runs before DELETE operations. It fires from the instance `delete!` (and from the soft-delete `delete!` and `force_delete!`); returning `false` makes `delete!` return `false` without deleting.

```crystal
struct User
  before_destroy :check_can_delete

  private def check_can_delete
    if posts_any?
      return false  # Halts - the row is kept
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

Runs after a successful DELETE (at least one row removed). The record's `id` is cleared afterwards, so capture it in `before_destroy` if you need it later.

```crystal
struct User
  after_destroy :cleanup_files

  private def cleanup_files
    FileUtils.rm_rf("/uploads/users/#{@name}")
    true
  end
end
```

**Use cases:**
- Cleaning up files
- Removing from search indexes
- Cascade deletes not handled by database

## Return Values

A callback halts the operation only when it returns `false`. Any other value, including `nil` and `true`, lets the chain continue, but return `true` explicitly so a stray `false` from your last expression cannot halt it by accident.

```crystal
# Stops the save operation
private def check_something
  if some_condition_fails
    return false  # Halts operation
  end
  true  # Continues operation
end
```

When a `before_*` callback halts, `save` returns `false` and `save!` raises `CQL::RecordNotSaved`. Halting does not add anything to `errors`; `errors` only holds validation rule results. A `false` from an `after_*` callback stops the remaining callbacks for that event but does not undo the database change.

## Callback Order

When saving a new record:
1. `before_validation`
2. `after_validation`
3. validation rules
4. `before_save`
5. `before_create`
6. (database INSERT)
7. `after_create`
8. `after_save`

When updating an existing record:
1. `before_validation`
2. `after_validation`
3. validation rules
4. `before_save`
5. `before_update`
6. (database UPDATE)
7. `after_update`
8. `after_save`

When deleting with `record.delete!`:
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
    if @published && @published_at.nil?
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
    Archive.create!(content: @body, type: "Article")
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
