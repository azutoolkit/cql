# Defining Models in CQL Active Record

CQL Active Record models are Crystal classes or structs that map directly to database tables. Each model encapsulates the table's columns as properties, provides type-safe access to data, and includes methods for persistence, querying, and associations.

---

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

- Use `class` or `struct` for models (both are supported)
- `include CQL::ActiveRecord::Model(PkType)` provides all Active Record functionality
- The type parameter specifies the primary key type (e.g., `Int32`, `Int64`, `UUID`, `ULID`)
- `db_context DatabaseSchema, :table_name` links the model to a specific table
- Use `property` for each database column
- Nullable types (e.g., `Int32?`, `String?`) are used for columns that may be `NULL` or auto-generated
- Define a constructor to initialize required fields

---

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
end
```

---

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

- Mass assignment only updates the instance in memory - call `save` to persist changes
- Invalid attribute names are ignored silently
- Attributes with incorrect types are ignored silently
- Only existing model properties can be set

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

---

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

---

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

---

## Best Practices

- **Use appropriate types**: Match Crystal types to your database column types
- **Make auto-generated fields nullable**: Primary keys and timestamps should be nullable (`Int32?`, `Time?`)
- **Provide constructors**: Define constructors for required fields to ensure valid object creation
- **Use `@[DB::Field(ignore: true)]`**: For computed fields or temporary values that shouldn't be persisted
- **Be careful with mass assignment**: Validate input when using `attributes` method with user data
- **Follow naming conventions**: Use snake_case for database columns and property names

---

For more information on model persistence, querying, and relationships, see the other guides in this directory.
