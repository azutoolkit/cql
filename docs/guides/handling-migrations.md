# Handling Migrations

Migrations in CQL provide a structured way to evolve your database schema over time. They allow you to create, modify, and drop tables and columns in a versioned, reversible manner using Crystal code.

---

## What is a Migration?

A migration is a Crystal class that defines changes to your database schema. Each migration has a unique version number and two methods:

- `up`: Applies the migration (e.g., creates or alters tables).
- `down`: Reverts the migration (e.g., drops or reverts changes).

---

## Creating a Migration

Create a new migration by subclassing `CQL::Migration` and setting a unique version:

```crystal
class CreateUsers < CQL::Migration
  self.version = 1_i64

  def up
    schema.create :users do
      primary_key :id, :serial
      column :name, :string
      column :email, :string
      column :active, :bool, default: false
      column :created_at, :timestamp
      column :updated_at, :timestamp
    end
  end

  def down
    schema.drop :users
  end
end
```

- `self.version` must be unique and increasing (often a timestamp or integer).
- The `up` method defines the schema changes to apply.
- The `down` method defines how to revert those changes.

---

## Running Migrations

You can run migrations using your preferred migration runner or a custom script. A typical workflow:

1. Place migration files in a `db/migrations/` directory.
2. Load and apply migrations in order:

```crystal
require "cql"

# Load all migration files
dir = "./db/migrations"
Dir.glob("#{dir}/*.cr").each { |file| require file }

# Run all migrations (pseudo-code, depends on your runner)
CQL::Migrator.new(AcmeDB).migrate!
```

Consult your project's migration runner or CQL's documentation for details on migration management.

---

## Modifying Tables

You can alter existing tables in a migration:

```crystal
class AddAgeToUsers < CQL::Migration
  self.version = 2_i64

  def up
    schema.alter :users do
      add_column :age, :int32
    end
  end

  def down
    schema.alter :users do
      drop_column :age
    end
  end
end
```

---

## Best Practices

- Use a unique, increasing version for each migration.
- Write reversible migrations (always provide a `down` method).
- Keep migrations in version control.
- Test migrations on a development database before running in production.
- Use descriptive class names (e.g., `AddAgeToUsers`).

---

## Example: Multiple Migrations

```crystal
class CreatePosts < CQL::Migration
  self.version = 3_i64

  def up
    schema.create :posts do
      primary_key :id, :serial
      column :user_id, :int32
      column :title, :string
      column :body, :string
      column :created_at, :timestamp
    end
  end

  def down
    schema.drop :posts
  end
end

class AddIndexToUsersEmail < CQL::Migration
  self.version = 4_i64

  def up
    schema.alter :users do
      add_index :email, unique: true
    end
  end

  def down
    schema.alter :users do
      drop_index :email
    end
  end
end
```

---

For more on defining models and querying, see the other guides in this directory.
