# Create Indexes

This guide shows you how to create database indexes to improve query performance.

## Create a Simple Index

```crystal
class AddEmailIndex < CQL::Migration(5)
  def up
    schema.alter :users do
      create_index :idx_users_email, [:email]
    end
  end

  def down
    schema.alter :users do
      drop_index :idx_users_email
    end
  end
end
```

## Create a Unique Index

```crystal
class AddUniqueEmailIndex < CQL::Migration(6)
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

## Create a Composite Index

Index multiple columns together:

```crystal
class AddUserStatusIndex < CQL::Migration(7)
  def up
    schema.alter :users do
      create_index :idx_users_status_created, [:status, :created_at]
    end
  end

  def down
    schema.alter :users do
      drop_index :idx_users_status_created
    end
  end
end
```

## Index on Foreign Keys

Always index foreign key columns:

```crystal
class AddPostIndexes < CQL::Migration(8)
  def up
    schema.alter :posts do
      create_index :idx_posts_user_id, [:user_id]
      create_index :idx_posts_category_id, [:category_id]
    end
  end

  def down
    schema.alter :posts do
      drop_index :idx_posts_user_id
      drop_index :idx_posts_category_id
    end
  end
end
```

## Index for Frequently Filtered Columns

```crystal
class AddFilterIndexes < CQL::Migration(9)
  def up
    schema.alter :posts do
      create_index :idx_posts_published, [:published]
      create_index :idx_posts_created_at, [:created_at]
    end
  end

  def down
    schema.alter :posts do
      drop_index :idx_posts_published
      drop_index :idx_posts_created_at
    end
  end
end
```

## Index for Soft Deletes

```crystal
class AddDeletedAtIndex < CQL::Migration(10)
  def up
    schema.alter :users do
      create_index :idx_users_deleted_at, [:deleted_at]
    end
  end

  def down
    schema.alter :users do
      drop_index :idx_users_deleted_at
    end
  end
end
```

## Unique Composite Index

Prevent duplicate combinations:

```crystal
class AddUniquePostTag < CQL::Migration(11)
  def up
    schema.alter :post_tags do
      create_index :idx_post_tags_unique, [:post_id, :tag_id], unique: true
    end
  end

  def down
    schema.alter :post_tags do
      drop_index :idx_post_tags_unique
    end
  end
end
```

## Index Naming Convention

Use consistent naming:

```
idx_{table}_{column}          # Simple index
idx_{table}_{col1}_{col2}     # Composite index
idx_{table}_{column}_unique   # Unique index (optional suffix)
```

## When to Create Indexes

Create indexes for:
- Primary keys (automatic)
- Foreign keys
- Columns used in WHERE clauses
- Columns used in ORDER BY
- Columns used in JOIN conditions
- Columns with unique constraints

## When NOT to Create Indexes

Avoid unnecessary indexes on:
- Small tables (< 1000 rows)
- Columns with low cardinality (few unique values)
- Tables with frequent writes (indexes slow down inserts)
- Columns rarely used in queries

## Verify Index Works

```crystal
migrator.up

# Index should speed up this query
User.where(email: "john@example.com").first
```

## Related

- [Create a Migration](create-migration.md)
- [Add Columns](add-columns.md)
- [Optimize Queries](../performance/optimize-queries.md)
