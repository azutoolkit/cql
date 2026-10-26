---
description: "Map a class to a table by including CQL::ActiveRecord::Model(Pk), where Pk is the primary key type."
---

# Define a Model

## Write the Model

{% code title="src/database.cr" %}
```crystal
AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./app.db") do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String
    column :email, String
    column :bio, String, null: true
    column :active, Bool, default: true
    timestamps
  end
end
```
{% endcode %}

{% code title="src/models/user.cr" %}
```crystal
class User
  include CQL::ActiveRecord::Model(Int64) # Pk: Int32, Int64, UUID, or String (ULID)

  # One property per column, named after it. id, id!, id? and id= (Int64?) come from the module.
  property name : String = ""
  property email : String = ""
  property bio : String?           # nullable column
  property active : Bool = true
  property created_at : Time?
  property updated_at : Time?

  @[DB::Field(ignore: true)]       # not a column: never read or written
  property password_confirmation : String?

  def initialize                   # User.new
  end

  def initialize(@name : String, @email : String) # User.new("Ada", "ada@example.com")
  end

  def email_domain : String        # business logic lives on the model
    email.split("@").last
  end
end
```
{% endcode %}

```crystal
user = User.new("Ada", "ada@example.com")
user.id          # => nil
user.save        # => true
user.id          # => 1

User.create!(name: "Grace", email: "grace@example.com") # => User, the row as stored
User.find(1)     # => User? (nil when no row matches)
User.find!(99)   # raises DB::NoResultsError: No records found with id=99
```

The model only gets the constructor that reads a row, so write the ones you call. `User.from_hash` needs the one without arguments.

## Map the Model to a Schema and Table

Without `db_context`, CQL infers both at compile time:

```crystal
# Table: the type name's last segment, underscored and pluralized
#   User -> :users, OrderItem -> :order_items, Shop::OrderItem -> :order_items,
#   Category -> :categories, Address -> :addresses, Person -> :persons
# Schema: the one CQL::Schema.define constant, in the model's enclosing namespaces or at the
#   top level, whose block contains `table :users do ... end`

class Person
  include CQL::ActiveRecord::Model(Int64)
  db_context table: :people  # irregular plural; schema inferred: the one declaring :people
end

class Admin
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :users   # both pinned, same as db_context schema: AppDB, table: :users
end

User.table        # => :users
User.schema.name  # => :app_db, AppDB's name
```

Write `db_context` when:

- **The plural is irregular**, as for `Person`.
- **Several schemas declare the table.** Name one: `db_context AppDB, :users`.
- **The lookup cannot see the table.** It reads only literal `table :name` calls written directly in the `define` block, not tables added with `Schema.new` and `.table`, through helper macros, or inside `{% if %}` or `begin`. It cannot reference a `private` schema constant either.

{% hint style="warning" %}
When no `define` block or several declare the table, the model still compiles, and `User.schema` raises `CQL::ActiveRecord::SchemaMappingError` on its first call. See [Fix Schema Mapping Errors](../troubleshooting/schema-mapping-errors.md).
{% endhint %}

## Check Property Types Against the Schema

Run `CQL_VALIDATE_SCHEMA_MAPPINGS=1 crystal spec` to compare every model's property types with its schema columns; see [Validate Models Against the Schema](../migrations/schema-dump-and-validation.md#validate-models-against-the-schema).

## Primary Key on Another Column

Name the key column with `primary_key:` (default `:id`, always a Symbol literal); `id` then reads and writes it:

```crystal
table :labels do      # in AppDB
  primary :label_no, Int32
  text :name
end

class Label
  include CQL::ActiveRecord::Model(Int32)
  db_context AppDB, :labels, primary_key: :label_no
  # also: db_context table: :labels, primary_key: :label_no
  #       db_context schema: AppDB, primary_key: :label_no
  #       db_context primary_key: :label_no (schema and table inferred)

  property name : String = ""

  def initialize
  end
end

Label.primary_key_column                # => :label_no
label = Label.create!(name: "Fragile")
label.id                                # => 1
Label.find!(99)                         # DB::NoResultsError: No records found with label_no=99

# Hashes name real columns; where_primary_key names the key for you
Label.where(label_no: 1).all            # where(id: 1) would look for a column called id
Label.query.where_primary_key([1, 2]).all
# In the typed DSL, id is the key: WHERE labels.label_no = ?
Label.query.where { id == 1 }.order_by(id: :desc).all

# Mass assignment never sets the key, so request params cannot re-point a record
label.attributes({:label_no => 7} of Symbol => DB::Any)
label.id                                # => 1
label.id = 7                            # explicit assignment does
Label.from_hash({:label_no => 7, :name => "x"} of Symbol => DB::Any).id                          # => nil
Label.from_hash({:label_no => 7, :name => "x"} of Symbol => DB::Any, with_primary_key: true).id  # => 7
```

The declared column is used by `find`, `find?`, `find!`, `ids`, `attributes`, create, `save`, `update!`, `touch`, optimistic locking, delete and soft delete, cursor helpers, `insert_all`/`upsert_all`, and associations (`belongs_to` preloads, `has_many` `ids=`, typed `joins`, `many_to_many` targets). Pass `with_primary_key: true` to `from_hash` only for trusted data: the record then saves as an update of that row.

{% hint style="info" %}
A model without `primary_key:` uses `id`. `CQL_VALIDATE_SCHEMA_MAPPINGS=1` reports a table keyed on another column (see [Fix Primary Key Mismatches](../troubleshooting/schema-mapping-errors.md#fix-primary-key-mismatches)).
{% endhint %}

## See Also

- [Add Validations](add-validations.md)
- [Use Callbacks](use-callbacks.md)
- [Use UUID and ULID Primary Keys](uuid-ulid-primary-keys.md)
- [Set Up Belongs To](../relationships/belongs-to.md)
- [Fix Schema Mapping Errors](../troubleshooting/schema-mapping-errors.md)
