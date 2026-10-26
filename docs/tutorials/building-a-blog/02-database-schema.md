# Part 2: Database Schema

Write the four migrations for users, categories, posts and comments, run them, and look at the schema file the migrator generates.

**You need:** the project from [Part 1](01-project-setup.md).

## The tables

```text
users                    categories
├── id (PK)              ├── id (PK)
├── username (unique)    ├── name
├── email (unique)       ├── slug (unique)
├── first_name           ├── created_at
├── last_name            └── updated_at
├── active
├── created_at
└── updated_at

posts                    comments
├── id (PK)              ├── id (PK)
├── title                ├── content
├── content              ├── post_id (FK)
├── published            ├── user_id (FK, nullable)
├── views_count          ├── created_at
├── user_id (FK)         └── updated_at
├── category_id (FK, nullable)
├── created_at
└── updated_at
```

## Step 1: Create the users migration

```crystal
# migrations/001_create_users.cr
class CreateUsers < CQL::Migration(1)
  def up
    schema.table :users do
      primary :id, Int64, auto_increment: true
      column :username, String # NOT NULL unless null: true
      column :email, String
      column :first_name, String, null: true
      column :last_name, String, null: true
      column :active, Bool, default: true
      timestamps # created_at and updated_at, defaulting to the current time

      unique_constraint [:email] # a table-level UNIQUE (email)
      unique_constraint [:username]
    end

    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end
```

## Step 2: Create the categories migration

```crystal
# migrations/002_create_categories.cr
class CreateCategories < CQL::Migration(2)
  def up
    schema.table :categories do
      primary :id, Int64, auto_increment: true
      column :name, String
      column :slug, String # URL-friendly name: "Web Development" -> "web-development"
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

## Step 3: Create the posts migration

```crystal
# migrations/003_create_posts.cr
class CreatePosts < CQL::Migration(3)
  def up
    schema.table :posts do
      primary :id, Int64, auto_increment: true
      column :title, String
      column :content, String
      column :published, Bool, default: false
      column :views_count, Int64, default: 0_i64
      column :user_id, Int64
      column :category_id, Int64, null: true
      timestamps

      # Deleting a user deletes their posts; deleting a category keeps its posts with no category
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

An `index [:user_id]` line inside the `table` block works too; `create!` then creates the index right after the table.

## Step 4: Create the comments migration

```crystal
# migrations/004_create_comments.cr
class CreateComments < CQL::Migration(4)
  def up
    schema.table :comments do
      primary :id, Int64, auto_increment: true
      column :content, String
      column :post_id, Int64
      column :user_id, Int64, null: true # anonymous comments have no user
      timestamps

      # Deleting a post deletes its comments; deleting a user keeps their comments as anonymous
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

## Step 5: Run the migrations

`src/blog_engine.cr` from Part 1 already requires `../migrations/*`, so the setup script runs them:

```bash
crystal src/setup.cr
```

```text
Setting up Blog Engine...
Database connected
Running 4 pending migration(s)...

┌────────┬──────────────────────┬─────────┐
│ Status │ Migration            │ Version │
├────────┼──────────────────────┼─────────┤
│   ✔    │ CreateUsers │       1 │
│   ✔    │ CreateCategories │       2 │
│   ✔    │ CreatePosts │       3 │
│   ✔    │ CreateComments │       4 │
└────────┴──────────────────────┴─────────┘

Migrations complete
Setup complete!
```

CQL's development logger adds timestamped `INFO` and `DEBUG` lines. Run the script again and it prints `Database is up to date`. Migrations run in version order, and each runs once.

## Step 6: Look at the generated schema

With `auto_sync`, the migrator wrote the database's real tables to `src/schemas/app_schema.cr`:

```crystal
AppSchema = CQL::Schema.define(
  :app_schema,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://./db/blog_development.db?foreign_keys=1") do
  table :cql_schema_migrations do
    # the migrator's own bookkeeping
  end

  table :users do
    primary :id, Int32
    text :username
    text :email
    text :first_name, null: true
    text :last_name, null: true
    boolean :active, default: "1"
    timestamps
  end

  # categories, posts and comments, with their foreign keys
end
```

Your models use `AppSchema` from Part 3: it knows every table, so a program that never runs the migrations can still query them. Keep the file in version control and recompile after each migration.

- SQLite integer keys come back as `Int32`; the models still declare `Model(Int64)`.
- The dump holds columns and foreign keys only; unique constraints and indexes stay in the migrations.
- The file embeds the connection URL. If the URL holds a password, set `auto_sync: false` there and keep a hand-written schema (Part 5).

## Column types

| Crystal type (helper) | SQLite | PostgreSQL | MySQL |
| :--- | :--- | :--- | :--- |
| `Int32` (`integer`) | `INTEGER` | `INTEGER` | `INT` |
| `Int64` (`bigint`) | `BIGINT` | `BIGINT` | `BIGINT` |
| `String` (`text`, `varchar`) | `TEXT` | `VARCHAR` | `VARCHAR(255)` |
| `Bool` (`boolean`) | `BOOLEAN` | `BOOLEAN` | `TINYINT(1)` |
| `Float64` (`double`) | `DOUBLE` | `DOUBLE PRECISION` | `DOUBLE` |
| `Time` (`timestamp`) | `TIMESTAMP` | `TIMESTAMP` | `DATETIME(3)` |
| `Time` (`date`) | `DATE` | `DATE` | `DATE` |

An auto-increment `primary` key becomes `INTEGER PRIMARY KEY AUTOINCREMENT` on SQLite, `BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY` on PostgreSQL and `BIGINT PRIMARY KEY AUTO_INCREMENT` on MySQL. CockroachDB follows PostgreSQL, except that `Int32` columns are `INT4`.

When you write your own migrations: number them in order, implement `down`, keep one concern per migration, index foreign keys, and choose each `on_delete` on purpose.

Next: [Part 3: Models and Relationships](03-models-and-relationships.md) maps these tables to classes.
