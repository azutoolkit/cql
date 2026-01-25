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
    version: ~> 0.0.435

  # Keep your existing database driver or add one
  pg:
    github: will/crystal-pg
    version: "~> 0.26.0"
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
require "pg"

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
    text :email, null: false
    text :name
    text :password_digest
    timestamps
  end

  table :products do
    primary :id, Int64, auto_increment: true
    text :name, null: false
    text :description
    decimal :price, precision: 10, scale: 2
    integer :stock, default: 0
    timestamps
  end
end
```

## Step 4: Create Models for Existing Tables

Create CQL models that map to your existing tables:

```crystal
# src/models/user.cr
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :users

  property id : Int64?
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
struct Product
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :products

  property id : Int64?
  property name : String
  property description : String?
  property price : BigDecimal?
  property stock : Int32 = 0
  property created_at : Time?
  property updated_at : Time?

  def initialize(@name : String, @price : BigDecimal? = nil)
  end
end
```

## Step 5: Initialize CQL

Add CQL initialization to your application startup:

```crystal
# src/app.cr (or your main file)
require "./cql_config"
require "./models/*"

# Initialize CQL connection
AppDB.init

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
      index [:user_id]
      index [:status]
    end

    schema.orders.create!
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

AppDB.init

migrator = AppDB.migrator(CQL_MIGRATOR_CONFIG)

case ARGV[0]?
when "up"
  migrator.up
  puts "Migrations applied"
when "down"
  migrator.down
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

## Step 8: Gradual Migration Strategy

Adopt CQL incrementally:

### Phase 1: Read Operations

Start by using CQL for read operations:

```crystal
# Before (raw SQL)
result = db.query("SELECT * FROM users WHERE email = $1", email)

# After (CQL)
user = User.find_by(email: email)
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
results = db.query(<<-SQL
  SELECT u.*, COUNT(o.id) as order_count
  FROM users u
  LEFT JOIN orders o ON o.user_id = u.id
  GROUP BY u.id
  ORDER BY order_count DESC
  LIMIT 10
SQL
)

# After
top_users = User.all.sort_by { |u| -u.orders.count }.first(10)
```

### Phase 4: Relationships

Add relationship navigation:

```crystal
# Update User model
struct User
  # ...existing code...
  has_many :orders, Order, :user_id
end

# Now you can do
user = User.find(1)
user_orders = user.orders.all
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

### Option B: Import Existing Schema

Mark existing migrations as applied:

```crystal
# In your migrate script
migrator = AppDB.migrator(CQL_MIGRATOR_CONFIG)

# Mark baseline as applied without running
migrator.mark_as_applied(0) unless migrator.applied?(0)
```

## Best Practices

1. **Don't modify existing tables** with CQL initially - just read from them
2. **Test thoroughly** before switching write operations
3. **Keep existing code working** during transition
4. **Migrate one model at a time** to limit risk
5. **Use transactions** when doing bulk data updates

## Common Issues

### Column Name Mismatches

If your existing column names differ from CQL conventions:

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :users

  # Map property to different column name
  @[CQL::Column(name: "user_email")]
  property email : String
end
```

### Different Timestamp Format

If your timestamps use a different format:

```crystal
# Handle existing timestamp format
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
