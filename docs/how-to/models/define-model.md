# Define a Model

This guide shows you how to define a CQL Active Record model that maps to a database table.

## Basic Model Definition

To define a model, create a struct or class that includes the Active Record module:

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :users

  property id : Int64?
  property name : String
  property email : String
  property created_at : Time?
  property updated_at : Time?

  def initialize(@name : String, @email : String)
  end
end
```

## Key Components

### 1. Include the Active Record Module

```crystal
include CQL::ActiveRecord::Model(Int64)
```

The type parameter specifies your primary key type: `Int32`, `Int64`, `UUID`, or `String` (for ULIDs).

### 2. Set the Database Context

```crystal
db_context MyDB, :users
```

This connects the model to a specific schema and table.

CQL also records this mapping for optional strict schema validation. To verify model getter types against schema column types when your application boots, run with:

```bash
CQL_VALIDATE_SCHEMA_MAPPINGS=1 crystal run src/app.cr
```

This raises a `CQL schema mapping error` if a model getter type disagrees with the schema column type. The check is opt-in because many applications intentionally omit database columns from a model or allow nil values while a record is transient.

### 3. Define Properties

```crystal
property id : Int64?          # Primary key (nullable for new records)
property name : String        # Required field
property active : Bool = false  # With default value
property bio : String?        # Nullable field
property created_at : Time?   # Timestamp
property updated_at : Time?   # Timestamp
```

### 4. Create a Constructor

```crystal
def initialize(@name : String, @email : String)
end
```

## Primary Key Types

### Integer (default)

```crystal
struct Product
  include CQL::ActiveRecord::Model(Int64)
  db_context StoreDB, :products

  property id : Int64?
  # ...
end
```

### UUID

```crystal
struct Session
  include CQL::ActiveRecord::Model(UUID)
  db_context MyDB, :sessions

  property id : UUID?
  # ...
end
```

### ULID (for sortable IDs)

```crystal
struct Event
  include CQL::ActiveRecord::Model(String)
  db_context EventDB, :events

  property id : String?
  # ...
end
```

## Excluding Fields from Persistence

Use the `DB::Field` annotation to exclude virtual fields:

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :users

  property id : Int64?
  property name : String
  property password : String?

  @[DB::Field(ignore: true)]
  property password_confirmation : String?

  def initialize(@name : String, @password : String? = nil, @password_confirmation : String? = nil)
  end
end
```

## Adding Custom Methods

Add business logic directly in your model:

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :users

  property id : Int64?
  property first_name : String
  property last_name : String
  property email : String

  def initialize(@first_name : String, @last_name : String, @email : String)
  end

  def full_name : String
    "#{first_name} #{last_name}"
  end

  def email_domain : String
    email.split("@").last
  end
end
```

## Verify Your Model

Test that your model works:

```crystal
# Create an instance
user = User.new("John", "john@example.com")

# Check attributes
user.name      # => "John"
user.id        # => nil (not saved yet)

# Save to database
user.save
user.id        # => 1 (now assigned)

# Find it again
found = User.find(user.id)
```

## Common Issues

**"No database context defined"**: Ensure you called `db_context` with correct schema and table.

**"Could not find column"**: Property names must match database column names.

**"Type mismatch"**: Crystal property types must match database column types.

**"CQL schema mapping error"**: You enabled `CQL_VALIDATE_SCHEMA_MAPPINGS=1` and a model getter type does not match the schema column type. Update either the schema or the model property type.

## Related

- [Add Validations](add-validations.md)
- [Use Callbacks](use-callbacks.md)
- [Set Up Relationships](../relationships/belongs-to.md)
- [Fix Schema Mapping Errors](../troubleshooting/schema-mapping-errors.md)
