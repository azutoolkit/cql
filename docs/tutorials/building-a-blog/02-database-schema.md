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

      unique_constraint [:email]
      unique_constraint [:username]
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
- `unique_constraint` on `email` and `username` prevents duplicates (a table-level `UNIQUE (...)` clause)

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

      unique_constraint [:slug]
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
    end

    schema.posts.create!

    schema.alter :posts do
      create_index :idx_posts_user_id, [:user_id]
      create_index :idx_posts_category_id, [:category_id]
      create_index :idx_posts_published, [:published]
    end
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
- Indexes on foreign keys improve query performance. Here they are added with `create_index` inside `schema.alter`; an `index [...]` line inside the `table` block works too, and `create!` creates it right after the table
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
    end

    schema.comments.create!

    schema.alter :comments do
      create_index :idx_comments_post_id, [:post_id]
      create_index :idx_comments_user_id, [:user_id]
    end
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

The setup script from Part 1 already loads the migrations (`src/blog_engine.cr` requires `../migrations/*`), so it runs them as is:

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
(a table listing the four applied migrations)
Migrations complete

Setup complete!
```

## Step 6: Look at the Generated Schema

Because `auto_sync` is on, the migrator wrote the real tables of your database to `src/schemas/blog_schema.cr`:

```crystal
BlogSchema = CQL::Schema.define(
  :blog_schema,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://./db/blog_development.db") do
  table :users do
    primary :id, Int32
    text :username
    text :email
    # ...
    timestamps
  end

  table :posts do
    # ... with its foreign keys
  end
  # categories, comments, and the cql_schema_migrations bookkeeping table
end
```

This is the schema your models will use in Part 3: unlike `BlogDB`, whose block is empty, it knows every table, so a program that never runs the migrations can still query them. The file is rewritten after every `migrator.up` and `down`, so keep it in version control and recompile after adding a migration. (SQLite integer keys are dumped as `Int32`; the models still declare `Model(Int64)`.)

The generated file embeds the connection URL it was created from. If that URL holds credentials (a production PostgreSQL password, for example), set `auto_sync: false` there and keep a hand-written schema instead.

## Step 7: Verify the Migrations

Create a verification script to inspect the created tables:

```crystal
# src/verify_schema.cr
require "./database"
require "../migrations/*"

migrator = BlogDB.migrator(MIGRATOR_CONFIG)

puts "Migration Status"
puts "================"
puts "Applied: #{migrator.applied_migrations.size}"
puts "Pending: #{migrator.pending_migrations.size}"
puts ""
puts "Applied migrations:"
migrator.applied_migrations.each do |m|
  puts "  - #{m.version} #{m.name}"
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

| Crystal type (helper) | SQLite | PostgreSQL | MySQL |
|----------|--------|------------|-------|
| `Int32` (`integer`) | INTEGER | INTEGER | INT |
| `Int64` (`bigint`) | BIGINT | BIGINT | BIGINT |
| `String` (`text`, `varchar`) | TEXT | VARCHAR | VARCHAR(255) |
| `Bool` (`boolean`) | BOOLEAN | BOOLEAN | TINYINT(1) |
| `Float64` (`double`) | DOUBLE | DOUBLE PRECISION | DOUBLE |
| `Time` (`timestamp`) | DATE | DATE | DATE |
| `timestamps` | `created_at` and `updated_at` as `Time` columns defaulting to the current time | | |

(`Time` columns are currently declared with the type name `DATE` on every adapter; check the generated DDL with `schema.users.create_sql` if you depend on sub-day precision on PostgreSQL or MySQL.)

An auto-increment `primary` key becomes `INTEGER PRIMARY KEY AUTOINCREMENT` on SQLite, `... GENERATED ALWAYS AS IDENTITY PRIMARY KEY` on PostgreSQL and `AUTO_INCREMENT` on MySQL. CockroachDB follows PostgreSQL, except that `Int32` columns are declared `INT4`.

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
