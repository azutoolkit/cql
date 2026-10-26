---
description: "Register methods that CQL runs before or after a record is validated, saved or deleted."
---

# Use Callbacks

## Register Callbacks

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)

  property name : String = ""
  property email : String = ""
  property slug : String = ""
  property status : String = "active"

  before_validation :normalize_email   # derived values that must pass validation
  before_save :set_slug                # several per event run in declaration order
  before_save :reject_banned
  after_create :send_welcome_email

  validate :email, presence: true

  def initialize
  end

  def initialize(@name : String, @email : String)
  end

  private def normalize_email
    @email = @email.downcase.strip   # any value but false continues
  end

  private def set_slug
    @slug = @name.downcase.gsub(/[^a-z0-9]+/, "-").strip('-')
  end

  private def reject_banned
    @status != "banned"              # false halts: save returns false
  end

  private def send_welcome_email
    puts "Welcome, #{@email}"
  end
end

user = User.new("Ada Lovelace", " ADA@EXAMPLE.COM ")
user.save     # => true, prints "Welcome, ada@example.com"
user.email    # => "ada@example.com"
user.slug     # => "ada-lovelace"
```

The macros are `before_validation`, `after_validation`, `before_save`, `after_save`, `before_create`, `after_create`, `before_update`, `after_update`, `before_destroy` and `after_destroy`. Each takes one method name; the method may be private.

## Know the Order

```text
save, new record           save, persisted record     record.delete!
1. before_validation       1. before_validation       1. before_destroy
2. validations             2. validations             2. DELETE (soft delete: UPDATE deleted_at)
3. after_validation        3. after_validation        3. after_destroy, if a row was deleted
4. before_save             4. before_save
5. before_create           5. before_update
6. INSERT                  6. UPDATE
7. after_create            7. after_update
8. after_save              8. after_save
```

`after_validation` runs only once the validations pass; an invalid record raises before it. A value set in `before_save`, `before_create` or `before_update` is not validated, so set derived values in `before_validation`. `save` stamps `created_at`/`updated_at` before step 1.

## Halt a Save

```crystal
user = User.new("Mallory", "mallory@example.com")
user.status = "banned"

user.save         # => false: reject_banned returned false, nothing is written
user.persisted?   # => false
user.errors       # => [] (a halt adds no error)
user.save!        # raises CQL::RecordNotSaved: Failed to save the record
```

Only `false` halts; `nil` continues. A `false` from an `after_*` callback skips the later callbacks of that event, but the row is already written.

## Know What Skips Callbacks

`save`, `save!` and the instance `delete!` (soft delete: `delete!`, `force_delete!`) run callbacks. `create!`, `update!`, `touch` and most class-level writes skip them; the [Callback Hooks Reference](../../reference/api/callback-hooks.md) lists every call.

{% hint style="info" %}
`created_at` and `updated_at` need no callback: `save` sets them (see [Use Timestamps](timestamps.md)).
{% endhint %}

## See Also

- [Callback Hooks Reference](../../reference/api/callback-hooks.md)
- [Add Validations](add-validations.md)
- [Implement Soft Deletes](soft-delete.md)
- [Use Timestamps](timestamps.md)
- [Define a Model](define-model.md)
