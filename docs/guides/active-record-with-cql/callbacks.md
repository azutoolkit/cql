# Callbacks

CQL's Active Record provides lifecycle callbacks that allow you to trigger logic at various points during an object's life. This is useful for tasks like data normalization before validation, encrypting passwords before saving, or sending notifications after an action.

The `CQL::ActiveRecord::Callbacks` module is automatically included when you use `CQL::ActiveRecord::Model(Pk)`.

---

## Available Callbacks

Callbacks are methods defined in your model that are registered to be called at specific moments. CQL supports the following callbacks:

**Validation Callbacks:**

- `before_validation(method_name)`: Called before `validate` is run.
- `after_validation(method_name)`: Called after `validate` completes.

**Save Callbacks (run for both create and update):**

- `before_save(method_name)`: Called before the record is saved to the database.
- `after_save(method_name)`: Called after the record is saved to the database.

**Create Callbacks (run only when a new record is saved):**

- `before_create(method_name)`: Called before a new record is inserted into the database.
- `after_create(method_name)`: Called after a new record is inserted into the database.

**Update Callbacks (run only when an existing record is saved):**

- `before_update(method_name)`: Called before an existing record is updated in the database.
- `after_update(method_name)`: Called after an existing record is updated in the database.

**Destroy Callbacks:**

- `before_destroy(method_name)`: Called before a record is deleted from the database.
- `after_destroy(method_name)`: Called after a record is deleted from the database.

---

## Registering Callbacks

You register a callback by calling its macro with the name of the method (as a Symbol) to be executed.

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context AcmeDB, :users

  property id : Int64?
  property name : String
  property email : String
  property status : String?
  property last_logged_in_at : Time?

  def initialize(@name : String, @email : String)
    @status = "pending"
  end

  # Registering callbacks
  before_validation :normalize_email
  before_save :set_status_if_nil
  after_create :send_welcome_email
  before_update :record_login_time
  after_destroy :log_deletion

  private def normalize_email
    self.email = email.downcase.strip
    true # Important: before_ callbacks must return true or a truthy value to continue
  end

  private def set_status_if_nil
    self.status = "active" if status.nil?
    true
  end

  private def send_welcome_email
    puts "Sending welcome email to #{email}..."
    # In a real app, you'd use an email library here
    true
  end

  private def record_login_time
    # Hypothetical: this callback might be triggered indirectly
    # if an update operation is intended to signify a login.
    # More commonly, you'd set this explicitly.
    self.last_logged_in_at = Time.utc
    true
  end

  private def log_deletion
    puts "User #{name} (ID: #{id.inspect}) deleted."
    true # after_ callbacks don't halt the chain, but consistency is good
  end
end
```

In this example:

- `normalize_email` will run before validations.
- `set_status_if_nil` will run before any save operation (create or update).
- `send_welcome_email` will run only after a new user is created.
- `record_login_time` will run only before an existing user is updated.
- `log_deletion` will run after a user is destroyed.

---

## Halting Execution

If a `before_validation`, `before_save`, `before_create`, `before_update`, or `before_destroy` callback method returns `false` (explicitly `false`, not `nil` or other falsy values), the callback chain is halted. This means:

- Subsequent callbacks of the same type (e.g., other `before_save` methods) will not be executed.
- The main action (validation, save, create, update, or destroy) will be canceled.
  - For `save`, `create`, `update`, it will return `false`.
  - For `save!`, `create!`, `update!`, it will not raise `RecordInvalid` due to validation errors (if any ran), but simply won't proceed with persistence.
  - For `destroy`, it will return `false`, and the record will not be deleted.

**Example of halting:**

```crystal
struct Article
  include CQL::ActiveRecord::Model(Int64)
  db_context AcmeDB, :articles

  property id : Int64?
  property title : String
  property published : Bool

  def initialize(@title : String, @published : Bool = false)
  end

  before_save :check_if_can_be_published

  private def check_if_can_be_published
    if published && title.empty?
      errors.add(:title, "cannot be blank if published")
      return false # Halt the save
    end
    true
  end
end

# Attempt to save an article that will be halted
article1 = Article.new(title: "", published: true)
if article1.save
  puts "Article 1 saved!" # This won't run
else
  puts "Article 1 not saved. Errors: #{article1.errors.full_messages.join(", ")}"
  # Output: Article 1 not saved. Errors: Title cannot be blank if published
end

# Attempt to save a valid article
article2 = Article.new(title: "My Great Article", published: true)
if article2.save
  puts "Article 2 saved! ID: #{article2.id.inspect}"
else
  puts "Article 2 not saved."
end
```

`after_*` callbacks do not have the power to halt the chain, as the primary action has already completed.

---

## Order of Callbacks

When multiple callbacks are registered for the same event, they are executed in the order they were defined in the model.

CQL aims to follow a similar callback order to other popular ORMs like Rails Active Record during the `save` process:

1. `before_validation`
2. Validations are run (`validate` method)
3. `after_validation`
4. `before_save`
5. If new record: `before_create`
6. If existing record: `before_update`
7. Database operation (INSERT or UPDATE)
8. If new record: `after_create`
9. If existing record: `after_update`
10. `after_save`

For `destroy`:

1. `before_destroy`
2. Database operation (DELETE)
3. `after_destroy`

---

## Use Cases

- **Data Manipulation**: Normalize data (e.g., downcasing emails), set default values, generate tokens.
- **Lifecycle Management**: Update related objects, log changes, manage state transitions.
- **Notifications**: Send emails or push notifications after certain events (e.g., `after_create`).
- **Conditional Logic**: A callback method can contain logic to decide if it should perform an action, or even halt the entire operation.

Callbacks are a powerful tool for adding behavior to your models without cluttering your controller or service logic. However, use them judiciously, as complex callback chains can sometimes make debugging harder.
