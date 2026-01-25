# Migration Workflows

This tutorial demonstrates real-world migration workflows for managing database schema changes in production environments.

## What You'll Learn

- Planning schema changes
- Creating safe migrations
- Testing migrations before deployment
- Rolling back when needed
- Handling data migrations

## Prerequisites

- Completed a getting started tutorial
- Understanding of database migrations

## Workflow 1: Adding a New Feature

Let's add a tagging system to a blog application.

### Step 1: Plan the Schema Changes

Before writing code, plan what tables and columns you need:

```
New tables needed:
- tags (id, name, slug)
- post_tags (post_id, tag_id) - join table

New indexes:
- Unique index on tags.slug
- Composite index on post_tags
```

### Step 2: Create the Migrations

Create migrations in the correct order:

```crystal
# migrations/005_create_tags.cr
class CreateTags < CQL::Migration(5)
  def up
    schema.create :tags do
      primary :id, Int64, auto_increment: true
      text :name, null: false
      text :slug, null: false
      timestamps
    end

    schema.alter :tags do
      create_index :idx_tags_slug, [:slug], unique: true
    end
  end

  def down
    schema.drop :tags
  end
end
```

```crystal
# migrations/006_create_post_tags.cr
class CreatePostTags < CQL::Migration(6)
  def up
    schema.create :post_tags do
      bigint :post_id, null: false
      bigint :tag_id, null: false
      timestamp :created_at

      foreign_key [:post_id], references: :posts, references_columns: [:id], on_delete: "CASCADE"
      foreign_key [:tag_id], references: :tags, references_columns: [:id], on_delete: "CASCADE"
    end

    schema.alter :post_tags do
      create_index :idx_post_tags_post, [:post_id]
      create_index :idx_post_tags_tag, [:tag_id]
      create_index :idx_post_tags_unique, [:post_id, :tag_id], unique: true
    end
  end

  def down
    schema.drop :post_tags
  end
end
```

### Step 3: Test Locally

```shell
# Run migrations
crystal src/migrate.cr up

# Verify
crystal src/migrate.cr status
```

### Step 4: Create the Models

```crystal
struct Tag
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :tags

  property id : Int64?
  property name : String
  property slug : String
  property created_at : Time?
  property updated_at : Time?

  has_many :post_tags, PostTag, foreign_key: :tag_id

  def initialize(@name : String)
    @slug = name.downcase.gsub(/[^a-z0-9]+/, "-").strip("-")
  end
end

struct PostTag
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :post_tags

  property post_id : Int64
  property tag_id : Int64
  property created_at : Time?

  belongs_to :post, Post, foreign_key: :post_id
  belongs_to :tag, Tag, foreign_key: :tag_id

  def initialize(@post_id : Int64, @tag_id : Int64)
  end
end
```

## Workflow 2: Modifying Existing Tables

Adding a new column to an existing table requires careful planning.

### Step 1: Plan for Zero Downtime

When adding columns:
- Make new columns nullable OR provide defaults
- Add columns first, then update code
- Never remove columns that existing code depends on

### Step 2: Create the Migration

```crystal
# migrations/007_add_featured_to_posts.cr
class AddFeaturedToPosts < CQL::Migration(7)
  def up
    schema.alter :posts do
      add_column :featured, Bool, default: false
      add_column :featured_at, Time, null: true
    end

    schema.alter :posts do
      create_index :idx_posts_featured, [:featured]
    end
  end

  def down
    schema.alter :posts do
      drop_index :idx_posts_featured
      drop_column :featured_at
      drop_column :featured
    end
  end
end
```

### Step 3: Deploy Strategy

1. Deploy migration (adds column with default)
2. Deploy new code that uses the column
3. Backfill data if needed

## Workflow 3: Data Migrations

Sometimes you need to transform existing data.

### Step 1: Create Migration with Data Transformation

```crystal
# migrations/008_normalize_user_emails.cr
class NormalizeUserEmails < CQL::Migration(8)
  def up
    # Add temporary column
    schema.alter :users do
      add_column :email_normalized, String, null: true
    end

    # Migrate data (done in batches for large tables)
    schema.exec("UPDATE users SET email_normalized = LOWER(TRIM(email))")

    # Verify
    count = schema.exec("SELECT COUNT(*) FROM users WHERE email_normalized IS NULL").first
    raise "Data migration incomplete" if count > 0

    # Swap columns
    schema.alter :users do
      drop_column :email
    end

    schema.exec("ALTER TABLE users RENAME COLUMN email_normalized TO email")

    # Recreate index
    schema.alter :users do
      create_index :idx_users_email, [:email], unique: true
    end
  end

  def down
    # This migration cannot be easily reversed
    raise "Cannot rollback email normalization"
  end
end
```

### Step 2: For Large Tables, Use Batching

```crystal
def up
  batch_size = 1000
  offset = 0

  loop do
    result = schema.exec(<<-SQL
      UPDATE users
      SET email_normalized = LOWER(TRIM(email))
      WHERE id IN (
        SELECT id FROM users
        WHERE email_normalized IS NULL
        LIMIT #{batch_size}
      )
    SQL
    )

    break if result.rows_affected == 0
    offset += batch_size

    # Optional: Add a small delay to reduce database load
    sleep 0.1
  end
end
```

## Workflow 4: Rolling Back

### Safe Rollback

```shell
# Rollback last migration
crystal src/migrate.cr down

# Rollback to specific version
crystal src/migrate.cr down_to 5
```

### When Rollback Isn't Possible

Some migrations can't be rolled back:
- Data loss migrations (dropping columns with data)
- Data transformations
- Renaming with data loss

Mark these clearly:

```crystal
def down
  raise "Cannot rollback: #{self.class.name} - data would be lost"
end
```

## Workflow 5: Production Deployment

### Pre-Deployment Checklist

1. **Test migration locally**
2. **Test migration on staging**
3. **Backup production database**
4. **Plan rollback strategy**
5. **Schedule maintenance window if needed**

### Deployment Script

```crystal
# scripts/deploy_migrations.cr
require "../src/cql_config"
require "../migrations/*"

puts "Starting migration deployment..."
puts "================================"

AppDB.init

migrator = AppDB.migrator(CQL_MIGRATOR_CONFIG)

pending = migrator.pending_migrations.size
if pending == 0
  puts "No pending migrations"
  exit 0
end

puts "Pending migrations: #{pending}"
puts ""

# Run with transaction per migration
migrator.pending_migrations.each do |version|
  puts "Running migration #{version}..."

  begin
    migrator.up_to(version)
    puts "  Success!"
  rescue ex
    puts "  FAILED: #{ex.message}"
    puts ""
    puts "Migration failed. Database may be in inconsistent state."
    puts "Please investigate and fix manually."
    exit 1
  end
end

puts ""
puts "All migrations completed successfully!"
```

## Best Practices Summary

1. **Always write reversible migrations** when possible
2. **Test migrations on a copy of production data**
3. **Make additive changes first** (add columns before code uses them)
4. **Use transactions** for related changes
5. **Batch large data migrations**
6. **Document irreversible migrations**
7. **Have a rollback plan** before deploying

## Next Steps

- [Create a Migration](../../how-to/migrations/create-migration.md)
- [Rollback Migrations](../../how-to/migrations/rollback.md)
- [Migration DSL Reference](../../reference/api/migration-dsl.md)
