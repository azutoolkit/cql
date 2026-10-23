# Use Callbacks

This guide shows you how to use lifecycle callbacks to run code at specific points during a model's lifecycle.

## Available Callbacks

### Validation Callbacks

- `before_validation` - Before validations run
- `after_validation` - Runs right after `before_validation`, before the validations themselves are evaluated

### Save Callbacks (create and update)

- `before_save` - Before any save operation
- `after_save` - After any save operation

### Create Callbacks (new records only)

- `before_create` - Before inserting a new record
- `after_create` - After inserting a new record

### Update Callbacks (existing records only)

- `before_update` - Before updating an existing record
- `after_update` - After updating an existing record

### Destroy Callbacks

- `before_destroy` - Before deleting a record
- `after_destroy` - After deleting a record

Destroy callbacks run from the instance method `delete!` (and the soft-delete `delete!`/`force_delete!`).

### When Callbacks Run

Callbacks run through `save`, `save!` and the instance `delete!`. The shortcuts `create!`, `update!`, `touch` and the class-level `delete!`, `delete_by!`, `delete_all` and `update_all` write to the database directly and skip callbacks.

## Basic Usage

Register a callback by calling its macro with a method name:

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :users

  property id : Int64?
  property name : String
  property email : String

  before_save :normalize_email
  after_create :send_welcome_email

  def initialize(@name : String, @email : String)
  end

  private def normalize_email
    @email = @email.downcase.strip
    true  # Return true to continue
  end

  private def send_welcome_email
    puts "Sending welcome email to #{@email}"
    true
  end
end
```

## Callback Order

When saving a new record:

1. `before_validation`
2. `after_validation`
3. Validations run
4. `before_save`
5. `before_create`
6. INSERT into database
7. `after_create`
8. `after_save`

When updating an existing record:

1. `before_validation`
2. `after_validation`
3. Validations run
4. `before_save`
5. `before_update`
6. UPDATE in database
7. `after_update`
8. `after_save`

When deleting with `record.delete!`:

1. `before_destroy`
2. DELETE from database
3. `after_destroy` (only if a row was deleted)

## Halting the Chain

Return `false` from a callback to halt execution (any other return value continues). `save` then returns `false`:

```crystal
struct Article
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :articles

  property id : Int64?
  property title : String
  property published : Bool = false

  before_save :check_can_publish

  def initialize(@title : String, @published : Bool = false)
  end

  private def check_can_publish
    if @published && @title.empty?
      return false  # Halt - save won't proceed
    end
    true
  end
end

# This save is halted before anything is written
article = Article.new(title: "", published: true)
article.save  # => false
article.persisted?  # => false
```

A halted callback does not add to `errors`; `errors` only reports the results of `validate` rules (see [Add Validations](add-validations.md)).

## Common Use Cases

### Normalizing Data

```crystal
before_validation :normalize_data

private def normalize_data
  @email = @email.downcase.strip
  @name = @name.strip
  true
end
```

### Setting Custom Timestamps

`created_at` and `updated_at` are set automatically by `save` (see [Use Timestamps](timestamps.md)). Use callbacks only for other time columns:

```crystal
before_create :set_activated_at

private def set_activated_at
  @activated_at = Time.utc
  true
end
```

### Generating Slugs

```crystal
before_save :generate_slug

private def generate_slug
  @slug = @title.downcase.gsub(/[^a-z0-9]+/, "-").strip("-")
  true
end
```

### Sending Notifications

```crystal
after_create :notify_admin

private def notify_admin
  # Send notification (email, webhook, etc.)
  puts "New user registered: #{@email}"
  true
end
```

### Cleaning Up Related Data

```crystal
before_destroy :cleanup_files

private def cleanup_files
  # Delete associated files
  File.delete(@avatar_path) if @avatar_path && File.exists?(@avatar_path)
  true
end
```

## Multiple Callbacks

You can register multiple callbacks for the same event:

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :users

  property id : Int64?
  property name : String
  property email : String
  property status : String = "pending"
  property checked_at : Time?

  before_save :normalize_data
  before_save :check_permissions
  before_save :stamp_check

  def initialize(@name : String, @email : String)
  end

  private def normalize_data
    @email = @email.downcase
    true
  end

  private def check_permissions
    if @status == "banned"
      return false  # Halts - stamp_check won't run
    end
    true
  end

  private def stamp_check
    @checked_at = Time.utc
    true
  end
end
```

## Best Practices

1. **Keep callbacks simple** - Complex logic belongs in service objects
2. **Always return true** unless you intend to halt (a callback whose last expression is `false` halts the chain)
3. **Make callback methods private** - They're internal to the model
4. **Avoid external API calls** in callbacks without error handling
5. **Test callbacks** - Ensure they work as expected

## Verify It Works

```crystal
user = User.new("John", " JOHN@EXAMPLE.COM ")
user.save

user.email  # => "john@example.com" (normalized by callback)
```

## Related

- [Define a Model](define-model.md)
- [Add Validations](add-validations.md)
- [Callback Hooks Reference](../../reference/api/callback-hooks.md)
