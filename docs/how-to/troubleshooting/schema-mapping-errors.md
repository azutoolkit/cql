# Fix Schema Mapping Errors

Run CQL's check that model getter types match the schema's columns, then fix each `CQL::ActiveRecord::SchemaMappingError` it raises.

## Run the check where it can finish

The check runs only when `CQL_VALIDATE_SCHEMA_MAPPINGS` is exactly `1`, and it runs after all of the program's top-level code. An app that starts a blocking server at the top level never reaches it, so run it from your specs or from a script that loads the models and exits:

```bash
# ✅ Specs start after top-level code: a mapping error aborts the run before any example (exit 1)
CQL_VALIDATE_SCHEMA_MAPPINGS=1 crystal spec

# ✅ A script that requires the schema and models but starts no server
CQL_VALIDATE_SCHEMA_MAPPINGS=1 crystal run src/check_mappings.cr

# ❌ Never checks: the server blocks before the check runs
CQL_VALIDATE_SCHEMA_MAPPINGS=1 crystal run src/app.cr
```

```crystal
# src/check_mappings.cr: require your schema and models, nothing that serves requests
require "./config/cql"
require "./models/**"
```

For each model with a schema (from `db_context`, or inferred), CQL compares the zero-argument getters with the table's columns. It skips columns the model has no getter for, ignores nilability, and accepts a `UUID` getter over a `String` column. It is opt-in because models often allow `nil` while a record is transient.

## Fix type mismatches

```text
CQL schema mapping error in User: schema column `users.name` type String does not match model getter `name` type Int32. Update the schema column or the model property type.
```

```crystal
AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./db/app.db") do
  table :users do
    primary :id, Int64
    text :name
  end
end

class User
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: AppDB, table: :users

  property name : String = "" # ❌ was Int32
end
```

Or change the column if the model is right.

## Fix a table the schema does not define

```text
CQL schema mapping error in Post: table `posts` is not defined in schema `app_db`.
```

Declare `table :posts` in the schema block, or point `db_context` at the right table.

## Fix Primary Key Mismatches

```text
CQL schema mapping error in Label: table `labels` declares primary key `label_no`, but the model maps `id` to `id`. Declare `db_context ..., primary_key: :label_no` on the model.
```

Declare the schema's key column on the model, as in [Primary Key on Another Column](../models/define-model.md#primary-key-on-another-column):

```crystal
class Label
  include CQL::ActiveRecord::Model(Int32)
  db_context AppDB, :labels, primary_key: :label_no

  property name : String = ""
end
```

Or rename the schema's `primary` column to `id`. A table with no declared primary key is not checked.

## Fix a schema that cannot be inferred

A model without a schema in `db_context` finds one at compile time: the single `CQL::Schema.define` block that declares its table. When there is none, or more than one, the model still compiles and `Model.schema` raises on its first call, whether or not the check is on. The check skips such models.

```text
CQL schema mapping error in Person: no `CQL::Schema.define` block declares table `persons`. Declare the table in a schema, or add `db_context MySchema, :persons` to Person.
CQL schema mapping error in Account: schemas `::AppDB`, `::ReplicaDB` all declare table `accounts`. Add `db_context <one of them>, :accounts` to Account to pick one.
```

```crystal
class Person
  include CQL::ActiveRecord::Model(Int64)
  db_context table: :people # Person maps to :persons by default
end

class Account
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :accounts # pick one of the schemas
end
```

If the table is declared and the first error still appears, the lookup cannot see it. It reads only literal `table :name` calls written directly in the `define` block: not tables added later with `Schema.new` and `.table`, through helper macros, or inside `{% if %}` or `begin`. It cannot reference a `private` schema constant in a namespace either. Name the schema in `db_context` in these cases.

## See Also

- [Define a Model](../models/define-model.md)
- [Dump and Validate Your Schema](../migrations/schema-dump-and-validation.md)
- [Fix Migration Errors](migration-errors.md)
- [Fix Validation Errors](validation-errors.md)
