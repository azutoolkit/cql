# Fix Schema Mapping Errors

CQL can validate model getter types against schema column types when your application starts.

Enable it with:

```bash
CQL_VALIDATE_SCHEMA_MAPPINGS=1 crystal run src/app.cr
```

When enabled, CQL reads the `db_context` mapping for each model and compares the model's zero-argument getters with the corresponding table columns.

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
  db_context MyDB, :users

  property name : String
end
```

Or change the schema column type if the model type is correct.

## What Is Checked

CQL checks columns that have matching model getters. It does not require every schema column to appear on the model, which lets you omit database-managed columns or fields that are not part of the public model.

The validator also allows UUID model getters backed by string database storage, which is the standard CQL UUID storage path.

## Why It Is Opt-In

Some models intentionally allow nil while records are transient, before database defaults, foreign keys, or generated primary keys are assigned. For that reason, strict schema mapping validation focuses on concrete type mismatches and is disabled by default.

Use it in CI, staging, or production boot checks when you want an extra guardrail against schema drift.
