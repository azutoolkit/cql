# Adding CQL to an Existing Project

This tutorial walks you through integrating CQL into an existing Crystal application. You'll learn how to add CQL alongside your current code, migrate existing data, and gradually adopt CQL patterns.

## What You'll Learn

- Adding CQL as a dependency
- Configuring CQL alongside existing database code
- Creating migrations for existing tables
- Defining models for existing data
- Gradually migrating to CQL patterns

## Prerequisites

- An existing Crystal project
- Basic familiarity with CQL concepts
- Access to your existing database

## Step 1: Add Dependencies

Add CQL to your existing `shard.yml`:

```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: ~> 0.0.589

  # Keep your existing database driver or add one.
  # PostgreSQL needs no extra shard: CQL ships its own native driver.
  pg:
    github: will/crystal-pg
    version: "~> 0.29.0"
```

Install:

```shell
shards install
```

## Step 2: Create Database Configuration

Create a separate file for CQL configuration:

```crystal
# src/cql_config.cr
require "cql"
require "pg" # only if your app already uses the pg shard; CQL's native PostgreSQL driver serves postgres:// URLs otherwise

# Use your existing database URL
DATABASE_URL = ENV["DATABASE_URL"]? || "postgres://localhost/myapp_development"

AppDB = CQL::Schema.define(
  :app_db,
  adapter: CQL::Adapter::Postgres,
  uri: DATABASE_URL
) do
  # We'll define existing tables here
end

# Migration configuration
CQL_MIGRATOR_CONFIG = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  auto_sync: true
)
```

## Step 3: Define Existing Tables in Schema

If you have existing tables, define them in the schema so CQL knows about them:

```crystal
AppDB = CQL::Schema.define(
  :app_db,
  adapter: CQL::Adapter::Postgres,
  uri: DATABASE_URL
) do
  # Define existing tables (read-only, won't create them)
  table :users do
    primary :id, Int64, auto_increment: true
    text :email
    text :name, null: true
    text :password_digest, null: true
    timestamps
  end

  table :products do
    primary :id, Int64, auto_increment: true
    text :name
    text :description, null: true
    double :price, null: true
    integer :stock, default: 0
    timestamps
  end
end
```

Columns are `NOT NULL` unless you pass `null: true`. The schema only describes the tables for CQL; nothing is created until you call `create!` on a table.

## Step 4: Create Models for Existing Tables

Create CQL models that map to your existing tables:

```crystal
# src/models/user.cr
class User
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :users

  property email : String
  property name : String?
  property password_digest : String?
  property created_at : Time?
  property updated_at : Time?

  def initialize(@email : String, @name : String? = nil)
  end
end
```

```crystal
# src/models/product.cr
class Product
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :products

  property name : String
  property description : String?
  property price : Float64?
  property stock : Int32 = 0
  property created_at : Time?
  property updated_at : Time?

  def initialize(@name : String, @price : Float64? = nil)
  end
end
```

The primary key (`id`) comes from `Model(Int64)`, so models do not declare it. Use `class`, not `struct`, so `save` can assign the new id to your instance.

## Step 5: Load CQL at Startup

`CQL::Schema.define` opens the connection pool when it runs, so loading the config and models is all the initialization CQL needs:

```crystal
# src/app.cr (or your main file)
require "./cql_config"
require "./models/*"

# Your existing application code continues...
```

## Step 6: Create New Migrations

For new features, create CQL migrations:

```shell
mkdir -p migrations
```

```crystal
# migrations/001_create_orders.cr
class CreateOrders < CQL::Migration(1)
  def up
    schema.table :orders do
      primary :id, Int64, auto_increment: true
      column :user_id, Int64, null: false
      column :total, Float64
      column :status, String, default: "pending"
      timestamps

      foreign_key [:user_id], references: :users, references_columns: [:id]
    end

    schema.orders.create!

    schema.alter :orders do
      create_index :idx_orders_user_id, [:user_id]
      create_index :idx_orders_status, [:status]
    end
  end

  def down
    schema.orders.drop!
  end
end
```

## Step 7: Run New Migrations

Create a migration runner:

```crystal
# src/migrate.cr
require "./cql_config"
require "../migrations/*"

migrator = AppDB.migrator(CQL_MIGRATOR_CONFIG)

case ARGV[0]?
when "up"
  migrator.up
  puts "Migrations applied"
when "down"
  migrator.rollback # one step; `migrator.down` with no argument rolls back everything
  puts "Last migration rolled back"
when "status"
  puts "Applied: #{migrator.applied_migrations.size}"
  puts "Pending: #{migrator.pending_migrations.size}"
else
  puts "Usage: crystal src/migrate.cr [up|down|status]"
end
```

Run migrations:

```shell
crystal src/migrate.cr up
```

A migration declares its table only while it runs. For models and queries in your application (a separate process) to know about `orders`, add the same `table :orders do ... end` block to the `AppDB` schema in `src/cql_config.cr`, next to `users` and `products`. (Alternatively, point your models at the schema file that `auto_sync` writes to `src/schemas/app_schema.cr`, as the other tutorials do.)

## Step 8: Gradual Migration Strategy

Adopt CQL incrementally:

### Phase 1: Read Operations

Start by using CQL for read operations:

```crystal
# Before (raw SQL)
result = db.query("SELECT * FROM users WHERE email = $1", email)

# After (CQL)
user = User.find_by(email: email) # => User?
```

### Phase 2: Simple Writes

Move simple create/update operations:

```crystal
# Before
db.exec("INSERT INTO users (email, name) VALUES ($1, $2)", email, name)

# After
user = User.create!(email: email, name: name)
```

### Phase 3: Complex Queries

Migrate complex queries:

```crystal
# Before
db.query_all(<<-SQL, as: {Int64, Int64})
  SELECT user_id, COUNT(id) AS order_count
  FROM orders
  GROUP BY user_id
  LIMIT 10
SQL

# After: the same aggregation with the query builder
order_counts = AppDB.query
  .from(:orders)
  .select(:user_id, count: :id)
  .group(:user_id)
  .limit(10)
  .all(as: {Int64, Int64})
```

For anything the builder cannot express yet, keep your raw SQL; both can run side by side.

### Phase 4: Relationships

Add relationship navigation:

```crystal
# Define the Order model (class Order with `include CQL::ActiveRecord::Model(Int64)`,
# `db_context AppDB, :orders`, a `property user_id : Int64` and `belongs_to :user, User, :user_id`),
# then update the User model
class User
  # ...existing code...
  has_many :orders, Order, :user_id
end

# Now you can do
user = User.find(1)
user_orders = user.orders.all if user
```

## Handling Existing Migrations

If you have existing migrations (e.g., from another ORM), you have options:

### Option A: Start Fresh

Create a baseline migration that represents your current schema:

```crystal
# migrations/000_baseline.cr
class Baseline < CQL::Migration(0)
  def up
    # This migration assumes tables already exist
    # It just establishes the baseline for CQL
  end

  def down
    # Cannot rollback baseline
    raise "Cannot rollback baseline migration"
  end
end
```

### Option B: Start Numbering After Your Old Migrations

CQL keeps its own bookkeeping in the `cql_schema_migrations` table (created automatically by the migrator), so migrations from another ORM do not conflict with it. Give new CQL migrations versions that sort after the old ones (for example a timestamp such as `CQL::Migration(20260101120000)`) and leave the old migrations where they are.

## Best Practices

1. **Don't modify existing tables** with CQL initially - just read from them
2. **Test thoroughly** before switching write operations
3. **Keep existing code working** during transition
4. **Migrate one model at a time** to limit risk
5. **Use transactions** when doing bulk data updates

## Common Issues

### Column Name Mismatches

Model properties map to columns of the same name, so a model property called `email` reads the `email` column. If an existing column is named differently (say `user_email`), rename it with a migration (renaming also affects your old code, so do it when you are ready to switch over):

```crystal
class RenameUserEmail < CQL::Migration(20260101130000)
  def up
    schema.alter :users do
      rename_column :user_email, :email
    end
  end

  def down
    schema.alter :users do
      rename_column :email, :user_email
    end
  end
end
```

### Different Timestamp Format

If you want a different format when displaying timestamps, format them in the model:

```crystal
property created_at : Time?

def created_at_formatted
  created_at.try(&.to_s("%Y-%m-%d %H:%M:%S"))
end
```

## Summary

You've learned how to:

1. Add CQL to an existing Crystal project
2. Define schemas for existing tables
3. Create models for existing data
4. Create new migrations for new features
5. Gradually migrate from raw SQL to CQL patterns

## Next Steps

- [Your First CQL App](your-first-cql-app.md) - Learn CQL fundamentals
- [Define a Model](../../how-to/models/define-model.md) - Advanced model features
- [Run Migrations](../../how-to/migrations/run-migrations.md) - Migration management
