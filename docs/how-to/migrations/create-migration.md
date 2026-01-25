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
    schema.create :users do
      primary :id, Int64, auto_increment: true
      text :name, null: false
      text :email, null: false
      timestamps
    end
  end

  def down
    schema.drop :users
  end
end
```

## Migration Number

The number in `CQL::Migration(N)` must be unique and sequential:

```crystal
class CreateUsers < CQL::Migration(1)      # First migration
class CreatePosts < CQL::Migration(2)      # Second migration
class AddIndexes < CQL::Migration(3)       # Third migration
```

## Create Table

```crystal
def up
  schema.create :posts do
    primary :id, Int64, auto_increment: true
    text :title, null: false
    text :body, null: false
    boolean :published, default: false
    bigint :user_id, null: false
    timestamps

    foreign_key [:user_id], references: :users, references_columns: [:id]
  end
end
```

## Add Columns

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

```crystal
class AddPostsForeignKey < CQL::Migration(6)
  def up
    schema.alter :posts do
      add_foreign_key [:user_id], references: :users, references_columns: [:id], on_delete: "CASCADE"
    end
  end

  def down
    schema.alter :posts do
      drop_foreign_key [:user_id]
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

```crystal
class ChangeViewsCount < CQL::Migration(8)
  def up
    schema.alter :posts do
      change_column :views_count, Int64, default: 0_i64
    end
  end

  def down
    schema.alter :posts do
      change_column :views_count, Int32, default: 0
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
# Test migration
MyDB.init
migrator = MyDB.migrator(config)
migrator.up

# Check table exists
User.count  # Should not raise
```

## Related

- [Run Migrations](run-migrations.md)
- [Rollback Migrations](rollback.md)
- [Add Columns](add-columns.md)
