# Add Columns

This guide shows you how to add columns to existing tables using migrations.

## Add a Single Column

```crystal
class AddAvatarToUsers < CQL::Migration(5)
  def up
    schema.alter :users do
      add_column :avatar_url, String, null: true
    end
  end

  def down
    schema.alter :users do
      drop_column :avatar_url
    end
  end
end
```

## Add Multiple Columns

```crystal
class AddProfileFieldsToUsers < CQL::Migration(6)
  def up
    schema.alter :users do
      add_column :bio, String, null: true
      add_column :website, String, null: true
      add_column :location, String, null: true
    end
  end

  def down
    schema.alter :users do
      drop_column :bio
      drop_column :website
      drop_column :location
    end
  end
end
```

## Add Column with Default

```crystal
class AddActiveToUsers < CQL::Migration(7)
  def up
    schema.alter :users do
      add_column :active, Bool, default: true, null: false
    end
  end

  def down
    schema.alter :users do
      drop_column :active
    end
  end
end
```

## Add Column with Index

```crystal
class AddSlugToPosts < CQL::Migration(8)
  def up
    schema.alter :posts do
      add_column :slug, String, null: true
    end

    schema.alter :posts do
      create_index :idx_posts_slug, [:slug], unique: true
    end
  end

  def down
    schema.alter :posts do
      drop_index :idx_posts_slug
      drop_column :slug
    end
  end
end
```

## Add Foreign Key Column

```crystal
class AddCategoryToPosts < CQL::Migration(9)
  def up
    schema.alter :posts do
      add_column :category_id, Int64, null: true
    end

    schema.alter :posts do
      create_index :idx_posts_category_id, [:category_id]
      add_foreign_key [:category_id], references: :categories, references_columns: [:id], on_delete: "SET NULL"
    end
  end

  def down
    schema.alter :posts do
      drop_foreign_key [:category_id]
      drop_index :idx_posts_category_id
      drop_column :category_id
    end
  end
end
```

## Add Timestamp Columns

```crystal
class AddTimestampsToPosts < CQL::Migration(10)
  def up
    schema.alter :posts do
      add_column :created_at, Time, null: true
      add_column :updated_at, Time, null: true
    end

    # Optionally set current time for existing records
    schema.exec("UPDATE posts SET created_at = NOW(), updated_at = NOW() WHERE created_at IS NULL")
  end

  def down
    schema.alter :posts do
      drop_column :created_at
      drop_column :updated_at
    end
  end
end
```

## Add Column for Soft Deletes

```crystal
class AddDeletedAtToUsers < CQL::Migration(11)
  def up
    schema.alter :users do
      add_column :deleted_at, Time, null: true
    end

    schema.alter :users do
      create_index :idx_users_deleted_at, [:deleted_at]
    end
  end

  def down
    schema.alter :users do
      drop_index :idx_users_deleted_at
      drop_column :deleted_at
    end
  end
end
```

## Add Version Column for Locking

```crystal
class AddVersionToUsers < CQL::Migration(12)
  def up
    schema.alter :users do
      add_column :version, Int32, default: 1, null: false
    end
  end

  def down
    schema.alter :users do
      drop_column :version
    end
  end
end
```

## Update Model After Migration

After running the migration, update your model:

```crystal
struct User
  # Existing properties...

  # New property
  property avatar_url : String?

  # Don't forget to update constructor if needed
  def initialize(@name : String, @email : String, @avatar_url : String? = nil)
  end
end
```

## Verify Column Added

```crystal
migrator.up

# Test the new column works
user = User.create!(name: "John", email: "john@example.com", avatar_url: "/avatars/john.png")
user.avatar_url  # => "/avatars/john.png"
```

## Related

- [Create a Migration](create-migration.md)
- [Create Indexes](indexes.md)
- [Migration DSL Reference](../../reference/api/migration-dsl.md)
