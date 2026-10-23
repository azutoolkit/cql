# Create a Migration

This guide shows you how to create database migrations to manage schema changes.

## Migration File Structure

Create migration files in a `migrations/` directory:

```
migrations/
├── 001_create_users.cr
├── 002_create_posts.cr
└── 003_add_email_index.cr
```

## Basic Migration

```crystal
# migrations/001_create_users.cr
class CreateUsers < CQL::Migration(1)
  def up
    schema.table :users do
      primary :id, Int64, auto_increment: true
      column :name, String, null: false
      column :email, String, null: false
      timestamps
    end

    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end
```

A migration registers itself with `CQL::Migrator` when its class is defined, so `require` every migration file before running the migrator. `up` and `down` receive no arguments; the schema is available as `schema`. `schema.table :users do ... end` declares the table and `schema.users.create!` / `schema.users.drop!` create and drop it.

## Migration Number

The number in `CQL::Migration(N)` is the version (stored as `Int64`) and must be unique; migrations run in ascending version order. Use sequential numbers or timestamps:

```crystal
class CreateUsers < CQL::Migration(1)              # Sequential
class CreatePosts < CQL::Migration(2)
class AddIndexes < CQL::Migration(20250125120000)  # Timestamp format
```

## Create Table

```crystal
def up
  schema.table :posts do
    primary :id, Int64, auto_increment: true
    column :title, String, null: false
    column :body, String, null: false
    column :published, Bool, default: false
    column :user_id, Int64, null: false
    timestamps

    foreign_key [:user_id], references: :users, references_columns: [:id]
  end

  schema.posts.create!

  # Indexes are created separately; `index` inside the table block is not emitted by create!
  schema.alter :posts do
    create_index :idx_posts_user_id, [:user_id]
    create_index :idx_posts_published, [:published]
  end
end

def down
  schema.posts.drop!
end
```

## Add Columns

`schema.alter :users` looks the table up in the schema and raises `CQL::Schema::Error` ("Table 'users' not found") if it was never declared, so declare it with `schema.table` or load your generated schema file first.

```crystal
class AddAvatarToUsers < CQL::Migration(4)
  def up
    schema.alter :users do
      add_column :avatar_url, String, null: true
      add_column :bio, String, null: true
    end
  end

  def down
    schema.alter :users do
      drop_column :avatar_url
      drop_column :bio
    end
  end
end
```

## Add Index

```crystal
class AddEmailIndex < CQL::Migration(5)
  def up
    schema.alter :users do
      create_index :idx_users_email, [:email], unique: true
    end
  end

  def down
    schema.alter :users do
      drop_index :idx_users_email
    end
  end
end
```

## Add Foreign Key

Not supported on SQLite (`CQL::SQLiteUnsupportedFeatureError`): declare `foreign_key` inside the `schema.table` block when creating the table instead.

```crystal
class AddPostsForeignKey < CQL::Migration(6)
  def up
    schema.alter :posts do
      foreign_key [:user_id], references: :users, references_columns: [:id], on_delete: :cascade
    end
  end

  def down
    schema.alter :posts do
      drop_foreign_key :fk_posts_user_id
    end
  end
end
```

## Rename Column

```crystal
class RenameUserName < CQL::Migration(7)
  def up
    schema.alter :users do
      rename_column :name, :full_name
    end
  end

  def down
    schema.alter :users do
      rename_column :full_name, :name
    end
  end
end
```

## Change Column Type

PostgreSQL, CockroachDB and MySQL only: SQLite raises `CQL::SQLiteUnsupportedFeatureError` for `change_column` (as it does for `foreign_key` and `drop_foreign_key` in `schema.alter`). Recreate the table instead.

```crystal
class ChangeViewsCount < CQL::Migration(8)
  def up
    schema.alter :posts do
      change_column :views_count, Int64
    end
  end

  def down
    schema.alter :posts do
      change_column :views_count, Int32
    end
  end
end
```

## Irreversible Migration

Some migrations can't be reversed:

```crystal
class RemoveOldColumn < CQL::Migration(9)
  def up
    schema.alter :users do
      drop_column :legacy_field
    end
  end

  def down
    raise "Cannot reverse: data would be lost"
  end
end
```

## Verify Migration

Create a simple test:

```crystal
# Test migration (auto_sync: false keeps it from rewriting your schema file)
migrator = MyDB.migrator(CQL::MigratorConfig.new(auto_sync: false))
migrator.up

# Check table exists
User.count  # Should not raise
```

## Related

- [Run Migrations](run-migrations.md)
- [Rollback Migrations](rollback.md)
- [Add Columns](add-columns.md)
- [Migration DSL Reference](../../reference/api/migration-dsl.md)
