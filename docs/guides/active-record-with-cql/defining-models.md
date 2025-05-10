# Defining Models in CQL Active Record

CQL Active Record models are Crystal `struct`s that map directly to database tables. Each model encapsulates the table's columns as properties, provides type-safe access to data, and includes methods for persistence, querying, and associations.

---

## Basic Model Definition

To define a model:

```crystal
# src/models/user.cr
require "cql"

struct User
  # Include Active Record functionality with the primary key type
  include CQL::ActiveRecord::Model(Int32)

  # Map to the 'users' table in the AcmeDB context
  db_context AcmeDB, :users

  # Define properties for each column
  property id : Int32?           # Primary key, nullable if auto-generated
  property name : String
  property email : String
  property active : Bool = false # Default value
  property created_at : Time?
  property updated_at : Time?
end
```

**Key points:**

- Use `struct` for models (Crystal convention for value types).
- `include CQL::ActiveRecord::Model(PkType)` mixes in all Active Record features. The type parameter specifies the primary key type (e.g., `Int32`, `Int64`, `UUID`).
- `db_context AcmeDB, :users` links the model to a specific table in a database context.
- Use `property` for each column. Nullable types (e.g., `Int32?`) are used for columns that may be `NULL` or auto-generated.

---

## Primary Keys

- The primary key type is specified in the `Model` inclusion.
- By convention, the primary key property is named `id`.
- If the primary key is auto-generated, make it nullable (`id : Int32?`).

```crystal
struct Product
  include CQL::ActiveRecord::Model(UUID)
  db_context StoreDB, :products

  property id : UUID?
  property name : String
  property price : Float64
end
```

---

## Working with Attributes

### Individual Attribute Access

Use the generated getter and setter methods:

```crystal
user = User.new(name: "Alice", email: "alice@example.com")
puts user.name  # => "Alice"
user.name = "Bob"
```

### Accessing All Attributes as a Hash

Use the `attributes` method to get a hash of all attribute values:

```crystal
attrs = user.attributes
# => {:id => 1, :name => "Alice", :email => "alice@example.com", ...}
puts attrs[:name]
```

### Mass Assignment

Set multiple attributes at once using a hash or keyword arguments:

```crystal
user = User.new(name: "Placeholder", email: "placeholder@example.com")

# Using a hash
user.attributes = {name: "Jane", email: "jane@example.com", active: true}

# Using keyword arguments
user.attributes(name: "John", email: "john@example.com")
```

**Note:** These methods only update the instance in memory. Call `save` to persist changes.

### Attribute Names

Get all attribute names as symbols:

```crystal
User.attribute_names # => [:id, :name, :email, :active, :created_at, :updated_at]
```

---

## Best Practices

- Use `property` for all columns you want to map.
- Use nullable types for columns that may be `NULL` or auto-generated.
- Use mass assignment carefully, especially with user input.
- Use direct property access for individual attributes; use `attributes` for bulk operations.

---

## Example: Complete Model

```crystal
struct Article
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :articles

  property id : Int64?
  property title : String
  property body : String
  property published : Bool = false
  property author_id : Int32
  property created_at : Time?
  property updated_at : Time?
end
```

---

For more on querying and persistence, see the other guides in this directory.
