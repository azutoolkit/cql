# Defining Models

CQL Active Record models are Crystal classes or structs that map directly to database tables. Each model encapsulates the table's columns as properties, provides type-safe access to data, and includes methods for persistence, querying, and associations.

***

## Basic Model Definition

To define a model, include the `CQL::ActiveRecord::Model` module with your primary key type and specify the database context:

```crystal
# src/models/user.cr
require "cql"

class User
  # Include Active Record functionality with the primary key type
  include CQL::ActiveRecord::Model(Int32)

  # Map to the 'users' table in the specified database context
  db_context UserDB, :users

  # Define properties for each column
  property id : Int32?           # Primary key, nullable if auto-generated
  property name : String
  property email : String
  property age : Int32 = 0       # Default value
  property password : String?    # Nullable field
  property created_at : Time?    # Timestamp columns
  property updated_at : Time?

  # Constructor for creating new instances
  def initialize(@name : String, @email : String, @age : Int32 = 0, @password : String? = nil)
  end
end
```

**Key Points:**

* Use `class` or `struct` for models (both are supported)
* `include CQL::ActiveRecord::Model(PkType)` provides all Active Record functionality
* The type parameter specifies the primary key type (e.g., `Int32`, `Int64`, `UUID`, `ULID`)
* `db_context DatabaseSchema, :table_name` links the model to a specific table
* Use `property` for each database column
* Nullable types (e.g., `Int32?`, `String?`) are used for columns that may be `NULL` or auto-generated
* Define a constructor to initialize required fields

***

## Primary Key Types

CQL supports multiple primary key types to fit different application needs:

### Integer Primary Keys

```crystal
class Product
  include CQL::ActiveRecord::Model(Int64)
  db_context StoreDB, :products

  property id : Int64?
  property name : String
  property price : Float64

  def initialize(@name : String, @price : Float64)
  end
end
```

### UUID Primary Keys

```crystal
class Session
  include CQL::ActiveRecord::Model(UUID)
  db_context AppDB, :sessions

  property id : UUID?
  property user_id : Int32
  property token : String
  property expires_at : Time

  def initialize(@user_id : Int32, @token : String, @expires_at : Time)
  end
end
```

### ULID Primary Keys

```crystal
class Event
  include CQL::ActiveRecord::Model(ULID)
  db_context EventDB, :events

  property id : ULID?
  property event_type : String
  property payload : JSON::Any
  property occurred_at : Time

  def initialize(@event_type : String, @payload : JSON::Any, @occurred_at : Time = Time.utc)
  end
end
```

***

## Working with Attributes

### Individual Attribute Access

Access and modify attributes using the generated getter and setter methods:

```crystal
user = User.new("Alice", "alice@example.com", 30)
puts user.name        # => "Alice"
puts user.email       # => "alice@example.com"

user.name = "Alice Johnson"
user.age = 31
```

### Accessing All Attributes as a Hash

Use the `attributes` method to get a hash of all attribute values:

```crystal
user = User.new("Bob", "bob@example.com", 25)
attrs = user.attributes

# Returns Hash(Symbol, DB::Any)
puts attrs[:name]     # => "Bob"
puts attrs[:email]    # => "bob@example.com"
puts attrs[:age]      # => 25
puts attrs[:id]       # => nil (not saved yet)
```

### Mass Assignment

Set multiple attributes at once using the `attributes` method:

```crystal
user = User.new("Original", "original@example.com", 20)

# Set multiple attributes using a hash
new_attrs = {
  :name  => "Updated Name",
  :email => "updated@example.com",
  :age   => 35,
} of Symbol => DB::Any

user.attributes(new_attrs)

puts user.name   # => "Updated Name"
puts user.email  # => "updated@example.com"
puts user.age    # => 35
```

**Important Notes:**

* Mass assignment only updates the instance in memory - call `save` to persist changes
* Invalid attribute names are ignored silently
* Attributes with incorrect types are ignored silently
* Only existing model properties can be set

### Handling Nullable Fields

For nullable database columns, use nullable Crystal types:

```crystal
class Article
  include CQL::ActiveRecord::Model(Int32)
  db_context BlogDB, :articles

  property id : Int32?
  property title : String
  property body : String
  property published_at : Time?  # Nullable - article may not be published yet
  property author_id : Int32?    # Nullable - anonymous articles allowed

  def initialize(@title : String, @body : String)
  end
end

# Creating with nullable fields
article = Article.new("My Title", "Article content")
article.published_at = nil      # Not published yet
article.author_id = nil         # Anonymous article
```

***

## Database Fields Configuration

### Ignoring Fields from Database Mapping

Use the `@[DB::Field(ignore: true)]` annotation for fields that shouldn't be persisted:

```crystal
class User
  include CQL::ActiveRecord::Model(Int32)
  db_context UserDB, :users

  property id : Int32?
  property name : String
  property email : String
  property password : String?

  # This field won't be saved to or loaded from the database
  @[DB::Field(ignore: true)]
  property password_confirmation : String?

  def initialize(@name : String, @email : String, @password : String? = nil, @password_confirmation : String? = nil)
  end
end
```

***

## Complete Model Example

Here's a comprehensive example showing all common patterns:

```crystal
class User
  include CQL::ActiveRecord::Model(Int32)
  db_context UserDB, :users

  # Database columns
  property id : Int32?
  property name : String
  property email : String
  property age : Int32 = 0
  property password : String?
  property active : Bool = true
  property created_at : Time?
  property updated_at : Time?

  # Non-persisted fields
  @[DB::Field(ignore: true)]
  property password_confirmation : String?

  # Constructor
  def initialize(@name : String, @email : String, @age : Int32 = 0, @password : String? = nil, @password_confirmation : String? = nil)
  end

  # Custom methods
  def full_name
    name
  end

  def email_domain
    email.split("@").last
  end
end

# Usage examples
user = User.new("John Doe", "john@example.com", 30, "secret123", "secret123")

# Access attributes
puts user.name                    # => "John Doe"
puts user.email_domain           # => "example.com"

# Get all attributes
attrs = user.attributes
puts attrs[:name]                # => "John Doe"

# Mass assignment
user.attributes({
  :name => "Jane Doe",
  :age  => 25
} of Symbol => DB::Any)

puts user.name                   # => "Jane Doe"
puts user.age                    # => 25
```

***

## Best Practices

* **Use appropriate types**: Match Crystal types to your database column types
* **Make auto-generated fields nullable**: Primary keys and timestamps should be nullable (`Int32?`, `Time?`)
* **Provide constructors**: Define constructors for required fields to ensure valid object creation
* **Use `@[DB::Field(ignore: true)]`**: For computed fields or temporary values that shouldn't be persisted
* **Be careful with mass assignment**: Validate input when using `attributes` method with user data
* **Follow naming conventions**: Use snake\_case for database columns and property names

***

## Related Guides

For more information on working with CQL Active Record models, see these related guides:

**Model Operations:**

* [CRUD Operations](crud-operations.md) - Creating, reading, updating, and deleting records
* [Queryable](queryable.md) - Advanced querying and filtering
* [Persistence Details](persistence-details.md) - Deep dive into model persistence

**Data Validation and Integrity:**

* [Validations](validations.md) - Ensuring data integrity with built-in and custom validators
* [Callbacks](callbacks.md) - Lifecycle hooks for model operations
* [Optimistic Locking](optimistic-locking.md) - Handling concurrent updates

**Relationships:**

* [Relations Overview](relations/) - Understanding model associations
* [Belongs To](relations/belongsto.md) - Many-to-one relationships
* [Has One](relations/hasone.md) - One-to-one relationships
* [Has Many](relations/hasmany.md) - One-to-many relationships
* [Many to Many](relations/manytomany.md) - Many-to-many relationships

**Advanced Features:**

* [Scopes](scopes.md) - Reusable query methods
* [Transactions](transactions.md) - Managing database transactions
* [Migrations](../database-management/migrations.md) - Managing database schema changes

***

## Model Definition Methods

CQL provides several class methods for working with model definitions and metadata. These methods are available on all models that include `CQL::ActiveRecord::Model`.

### Database Context Methods

#### `db_context(schema, table)`

Associates a model with a specific database schema and table:

```crystal
class User
  include CQL::ActiveRecord::Model(Int32)

  # Associate with UserDB schema and :users table
  db_context UserDB, :users
end
```

#### `schema`

Returns the schema associated with the model:

```crystal
User.schema  # => Returns the UserDB schema object
```

#### `table`

Returns the table name for the model:

```crystal
User.table  # => :users
```

#### `adapter`

Returns the database adapter for the model's schema:

```crystal
User.adapter  # => CQL::Adapter::SQLite (or Postgres, MySql)
```

### Table Metadata Methods

#### `table_columns`

Returns a hash of all table columns and their definitions:

```crystal
columns = User.table_columns
# Returns Hash(Symbol, CQL::Column) with column definitions

columns[:name]     # => Column definition for name field
columns[:email]    # => Column definition for email field
columns[:id]       # => Column definition for id field
```

#### `table_column(column_name)`

Returns the column expression for a specific column:

```crystal
name_column = User.table_column(:name)
# Returns the column expression for the name field

email_column = User.table_column(:email)
# Returns the column expression for the email field
```

### Object Creation Methods

#### `build(**fields)`

Creates a new model instance with the given attributes (alias for `new`):

```crystal
# These are equivalent - both use positional parameters
user1 = User.new("Alice", "alice@example.com", 30)
user2 = User.build("Alice", "alice@example.com", 30)

# Both create an unsaved instance
user1.id  # => nil (not saved yet)
user2.id  # => nil (not saved yet)
```

### Practical Examples

#### Inspecting Model Metadata

```crystal
class Product
  include CQL::ActiveRecord::Model(Int32)
  db_context StoreDB, :products

  property id : Int32?
  property name : String
  property price : Float64
  property category : String
  property active : Bool = true

  def initialize(@name : String, @price : Float64, @category : String)
  end
end

# Explore model metadata
puts "Schema: #{Product.schema.name}"        # => "store_database"
puts "Table: #{Product.table}"               # => :products
puts "Adapter: #{Product.adapter}"           # => CQL::Adapter::SQLite

# Inspect table structure
Product.table_columns.each do |name, column|
  puts "Column #{name}: #{column.class}"
end
# Output:
# Column id: CQL::PrimaryKey(Int32)
# Column name: CQL::Column(String)
# Column price: CQL::Column(Float64)
# Column category: CQL::Column(String)
# Column active: CQL::Column(Bool)

# Get specific column info
name_column = Product.table_column(:name)
puts "Name column expression: #{name_column}"
```

#### Using Build Method for Factories

```crystal
class UserFactory
  def self.create_user(type : Symbol)
    case type
    when :admin
      User.new(
        "Admin User",
        "admin@example.com",
        35,
        "admin_password"
      )
    when :regular
      User.new(
        "Regular User",
        "user@example.com",
        25,
        "user_password"
      )
    when :guest
      User.new(
        "Guest User",
        "guest@example.com",
        0
      )
    else
      raise "Unknown user type: #{type}"
    end
  end
end

# Usage
admin = UserFactory.create_user(:admin)
regular = UserFactory.create_user(:regular)
guest = UserFactory.create_user(:guest)

admin.save!    # Persist to database
regular.save!  # Persist to database
guest.save!    # Persist to database
```

#### Dynamic Model Information

```crystal
# Get adapter-specific information
def database_info(model_class)
  schema = model_class.schema
  adapter = model_class.adapter
  table = model_class.table

  puts "Model: #{model_class.name}"
  puts "Database: #{schema.name}"
  puts "Adapter: #{adapter}"
  puts "Table: #{table}"
  puts "Columns: #{model_class.table_columns.keys.join(", ")}"
end

database_info(User)
database_info(Product)
```

#### Multi-Database Setup

```crystal
# Primary database
class User
  include CQL::ActiveRecord::Model(Int32)
  db_context PrimaryDB, :users

  property id : Int32?
  property name : String
  property email : String

  def initialize(@name : String, @email : String)
  end
end

# Analytics database
class UserAnalytics
  include CQL::ActiveRecord::Model(Int32)
  db_context AnalyticsDB, :user_analytics

  property id : Int32?
  property user_id : Int32
  property page_views : Int32
  property last_activity : Time

  def initialize(@user_id : Int32, @page_views : Int32 = 0, @last_activity : Time = Time.utc)
  end
end

# Check which database each model uses
puts "User schema: #{User.schema.name}"              # => "primary_database"
puts "Analytics schema: #{UserAnalytics.schema.name}" # => "analytics_database"

# Different adapters possible
puts "User adapter: #{User.adapter}"              # => CQL::Adapter::Postgres
puts "Analytics adapter: #{UserAnalytics.adapter}" # => CQL::Adapter::SQLite
```

### Best Practices

#### Consistent Naming

* Use descriptive model class names that match your domain
* Follow Crystal naming conventions (PascalCase for classes)
* Use plural table names (`:users`, `:products`, `:order_items`)

#### Database Context Organization

```crystal
# Good: Clear database contexts
class User
  include CQL::ActiveRecord::Model(UUID)
  db_context UserDB, :users         # User management database

  property id : UUID?
  property name : String
  property email : String

  def initialize(@name : String, @email : String)
  end
end

class InventoryItem
  include CQL::ActiveRecord::Model(Int32)
  db_context InventoryDB, :items    # Inventory database

  property id : Int32?
  property name : String
  property quantity : Int32

  def initialize(@name : String, @quantity : Int32 = 0)
  end
end

class AnalyticsEvent
  include CQL::ActiveRecord::Model(ULID)
  db_context AnalyticsDB, :events   # Analytics database

  property id : ULID?
  property event_type : String
  property occurred_at : Time

  def initialize(@event_type : String, @occurred_at : Time = Time.utc)
  end
end
```

#### Metadata Inspection for Development

```crystal
# Development helper to inspect all models
def inspect_models(*model_classes)
  model_classes.each do |model_class|
    puts "\n=== #{model_class.name} ==="
    puts "Table: #{model_class.table}"
    puts "Schema: #{model_class.schema.name}"
    puts "Adapter: #{model_class.adapter}"
    puts "Columns:"

    model_class.table_columns.each do |name, column|
      puts "  #{name}: #{column.class}"
    end
  end
end

# Usage during development
inspect_models(User, Product, AnalyticsEvent)
```

***

These model definition methods provide powerful introspection capabilities and help you work dynamically with your models while maintaining type safety. They're particularly useful for building developer tools, debugging, and creating flexible application architectures.
