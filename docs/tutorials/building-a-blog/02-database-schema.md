# Part 2: Database Schema

In this part, you'll design and create the database schema for your blog engine using CQL migrations. You'll create tables for users, categories, posts, and comments with proper relationships and indexes.

## What You'll Learn

- Designing a relational database schema
- Creating migrations for multiple tables
- Defining primary keys, foreign keys, and indexes
- Using timestamps and default values
- Running and verifying migrations

## Prerequisites

- Completed [Part 1: Project Setup](01-project-setup.md)

## Database Design

Here's the schema we'll create:

```
USERS                    CATEGORIES
├── id (PK)              ├── id (PK)
├── username (unique)    ├── name
├── email (unique)       ├── slug (unique)
├── first_name           ├── created_at
├── last_name            └── updated_at
├── active
├── created_at
└── updated_at

POSTS                    COMMENTS
├── id (PK)              ├── id (PK)
├── title                ├── content
├── content              ├── post_id (FK)
├── published            ├── user_id (FK, nullable)
├── views_count          ├── created_at
├── user_id (FK)         └── updated_at
├── category_id (FK)
├── created_at
└── updated_at
```

## Step 1: Create Users Migration

Create the first migration for the users table:

```crystal
# migrations/001_create_users.cr
class CreateUsers < CQL::Migration(1)
  def up
    schema.table :users do
      primary :id, Int64, auto_increment: true
      column :username, String, null: false
      column :email, String, null: false
      column :first_name, String, null: true
      column :last_name, String, null: true
      column :active, Bool, default: true
      timestamps

      index [:email], unique: true
      index [:username], unique: true
    end

    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end
```

Key points:
- `primary :id` creates an auto-incrementing primary key
- `null: false` makes columns required
- `default: true` sets a default value
- `timestamps` creates `created_at` and `updated_at` columns
- Unique indexes on `email` and `username` prevent duplicates

## Step 2: Create Categories Migration

```crystal
# migrations/002_create_categories.cr
class CreateCategories < CQL::Migration(2)
  def up
    schema.table :categories do
      primary :id, Int64, auto_increment: true
      column :name, String, null: false
      column :slug, String, null: false
      timestamps

      index [:slug], unique: true
    end

    schema.categories.create!
  end

  def down
    schema.categories.drop!
  end
end
```

The `slug` column stores URL-friendly versions of category names (e.g., "Web Development" becomes "web-development").

## Step 3: Create Posts Migration

```crystal
# migrations/003_create_posts.cr
class CreatePosts < CQL::Migration(3)
  def up
    schema.table :posts do
      primary :id, Int64, auto_increment: true
      column :title, String, null: false
      column :content, String, null: false
      column :published, Bool, default: false
      column :views_count, Int64, default: 0_i64
      column :user_id, Int64, null: false
      column :category_id, Int64, null: true
      timestamps

      foreign_key [:user_id], references: :users, references_columns: [:id], on_delete: :cascade
      foreign_key [:category_id], references: :categories, references_columns: [:id], on_delete: :set_null
      index [:user_id]
      index [:category_id]
      index [:published]
    end

    schema.posts.create!
  end

  def down
    schema.posts.drop!
  end
end
```

Key points:
- Foreign keys establish relationships with users and categories
- `on_delete: :cascade` deletes posts when the author is deleted
- `on_delete: :set_null` keeps posts when a category is deleted (just nullifies the reference)
- Indexes on foreign keys improve query performance
- Index on `published` helps filter posts efficiently

## Step 4: Create Comments Migration

```crystal
# migrations/004_create_comments.cr
class CreateComments < CQL::Migration(4)
  def up
    schema.table :comments do
      primary :id, Int64, auto_increment: true
      column :content, String, null: false
      column :post_id, Int64, null: false
      column :user_id, Int64, null: true  # Allow anonymous comments
      timestamps

      foreign_key [:post_id], references: :posts, references_columns: [:id], on_delete: :cascade
      foreign_key [:user_id], references: :users, references_columns: [:id], on_delete: :set_null
      index [:post_id]
      index [:user_id]
    end

    schema.comments.create!
  end

  def down
    schema.comments.drop!
  end
end
```

Key points:
- `user_id` is nullable to allow anonymous comments
- Cascading delete removes comments when their post is deleted
- Setting user to NULL when a user is deleted preserves the comment

## Step 5: Run the Migrations

Update your setup script to require migrations:

```crystal
# src/setup.cr
require "./blog_engine"

puts "Setting up Blog Engine..."
puts "========================="

BlogEngine.setup
BlogEngine.migrate

puts ""
puts "Setup complete!"
```

Run the migrations:

```shell
crystal src/setup.cr
```

Expected output:

```
Setting up Blog Engine...
=========================
Database connected
Running 4 pending migration(s)...
Migrations complete

Setup complete!
```

## Step 6: Verify the Schema

Create a verification script to inspect the created tables:

```crystal
# src/verify_schema.cr
require "./database"
require "../migrations/*"

BlogDB.init

migrator = BlogDB.migrator(MIGRATOR_CONFIG)

puts "Migration Status"
puts "================"
puts "Applied: #{migrator.applied_migrations.size}"
puts "Pending: #{migrator.pending_migrations.size}"
puts ""
puts "Applied migrations:"
migrator.applied_migrations.each do |m|
  puts "  - Migration #{m}"
end
```

Run it:

```shell
crystal src/verify_schema.cr
```

## Understanding the Schema

Let's visualize the relationships:

```
Users ─────────┬─── has many ───> Posts
               │
               └─── has many ───> Comments

Categories ────────── has many ───> Posts

Posts ─────────┬─── belongs to ──> User
               ├─── belongs to ──> Category (optional)
               └─── has many ────> Comments

Comments ──────┬─── belongs to ──> Post
               └─── belongs to ──> User (optional)
```

## Migration Best Practices

1. **Number migrations sequentially**: Use `001_`, `002_`, etc. to ensure order
2. **Write reversible migrations**: Always implement both `up` and `down`
3. **One concern per migration**: Don't create multiple unrelated tables in one migration
4. **Index foreign keys**: Always index columns used in foreign key relationships
5. **Plan for deletion**: Choose appropriate `on_delete` behavior
6. **Use nullable carefully**: Only make columns nullable when truly optional

## Common Column Types

| CQL Type | SQLite | PostgreSQL | MySQL |
|----------|--------|------------|-------|
| `primary` | INTEGER | BIGSERIAL | BIGINT |
| `bigint` | INTEGER | BIGINT | BIGINT |
| `integer` | INTEGER | INTEGER | INT |
| `text` | TEXT | TEXT | TEXT |
| `boolean` | INTEGER | BOOLEAN | TINYINT |
| `timestamps` | TEXT (x2) | TIMESTAMP (x2) | DATETIME (x2) |

## Summary

In this part, you:

1. Designed a relational database schema for a blog
2. Created four migrations: users, categories, posts, comments
3. Defined primary keys, foreign keys, and indexes
4. Ran migrations to create the database tables
5. Verified the schema was created correctly

## Next Steps

In [Part 3: Models and Relationships](03-models-and-relationships.md), you'll create Active Record models that map to these tables and define the relationships between them.

---

**Tutorial Navigation:**
- [Part 1: Project Setup](01-project-setup.md)
- Part 2: Database Schema (current)
- [Part 3: Models and Relationships](03-models-and-relationships.md)
- [Part 4: CRUD Operations](04-crud-operations.md)
- [Part 5: Adding Features](05-adding-features.md)
