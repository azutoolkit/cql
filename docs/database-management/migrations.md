# Migrations

CQL provides a comprehensive migration system for managing database schema changes over time with **automatic schema file synchronization**. This integrated workflow ensures your schema files always match your database state, providing compile-time type safety for Active Record models.

***

## What are Migrations?

Migrations are Crystal classes that define changes to your database schema. Each migration has:

* **Version Number**: Unique identifier for ordering migrations
* **Up Method**: Defines changes to apply
* **Down Method**: Defines how to revert the changes

**Benefits of Migrations:**

* **Version Control**: Schema changes are tracked with your code
* **Team Collaboration**: Consistent schema across development environments
* **Deployment Safety**: Reliable schema updates in production
* **Rollback Capability**: Ability to undo problematic changes
* **🆕 Automatic Schema Sync**: Schema files automatically updated after migrations
* **🆕 Type Safety**: Compile-time guarantees for Active Record models

***

## 🆕 Integrated Migration Workflow

CQL now provides an integrated migration system that automatically maintains schema files in sync with your database changes:

### Quick Setup

```crystal
# 1. Configure automatic schema synchronization
config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  schema_symbol: :app_schema,
  auto_sync: true  # Automatically update schema file after migrations
)

# 2. Initialize migrator with config
migrator = AppDB.migrator(config)

# 3. Run migrations - schema file automatically updated!
migrator.up
```

### Benefits for Active Record

```crystal
# After migrations run, your schema file is automatically updated
require "./src/schemas/app_schema"

class User
  include CQL::ActiveRecord::Model(Int32)
  db_context AppSchema, :users  # Uses auto-generated schema

  # Compile-time type safety guaranteed!
  property name : String
  property email : String
end
```

**For a complete guide on this workflow, see** [**Integrated Migration Workflow with Active Record**](../active-record-with-cql/integrated-migration-workflow.md)**.**

***

## Migration Structure

### Basic Migration Class

All migrations inherit from `CQL::Migration` with a version number:

```crystal
class CreateUsersTable < CQL::Migration(20240101120000)
  def up
    # Define schema changes to apply
  end

  def down
    # Define how to rollback the changes
  end
end
```

### Version Numbers

Use timestamp-based version numbers for proper ordering:

```crystal
# Format: YYYYMMDDHHMMSS
class CreateUsersTable < CQL::Migration(20240315103000)  # March 15, 2024 10:30:00
class AddEmailToUsers < CQL::Migration(20240315104500)   # March 15, 2024 10:45:00
class CreatePostsTable < CQL::Migration(20240316090000)  # March 16, 2024 09:00:00
```

***

## Creating Tables

### Table Creation Migration

```crystal
class CreateUsersTable < CQL::Migration(20240101120000)
  def up
    # Create table using existing schema definition
    schema.users.create!
  end

  def down
    # Drop the table
    schema.users.drop!
  end
end
```

**Note**: This approach assumes you've already defined the table structure in your schema. The migration just creates/drops the physical table.

### Complete Table Definition Example

If you need to define table structure within the migration:

```crystal
class CreateProductsTable < CQL::Migration(20240102120000)
  def up
    # Define and create table structure
    schema.table :products do
      primary :id, Int32
      column :name, String
      column :price, Float64
      column :category, String
      column :active, Bool, default: true
      timestamps
    end
    schema.products.create!
  end

  def down
    schema.products.drop!
  end
end
```

***

## Altering Tables

### Adding Columns

```crystal
class AddPhoneToUsers < CQL::Migration(20240103120000)
  def up
    schema.alter :users do
      add_column :phone, String, null: true
    end
  end

  def down
    schema.alter :users do
      drop_column :phone
    end
  end
end
```

### Removing Columns

```crystal
class RemoveMiddleNameFromUsers < CQL::Migration(20240104120000)
  def up
    schema.alter :users do
      drop_column :middle_name
    end
  end

  def down
    schema.alter :users do
      add_column :middle_name, String, null: true
    end
  end
end
```

### Renaming Columns

```crystal
class RenameUserEmailColumn < CQL::Migration(20240105120000)
  def up
    schema.alter :users do
      rename_column :email, :email_address
    end
  end

  def down
    schema.alter :users do
      rename_column :email_address, :email
    end
  end
end
```

### Changing Column Types

```crystal
class ChangeUserAgeToString < CQL::Migration(20240106120000)
  def up
    schema.alter :users do
      change_column :age, String
    end
  end

  def down
    schema.alter :users do
      change_column :age, Int32
    end
  end
end
```

***

## Working with Indexes

### Adding Indexes

```crystal
class AddIndexesToUsers < CQL::Migration(20240107120000)
  def up
    schema.alter :users do
      create_index :idx_users_email, [:email], unique: true
      create_index :idx_users_name_phone, [:name, :phone]
    end
  end

  def down
    schema.alter :users do
      drop_index :idx_users_email
      drop_index :idx_users_name_phone
    end
  end
end
```

### Removing Indexes

```crystal
class RemoveOldIndexes < CQL::Migration(20240108120000)
  def up
    schema.alter :users do
      drop_index :old_index_name
    end
  end

  def down
    schema.alter :users do
      create_index :old_index_name, [:column_name]
    end
  end
end
```

***

## Foreign Keys

### Adding Foreign Keys

```crystal
class AddUserForeignKeyToPosts < CQL::Migration(20240109120000)
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

### Complex Foreign Key Example

```crystal
class AddCompositeKeys < CQL::Migration(20240110120000)
  def up
    schema.alter :order_items do
      foreign_key [:order_id, :product_id],
                  references: :orders_products,
                  references_columns: [:order_id, :product_id],
                  name: :fk_order_items_composite,
                  on_update: :cascade,
                  on_delete: :restrict
    end
  end

  def down
    schema.alter :order_items do
      drop_foreign_key :fk_order_items_composite
    end
  end
end
```

***

## Table Operations

### Renaming Tables

```crystal
class RenameUsersToAccounts < CQL::Migration(20240111120000)
  def up
    schema.alter :users do
      rename_table :accounts
    end
  end

  def down
    schema.alter :accounts do
      rename_table :users
    end
  end
end
```

***

## Running Migrations

### Setting Up the Migrator

```crystal
# 🆕 New: Configure with automatic schema synchronization
config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  schema_symbol: :app_schema,
  auto_sync: true
)

migrator = MyAppDB.migrator(config)

# Traditional: Basic migrator (no auto-sync)
# migrator = CQL::Migrator.new(MyAppDB)

# Check migration status
migrator.print_pending_migrations
migrator.print_applied_migrations
```

### 🆕 Environment-Specific Configurations

```crystal
# Development: Auto-sync enabled for rapid iteration
dev_config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  auto_sync: true
)

# Production: Manual control for safety
prod_config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/production_schema.cr",
  schema_name: :ProductionSchema,
  auto_sync: false
)

# Test: Separate schema file
test_config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/test_schema.cr",
  schema_name: :TestSchema,
  auto_sync: true
)
```

### Basic Migration Commands

```crystal
# Apply all pending migrations
migrator.up

# Rollback the last migration
migrator.down(1)

# Rollback all migrations
migrator.down

# Redo the last migration (rollback then apply)
migrator.redo

# Apply migrations up to a specific version
migrator.up_to(20240105120000)

# Rollback to a specific version
migrator.down_to(20240103120000)
```

### Migration Status

```crystal
# Get applied migrations
applied = migrator.applied_migrations
puts "Applied: #{applied.map(&.version)}"

# Get pending migrations
pending = migrator.pending_migrations
puts "Pending: #{pending.map(&.version)}"

# Get last applied migration
last = migrator.last
puts "Last: #{last.try(&.version) || "None"}"
```

### 🆕 Schema Synchronization Methods

```crystal
# Bootstrap schema file from existing database (first-time setup)
migrator.bootstrap_schema

# Manually update schema file to match current database
migrator.update_schema_file

# Verify schema file matches database state
consistent = migrator.verify_schema_consistency
puts "Schema consistent: #{consistent}"

# Example: Manual sync workflow
unless migrator.verify_schema_consistency
  puts "Schema file out of sync - updating..."
  migrator.update_schema_file
  puts "Schema file updated!"
end
```

***

## Complete Migration Example

Here's a comprehensive example showing a complete migration workflow:

```crystal
# Define your schema
AppDB = CQL::Schema.define(
  :app_database,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://db/app.db"
) do
  table :users do
    primary :id, Int32
    column :name, String
    column :email, String
    timestamps
  end

  table :posts do
    primary :id, Int32
    column :title, String
    column :body, String
    column :user_id, Int32, null: true
    timestamps
    foreign_key [:user_id], references: :users, references_columns: [:id]
  end
end

# Migration 1: Create users table
class CreateUsersTable < CQL::Migration(20240101120000)
  def up
    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end

# Migration 2: Create posts table
class CreatePostsTable < CQL::Migration(20240101130000)
  def up
    schema.posts.create!
  end

  def down
    schema.posts.drop!
  end
end

# Migration 3: Add published flag to posts
class AddPublishedToPosts < CQL::Migration(20240102120000)
  def up
    schema.alter :posts do
      add_column :published, Bool, default: false
    end
  end

  def down
    schema.alter :posts do
      drop_column :published
    end
  end
end

# 🆕 Run migrations with automatic schema synchronization
config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  auto_sync: true
)
migrator = AppDB.migrator(config)

# Apply all migrations - schema file automatically updated!
migrator.up

# Check status
migrator.print_applied_migrations
# ✔ CreateUsersTable         20240101120000
# ✔ CreatePostsTable         20240101130000
# ✔ AddPublishedToPosts      20240102120000

# Schema file is now updated and ready for Active Record models!
require "./src/schemas/app_schema"

class User
  include CQL::ActiveRecord::Model(Int32)
  db_context AppSchema, :users

  property id : Int32?
  property name : String
  property email : String
  property created_at : Time?
  property updated_at : Time?
end

# Rollback last migration - schema file automatically updated!
migrator.down(1)

# Check status again
migrator.print_applied_migrations
# ✔ CreateUsersTable         20240101120000
# ✔ CreatePostsTable         20240101130000

migrator.print_pending_migrations
# ⏱ AddPublishedToPosts      20240102120000
```

***

## Integration with Application

### Development Workflow

```crystal
# db/migrations/001_create_schema.cr
class CreateSchema < CQL::Migration(20240101000000)
  def up
    AppDB.users.create!
    AppDB.posts.create!
  end

  def down
    AppDB.posts.drop!
    AppDB.users.drop!
  end
end

# db/migrate.cr
require "../src/schema"
require "./migrations/*"

migrator = CQL::Migrator.new(AppDB)

case ARGV[0]?
when "up"
  migrator.up
when "down"
  steps = ARGV[1]?.try(&.to_i) || 1
  migrator.down(steps)
when "status"
  migrator.print_applied_migrations
  migrator.print_pending_migrations
when "redo"
  migrator.redo
else
  puts "Usage: crystal db/migrate.cr [up|down|status|redo]"
end
```

### Running from Command Line

```bash
# Apply all pending migrations
crystal db/migrate.cr up

# Rollback last migration
crystal db/migrate.cr down

# Rollback last 3 migrations
crystal db/migrate.cr down 3

# Check migration status
crystal db/migrate.cr status

# Redo last migration
crystal db/migrate.cr redo
```

***

## Best Practices

### Migration Naming

* Use descriptive names: `CreateUsersTable`, `AddEmailToUsers`, `RemoveDeprecatedColumns`
* Include timestamp-based version numbers
* Keep migration files organized in a `migrations/` directory

### 🆕 Schema Synchronization Best Practices

```crystal
# 1. Always commit both migrations and schema files together
git add migrations/003_add_user_roles.cr
git add src/schemas/app_schema.cr
git commit -m "Add user roles migration and update schema"

# 2. Use environment-specific configurations
# Development: auto_sync: true for rapid iteration
# Production: auto_sync: false for manual control

# 3. Verify schema consistency in CI/CD
unless migrator.verify_schema_consistency
  puts "❌ DEPLOYMENT FAILED: Schema file out of sync"
  exit(1)
end

# 4. Bootstrap new developers easily
git clone project
migrator.up  # Applies migrations and generates schema file
# Ready to code with type-safe models!
```

### Safe Migration Practices

```crystal
# Good: Always provide rollback logic
class AddColumnSafely < CQL::Migration(20240115120000)
  def up
    schema.alter :users do
      add_column :phone, String, null: true  # Start with nullable
    end
  end

  def down
    schema.alter :users do
      drop_column :phone
    end
  end
end

# Good: Use transactions for multiple operations
class ComplexMigration < CQL::Migration(20240116120000)
  def up
    AppDB.schema.exec_query do |conn|
      conn.transaction do
        schema.alter :users do
          add_column :status, String, default: "active"
        end

        schema.alter :posts do
          add_column :user_status, String
        end
      end
    end
  end

  def down
    AppDB.schema.exec_query do |conn|
      conn.transaction do
        schema.alter :posts do
          drop_column :user_status
        end

        schema.alter :users do
          drop_column :status
        end
      end
    end
  end
end
```

### Data Migration Guidelines

```crystal
# When you need to migrate data, do it carefully
class MigrateUserData < CQL::Migration(20240117120000)
  def up
    # Add new column first
    schema.alter :users do
      add_column :full_name, String, null: true
    end

    # Migrate data (this should be done carefully in production)
    User.all.each do |user|
      user.full_name = "#{user.first_name} #{user.last_name}"
      user.save!
    end
  end

  def down
    schema.alter :users do
      drop_column :full_name
    end
  end
end
```

### Schema Tracking

* The migration system automatically tracks applied migrations in a `schema_migrations` table
* Don't modify or delete migration files after they've been applied in production
* Use new migrations to make further changes

***

## Troubleshooting

### Common Issues

1. **Migration Order**: Ensure version numbers are sequential and unique
2. **Rollback Logic**: Always provide working `down` methods
3. **Schema Conflicts**: Coordinate with team members on schema changes
4. **Data Dependencies**: Be careful when dropping columns that contain data

### Recovery from Failed Migrations

```crystal
# Check what migrations failed
migrator.print_applied_migrations

# If a migration partially succeeded, you may need to:
# 1. Fix the migration code
# 2. Manually clean up any partial changes
# 3. Re-run the migration

# For development, you can reset everything:
migrator.down  # Rollback all
migrator.up    # Apply all again
```

***

The CQL migration system provides a robust way to manage your database schema evolution while maintaining data integrity and team coordination.
