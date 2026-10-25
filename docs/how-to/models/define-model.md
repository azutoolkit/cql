# Define a Model

This guide shows you how to define a CQL Active Record model that maps to a database table.

## Basic Model Definition

To define a model, create a struct or class that includes the Active Record module:

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)

  property id : Int64?
  property name : String
  property email : String
  property created_at : Time?
  property updated_at : Time?

  def initialize(@name : String, @email : String)
  end
end
```

`User` maps to the `users` table of the schema whose `CQL::Schema.define` block declares `table :users` (see [step 2](#2-map-the-model-to-a-schema-and-table)). Add `db_context` only when that inference is not enough.

## Key Components

### 1. Include the Active Record Module

```crystal
include CQL::ActiveRecord::Model(Int64)
```

The type parameter specifies your primary key type: `Int32`, `Int64`, `UUID`, or `String` (for ULIDs).

The module provides `id`, `id!`, `id?` and `id=` for you, typed as `Pk?` (for example `Int64?`). Declaring `property id : Int64?` yourself, as the examples below do, is optional.

### 2. Map the Model to a Schema and Table

`db_context` is optional. Without it, CQL maps the model to:

- **The table** named after its type, underscored and pluralized: `User` to `:users`, `OrderItem` to `:order_items`, `Category` to `:categories`, `Box` to `:boxes`. Only the last namespace segment counts, so `Shop::OrderItem` also maps to `:order_items`.
- **The schema** that declares that table: the `CQL::Schema.define(...) do ... end` constant, in the model's enclosing namespaces or at the top level, whose block contains `table :users do ... end`. It is found at compile time.

Give `db_context` one argument to override just that part, and CQL infers the other:

```crystal
db_context table: :people   # schema: the one declaring :people
db_context schema: AppDB    # table: :users, from the type name
```

`db_context AppDB, :users` and `db_context schema: AppDB, table: :users` pin both.

Write `db_context` yourself when:

- **The plural is irregular.** `Person` maps to `:persons`, so write `db_context table: :people`.
- **Several schemas declare the table.** Name one, for example in a multi-database app: `db_context AppDB, :users`.
- **The schema is out of the lookup's sight.** Only literal `table :name` calls written directly in the `define` block are seen. Tables added later with `Schema.new` and `.table`, through helper macros, or wrapped in `{% if %}` or `begin` are not. A `private` schema constant inside a namespace cannot be referenced by the generated code either.

When no `define` block declares the table, or several do, the model still compiles and `Model.schema` raises `CQL::ActiveRecord::SchemaMappingError` on its first call. See [Fix Schema Mapping Errors](../troubleshooting/schema-mapping-errors.md).

CQL also records the mapping for optional strict schema validation. To verify model getter types against schema column types when your application boots, run with:

```bash
CQL_VALIDATE_SCHEMA_MAPPINGS=1 crystal run src/app.cr
```

This raises a `CQL schema mapping error` if a model getter type disagrees with the schema column type. Models whose schema was inferred are checked too; a model with no resolvable schema is skipped at startup. The check is opt-in because many applications intentionally omit database columns from a model or allow nil values while a record is transient.

### 3. Define Properties

```crystal
property id : Int64?          # Primary key (optional; provided by the module)
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

### Integer

```crystal
struct Product
  include CQL::ActiveRecord::Model(Int64)
  db_context StoreDB, :products

  property id : Int64?
  # ...
end
```

### UUID

`UUID` keys are generated client-side on insert and stored as text, so the column is `primary :id, String, auto_increment: false` (see `spec/patterns/active_record/uuid_primary_key_spec.cr`).

```crystal
struct Session
  include CQL::ActiveRecord::Model(UUID)
  db_context MyDB, :sessions

  property id : UUID?
  # ...
end
```

### ULID (for sortable IDs)

`Model(String)` primary keys are filled with a 26-character ULID on insert. Declare the column as `primary :id, String, auto_increment: false`.

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
found = User.find(user.id!)    # => User? (nil when no row matches)
```

## Common Issues

**`CQL::ActiveRecord::SchemaMappingError` from `User.schema` ("no `CQL::Schema.define` block declares table" or "all declare table")**: CQL could not infer the model's schema. Add `db_context` with the schema constant and the table symbol.

**Query or insert fails on an unknown column**: Property names must match database column names. Use `@[DB::Field(ignore: true)]` for properties that are not columns.

**Type mismatch when reading rows**: Crystal property types must match database column types.

**"CQL schema mapping error"**: You enabled `CQL_VALIDATE_SCHEMA_MAPPINGS=1` and a model getter type does not match the schema column type. Update either the schema or the model property type.

## Related

- [Add Validations](add-validations.md)
- [Use Callbacks](use-callbacks.md)
- [Set Up Relationships](../relationships/belongs-to.md)
- [Fix Schema Mapping Errors](../troubleshooting/schema-mapping-errors.md)
