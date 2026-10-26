# Fix Schema Mapping Errors

CQL can validate model getter types against schema column types when your application starts.

Enable it with:

```bash
CQL_VALIDATE_SCHEMA_MAPPINGS=1 crystal run src/app.cr
```

When enabled, CQL reads each model's schema and table (from `db_context`, or inferred when it is left out) and compares the model's zero-argument getters with the corresponding table columns.

## Example Error

```text
CQL schema mapping error in User: schema column `users.name` type String does not match model getter `name` type Int32. Update the schema column or the model property type.
```

## Fix Type Mismatches

Make the model property match the schema:

```crystal
schema.table :users do
  primary :id, Int64
  column :name, String
end

class User
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: MyDB, table: :users

  property name : String
end
```

Or change the schema column type if the model type is correct.

If the model's table is not defined in the schema, the error reads ``CQL schema mapping error in User: table `users` is not defined in schema `my_db`.`` Both cases raise `CQL::ActiveRecord::SchemaMappingError`.

## Fix Primary Key Mismatches

The validator also compares the model's primary key with the table's declared one:

```text
CQL schema mapping error in Label: table `labels` declares primary key `label_no`, but the model maps `id` to `id`. Declare `db_context ..., primary_key: :label_no` on the model.
```

Declare the schema's key column on the model, as in [Primary Key on Another Column](../models/define-model.md#primary-key-on-another-column):

```crystal
db_context LabelKeyDB, :labels, primary_key: :label_no
```

Or rename the schema's `primary` column to `id` if the model is right. A table without a declared primary key is not checked.

## Fix a Schema That Cannot Be Inferred

A model without a complete `db_context` finds its schema at compile time. When it cannot, the model still compiles and `Model.schema` raises `CQL::ActiveRecord::SchemaMappingError` on its first call, whether or not validation is enabled. Validation skips such models.

No `CQL::Schema.define` block declares the table:

```text
CQL schema mapping error in Person: no `CQL::Schema.define` block declares table `persons`. Declare the table in a schema, or add `db_context MySchema, :persons` to Person.
```

Declare the table in a schema, or name it. `Person` maps to `:persons`, not `:people`:

```crystal
class Person
  include CQL::ActiveRecord::Model(Int64)
  db_context table: :people
end
```

Several blocks declare the table:

```text
CQL schema mapping error in User: schemas `::PrimaryDB`, `::ReplicaDB` all declare table `users`. Add `db_context <one of them>, :users` to User to pick one.
```

Pick one with `db_context PrimaryDB, :users`.

If the table is declared and the first error still appears, the lookup cannot see it. It reads only literal `table :name` calls written directly in the `define` block, not tables added later with `Schema.new` and `.table`, through helper macros, or inside `{% if %}` or `begin`, and it cannot reference a `private` schema constant in a namespace. Use `db_context` in these cases.

## What Is Checked

CQL checks columns that have matching model getters. It does not require every schema column to appear on the model, which lets you omit database-managed columns or fields that are not part of the public model.

The validator also allows UUID model getters backed by string database storage, which is the standard CQL UUID storage path.

## Why It Is Opt-In

Some models intentionally allow nil while records are transient, before database defaults, foreign keys, or generated primary keys are assigned. For that reason, strict schema mapping validation focuses on concrete type mismatches and is disabled by default.

Use it in CI, staging, or production boot checks when you want an extra guardrail against schema drift.
