# Active Record Pattern

The Active Record pattern is the primary pattern used in CQL. Understanding it helps you write better models and make informed architectural decisions.

## What is Active Record?

Active Record is a design pattern where an object wraps a row in a database table, encapsulating both the data and the database access logic.

In Active Record:
- A model class represents a database table
- A model instance represents a row in that table
- The model knows how to save itself
- Business logic lives inside the model

## Active Record in CQL

```crystal
class User
  include CQL::ActiveRecord::Model(Int64) # provides `id : Int64?`
  db_context MyDB, :users

  property name : String
  property email : String
  property active : Bool = true

  def initialize(@name : String, @email : String)
  end

  # Business logic in the model
  def activate!
    @active = true
    save
  end

  def deactivate!
    @active = false
    save
  end
end

# Usage - the model handles its own persistence
user = User.new("John", "john@example.com")
user.save      # Model saves itself
user.activate! # Business logic + persistence together
```

## Key Characteristics

### 1. Self-Aware Persistence

Models know how to persist themselves:

```crystal
user = User.new("John", "john@example.com")
user.save   # INSERT
user.name = "Jane"
user.save   # UPDATE
user.delete! # DELETE
```

Models are classes, not structs: `save` assigns the generated `id` to the instance you hold.

### 2. Class Methods for Queries

The model class provides query methods:

```crystal
User.find(1)                 # => User?
User.where(active: true).all # => Array(User)
User.count
User.all
```

### 3. Built-in Validations

Validation logic lives in the model:

```crystal
class User
  validate :email, presence: true, match: /@/
  validate :name, presence: true
end

user = User.new("", "invalid")
user.valid?  # false
user.errors.map(&.message) # => ["email must match the pattern /@/", "name must be present"]
user.save    # raises CQL::ActiveRecord::Validations::ValidationError; nothing is written
```

### 4. Lifecycle Callbacks

Models respond to persistence events:

```crystal
class User
  before_save :normalize_email
  after_create :send_welcome_email

  private def normalize_email
    @email = @email.downcase.strip
    true
  end

  private def send_welcome_email
    # Send the welcome email
    true
  end
end
```

## Benefits

### Simplicity

Active Record is intuitive. The code reads naturally:

```crystal
# Create a user, save it, find it, update it
user = User.create!(name: "John", email: "john@example.com")
found = User.find!(user.id!)
found.name = "Jane"
found.save
```

### Rapid Development

Everything you need is in one place:

```crystal
class Post
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :posts

  property title : String
  property body : String
  property user_id : Int64
  property slug : String = ""

  belongs_to :user, User, :user_id
  has_many :comments, Comment, :post_id

  validate :title, presence: true

  before_save :update_slug

  def initialize(@title : String, @body : String, @user_id : Int64)
  end

  private def update_slug
    @slug = @title.downcase.gsub(/[^a-z0-9]+/, "-").strip("-")
  end
end
```

### Discoverability

Looking at a model tells you everything about that entity: its data, validations, relationships, and behavior.

## Trade-offs

### Coupling

Active Record couples your domain logic to the database structure. Changes to the database schema may require changes to business logic.

### Testing

Models are harder to test in isolation because they depend on the database.

### Complexity

For complex domains, models can become bloated with too much logic.

## When Active Record Works Best

- CRUD-heavy applications
- Rapid prototyping
- Small to medium applications
- When database schema closely matches domain model

## When to Consider Alternatives

- Complex business logic
- Multiple data sources
- Need for database-agnostic domain
- Heavy testing requirements

## Comparison with Other Patterns

| Pattern | Data | Persistence Logic | Business Logic |
|---------|------|-------------------|----------------|
| Active Record | In model | In model | In model |
| Repository | In model | In repository | In model |
| Data Mapper | In entity | In mapper | In entity |

## Example: Complex Active Record Model

```crystal
class Order
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :orders

  property user_id : Int64
  property status : String = "pending"
  property total : Float64 = 0.0

  def initialize(@user_id : Int64)
  end

  belongs_to :user, User, :user_id
  has_many :order_items, OrderItem, :order_id

  validate :status, in: ["pending", "paid", "shipped", "completed", "cancelled"]

  before_save :calculate_total
  after_save :notify_status_change

  def pay!
    @status = "paid"
    save
  end

  def ship!
    raise "Cannot ship unpaid order" unless status == "paid"
    @status = "shipped"
    save
  end

  private def calculate_total
    @total = order_items.all.sum(&.subtotal) # subtotal : Float64 on OrderItem
    true
  end

  private def notify_status_change
    # Send notification
    true
  end
end
```

This model:
- Defines data (properties)
- Handles its own persistence (save, validations)
- Contains business logic (pay!, ship!)
- Manages relationships (belongs_to, has_many)
- Responds to lifecycle events (callbacks)

All in one cohesive unit - that's the Active Record pattern.
