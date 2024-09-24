
---
title: "Cql::Migration"
---

# class Cql::Migration

`Reference` < `Object`

Migrations are used to manage changes to the database schema over time. Each migration is a subclass of `Migration` and must implement the `up` and `down` methods. The `up` method applies the migration, while the `down` method rolls back the migration.

Migrations are executed in version order, and the `Migrator` class manages them, providing methods to apply, roll back, and track migrations.

## Example: Creating a Migration

```crystal
class AddEmailToUsers < Cql::Migration
  def up
    schema.alter_table(:users) do
      add_column :email, String
    end
  end

  def down
    schema.alter_table(:users) do
      drop_column :email
    end
  end
end
```

## Methods

### def up

Defines the operations to apply when the migration is run.

- **@return** \[Nil]

**Example**:

```crystal
def up
  schema.alter_table(:users) do
    add_column :email, String
  end
end
```

### def down

Defines the operations to roll back the migration.

- **@return** \[Nil]

**Example**:

```crystal
def down
  schema.alter_table(:users) do
    drop_column :email
  end
end
```

