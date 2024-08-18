---
title: "Cql::Migration"
---

# class Cql::Migration

`Reference` < `Object`

Migrations are used to manage changes to the database schema over time.
Each migration is a subclass of `Migration` and must implement the `up` and `down` methods.

The `up` method is used to apply the migration, while the `down` method is used to rollback the migration.
Migrations are executed in their version order defined.
The `Migrator` class is used to manage migrations and provides methods to apply, rollback, and redo migrations.
The `Migrator` class also provides methods to list applied and pending migrations.

**Example** Creating a new migration

```crystal
class CreateUsersTable < Cql::Migration
  self.version = 1_i64

  def up
    schema.alter :users do
      add_column :name, String
      add_column :age, Int32
    end
  end

  def down
    schema.alter :users do
      drop_column :name
      drop_column :age
    end
  end
end
```

**Example** Applying migrations

```crystal
schema = Cql::Schema.build(:northwind, "sqlite3://db.sqlite3") do |s|
  table :schema_migrations do
    primary :id, Int32
    column :name, String
    column :version, Int64, index: true, unique: true
    timestamps
  end
end
migrator = Cql::Migrator.new(schema)
migrator.up
```

**Example** Rolling back migrations

```crystal
migrator.down
```

**Example** Redoing migrations

```crystal
migrator.redo
```

**Example** Rolling back to a specific version

```crystal
migrator.down_to(1_i64)
```

**Example** Applying to a specific version

```crystal
migrator.up_to(1_i64)
```

**Example** Listing applied migrations

```crystal
migrator.print_applied_migrations
```

**Example** Listing pending migrations

```crystal
migrator.print_pending_migrations
```

**Example** Listing rolled back migrations

```crystal
migrator.print_rolled_back_migrations
```

**Example** Listing the last migration

```crystal
migrator.last
```

details Table of Contents
[[toc]]

## Constructors

### def new`(schema : Schema)`

## Instance Methods

### def down

### def schema

### def up
