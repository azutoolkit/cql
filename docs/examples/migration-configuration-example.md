# Migration Configuration Example

A comprehensive demonstration of CQL's integrated migration system with automatic schema synchronization, showing how to maintain up-to-date schema files through version-controlled migrations.

## 🎯 What You'll Learn

This example teaches you how to:

- **Integrate configuration** with migration workflows
- **Create automatic schema synchronization** between migrations and schema files
- **Manage environment-specific** migration configurations
- **Define and execute migrations** with automatic schema updates
- **Verify schema consistency** between database and schema files
- **Handle migration rollbacks** with schema synchronization
- **Use generated schema files** in Active Record models
- **Implement team collaboration** patterns for schema management

## 🚀 Quick Start

```bash
# Run the migration configuration example
crystal examples/configure_migration_example.cr
```

## 📁 Code Structure

```
examples/
├── configure_migration_example.cr    # Main migration configuration example
└── generated_schema.cr               # Auto-generated schema file
```

## 🔧 Key Features

### 1. Basic Migration Configuration

```crystal
CQL.configure do |config|
  # Basic database settings
  config.database_url = "sqlite3://examples/migration_example.db"
  config.logger = Log.for("CQLExample")
  config.environment = "development"

  # Migration and schema settings
  config.schema_path = "examples"
  config.schema_file_name = "generated_schema.cr"
  config.schema_constant_name = :GeneratedSchema
  config.schema_symbol = :generated_schema
  config.enable_auto_schema_sync = true
  config.verify_schema_on_startup = true
end
```

### 2. Schema Creation with Configuration

```crystal
# Create schema using configuration
AppDB = CQL.create_schema(:app_db) do
  # Initial minimal schema - will be managed by migrations
end

# Create migrator using configuration
migrator = CQL.create_migrator(AppDB)
```

### 3. Migration Definition

```crystal
# Migration 1: Create users table
class CreateUsers < CQL::Migration(1)
  def up
    puts "  📄 Creating users table..."
    schema.table :users do
      primary :id, Int32
      column :name, String, null: false
      column :email, String, null: false
      timestamps
    end
    schema.users.create!
  end

  def down
    puts "  📄 Dropping users table..."
    schema.users.drop!
  end
end

# Migration 2: Add email index
class AddEmailIndexToUsers < CQL::Migration(2)
  def up
    puts "  📄 Adding email index to users..."
    schema.alter :users do
      create_index :idx_users_email, [:email], unique: true
    end
  end

  def down
    puts "  📄 Dropping email index from users..."
    schema.alter :users do
      drop_index :idx_users_email
    end
  end
end
```

## 🏗️ Migration Workflow Architecture

```mermaid
graph TB
    subgraph "Configuration Layer"
        A[CQL.configure] --> B[Migration Settings]
        B --> C[Schema Settings]
        C --> D[Environment Detection]
    end

    subgraph "Migration System"
        E[Schema Definition] --> F[Migrator Creation]
        F --> G[Migration Execution]
        G --> H[Schema File Sync]
    end

    subgraph "Schema Management"
        I[Database Schema] --> J[Schema File Generation]
        J --> K[Schema Verification]
        K --> L[Active Record Models]
    end

    A --> E
    D --> F
    G --> I
    H --> J
    K --> L
```

## 📊 Migration Examples

### Complete Migration Workflow

```crystal
# 1. Configure with migration settings
CQL.configure do |config|
  config.database_url = "postgresql://localhost/myapp"
  config.schema_path = "src/schemas"
  config.enable_auto_schema_sync = true
  config.verify_schema_on_startup = true
end

# 2. Create schema
AppDB = CQL.create_schema(:app_db)

# 3. Define migrations
class CreateUsers < CQL::Migration(1)
  def up
    schema.table :users do
      primary :id, Int64, auto_increment: true
      column :name, String, null: false
      column :email, String, null: false
      timestamps
    end
    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end

# 4. Run migrations with auto schema sync
migrator = CQL.create_migrator(AppDB)
migrator.up

# 5. Schema file automatically created/updated
# 6. Use in Active Record models
require "./src/schemas/app_schema"

class User
  include CQL::ActiveRecord::Model(Int64)
  db_context AppSchema, :users

  property id : Int64?
  property name : String
  property email : String
  property created_at : Time?
  property updated_at : Time?
end
```

### Environment-Specific Migration Configurations

```crystal
# Development configuration
CQL.configure do |config|
  config.environment = "development"
  config.enable_auto_schema_sync = true
  config.verify_schema_on_startup = true
  config.bootstrap_on_startup = false
end

dev_migrator_config = CQL.config.create_migrator_config
puts "  Auto sync: #{dev_migrator_config.auto_sync?}"
puts "  Schema file: #{dev_migrator_config.schema_file_path}"

# Test configuration
CQL.configure do |config|
  config.environment = "test"
  # Environment defaults automatically applied
end

test_migrator_config = CQL.config.create_migrator_config
puts "  Schema file: #{test_migrator_config.schema_file_path}"
puts "  Schema name: #{test_migrator_config.schema_name}"

# Production configuration
CQL.configure do |config|
  config.environment = "production"
  # Environment defaults automatically applied
end

prod_migrator_config = CQL.config.create_migrator_config
puts "  Auto sync: #{prod_migrator_config.auto_sync?}"
puts "  Verify on startup: #{CQL.config.verify_schema_on_startup?}"
```

## 🔧 Migration Configuration Options

### Core Migration Settings

| Option                     | Type   | Default                  | Description                        |
| -------------------------- | ------ | ------------------------ | ---------------------------------- |
| `migration_table_name`     | Symbol | `:cql_schema_migrations` | Migration tracking table           |
| `schema_path`              | String | `"src/schemas"`          | Path where schema files are stored |
| `schema_file_name`         | String | `"app_schema.cr"`        | Default schema file name           |
| `schema_constant_name`     | Symbol | `:AppSchema`             | Schema constant name               |
| `enable_auto_schema_sync`  | Bool   | `true`                   | Auto schema synchronization        |
| `verify_schema_on_startup` | Bool   | `false`                  | Verify schema on startup           |

### Environment-Specific Defaults

| Environment | Auto Sync | Schema File            | Verify Startup | Bootstrap |
| ----------- | --------- | ---------------------- | -------------- | --------- |
| Development | `true`    | `app_schema.cr`        | `true`         | `false`   |
| Test        | `true`    | `test_schema.cr`       | `false`        | `false`   |
| Production  | `false`   | `production_schema.cr` | `true`         | `false`   |

## 🎯 Migration Workflow Patterns

### Basic Migration Workflow

```crystal
# 1. Configure migration system
CQL.configure do |config|
  config.database_url = "sqlite3://examples/migration_example.db"
  config.schema_path = "examples"
  config.schema_file_name = "generated_schema.cr"
  config.enable_auto_schema_sync = true
end

# 2. Create schema
AppDB = CQL.create_schema(:app_db)

# 3. Create migrator
migrator = CQL.create_migrator(AppDB)

# 4. Check pending migrations
pending = migrator.pending_migrations
puts "Pending migrations: #{pending.size}"

# 5. Run migrations
migrator.up

# 6. Verify schema consistency
consistent = CQL.verify_schema(AppDB)
puts "Schema consistency: #{consistent}"
```

### Migration Rollback with Schema Sync

```crystal
# Rollback last migration
migrator.rollback

# Check updated state
last_migration = migrator.last
puts "Last applied migration: #{last_migration ? last_migration.name : "None"}"

# Re-apply migration
migrator.redo
```

### Schema Verification

```crystal
# Verify schema consistency
consistent = CQL.verify_schema(AppDB, auto_fix: true)
if consistent
  puts "✅ Schema is consistent with database"
else
  puts "❌ Schema inconsistency detected"
end

# Manual schema update
migrator.update_schema_file
puts "Schema file manually updated!"
```

## 🔧 Configuration Helpers

### Using Configuration Helpers

```crystal
# Access migration configuration through helpers
puts "Schema file path: #{CQL::ConfigHelpers.schema_file_path}"
puts "Schema path: #{CQL::ConfigHelpers.schema_path}"
puts "Auto sync enabled: #{CQL::ConfigHelpers.auto_schema_sync?}"
puts "Environment: #{CQL::ConfigHelpers.environment}"

# Create migrator config using helper
helper_config = CQL::ConfigHelpers.create_migrator_config
puts "Helper-created config auto_sync: #{helper_config.auto_sync?}"
```

### Environment-Specific Helpers

```crystal
# Create environment-specific migrator config
dev_config = CQL.create_migrator_config_for_environment("development")
test_config = CQL.create_migrator_config_for_environment("test")
prod_config = CQL.create_migrator_config_for_environment("production")

puts "Development auto_sync: #{dev_config.auto_sync?}"
puts "Test schema file: #{test_config.schema_file_path}"
puts "Production auto_sync: #{prod_config.auto_sync?}"
```

## 🎯 Team Workflow Scenarios

### New Team Member Setup

```bash
# 1. Clone repository
git clone <repository>

# 2. Set up local database
# (Database setup depends on your configuration)

# 3. Run migrations
crystal run migration_runner.cr

# 4. Schema file automatically created and ready to use
```

### Resolving Schema Conflicts

```bash
# 1. Pull latest changes
git pull origin main

# 2. Apply any new migrations
crystal run migration_runner.cr

# 3. Regenerate schema file
crystal run -e "CQL.create_migrator(AppDB).update_schema_file"

# 4. Commit updated schema
git add src/schemas/app_schema.cr
git commit -m "Update schema file after migrations"
```

### Production Deployment

```bash
# 1. Set production configuration
export CRYSTAL_ENV=production
export DATABASE_URL=postgresql://user:pass@prod-db/app

# 2. Apply migrations
crystal run migration_runner.cr

# 3. Verify schema consistency
crystal run -e "puts CQL.verify_schema(AppDB)"

# 4. Deploy application with updated schema file
```

## 📊 Generated Schema Files

### Schema File Structure

```crystal
# Generated schema file (examples/generated_schema.cr)
GeneratedSchema = CQL::Schema.define(
  :generated_schema,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://examples/migration_example.db") do
  table :schema_migrations do
    primary :id, Int32
    text :name
    integer :version
    timestamps
  end

  table :users do
    primary :id, Int32
    text :name
    text :email
    timestamps
  end

  table :posts do
    primary :id, Int32
    text :title
    text :content
    bigint :user_id
    boolean :published, default: "0"
    timestamps
    foreign_key [:user_id], references: :users, references_columns: [:id]
  end
end
```

### Using Generated Schema in Models

```crystal
# Load the generated schema
require "./examples/generated_schema"

# Use in Active Record models
class User
  include CQL::ActiveRecord::Model(Int32)
  db_context GeneratedSchema, :users

  property id : Int32?
  property name : String
  property email : String
  property created_at : Time?
  property updated_at : Time?
end

class Post
  include CQL::ActiveRecord::Model(Int32)
  db_context GeneratedSchema, :posts

  property id : Int32?
  property title : String
  property content : String
  property user_id : Int32
  property published : Bool
  property created_at : Time?
  property updated_at : Time?

  belongs_to :user, User, foreign_key: :user_id
end
```

## 🔧 Advanced Migration Patterns

### Complex Migration with Foreign Keys

```crystal
class CreatePostsTable < CQL::Migration(3)
  def up
    puts "  📄 Creating posts table..."

    schema.table :posts do
      primary :id, Int32
      column :title, String
      column :content, String
      column :user_id, Int32
      timestamps

      # Include foreign key constraint during table creation
      foreign_key [:user_id], references: :users, references_columns: [:id]
    end

    schema.posts.create!
  end

  def down
    puts "  📄 Dropping posts table..."
    schema.posts.drop!
  end
end
```

### Adding Columns to Existing Tables

```crystal
class AddPublishedToPosts < CQL::Migration(4)
  def up
    puts "  📄 Adding published column to posts..."
    schema.alter :posts do
      add_column :published, Bool, default: false
    end
  end

  def down
    puts "  📄 Removing published column from posts..."
    schema.alter :posts do
      drop_column :published
    end
  end
end
```

### Index Management

```crystal
class AddEmailIndex < CQL::Migration(2)
  def up
    puts "  📄 Adding email index to users..."
    schema.alter :users do
      create_index :email_idx, [:email], unique: true
    end
  end

  def down
    puts "  📄 Dropping email index from users..."
    schema.alter :users do
      drop_index :email_idx
    end
  end
end
```

## 🎯 Best Practices

### 1. Environment-Specific Configuration

```crystal
# config/migrations.cr
case ENV["CRYSTAL_ENV"]? || "development"
when "production"
  CQL.configure do |config|
    config.enable_auto_schema_sync = false
    config.verify_schema_on_startup = true
    config.schema_file_name = "production_schema.cr"
  end
when "test"
  CQL.configure do |config|
    config.enable_auto_schema_sync = true
    config.schema_file_name = "test_schema.cr"
    config.schema_constant_name = :TestSchema
  end
else
  CQL.configure do |config|
    config.enable_auto_schema_sync = true
    config.verify_schema_on_startup = true
  end
end
```

### 2. Migration Naming Conventions

```crystal
# Use descriptive migration names
class CreateUsersTable < CQL::Migration(1)
class AddEmailIndexToUsers < CQL::Migration(2)
class CreatePostsTable < CQL::Migration(3)
class AddPublishedColumnToPosts < CQL::Migration(4)
class AddUserProfileTable < CQL::Migration(5)
```

### 3. Schema File Management

```crystal
# Always commit schema files with migrations
git add src/schemas/app_schema.cr
git commit -m "Update schema after migration: Add user profiles"

# Verify schema consistency in CI/CD
crystal run -e "exit 1 unless CQL.verify_schema(AppDB)"
```

## 📚 Next Steps

### Related Examples

- **[Schema Migration Workflow](schema-migration-workflow.md)** - Detailed migration workflow
- **[PostgreSQL Migration Workflow](postgresql-migration-workflow.md)** - PostgreSQL-specific patterns
- **[Blog Engine](blog-engine.md)** - See migrations in a complete application

### Advanced Topics

- **[Migration Guide](../guides/active-record-with-cql/migrations.md)** - Complete migration documentation
- **[Integrated Migration Workflow](../guides/active-record-with-cql/integrated-migration-workflow.md)** - Advanced workflow patterns
- **[Schema Management](../core-concepts/schemas.md)** - Schema definition and management

### Production Considerations

- **Migration Safety** - Always test migrations in staging
- **Schema Consistency** - Verify schema files match database
- **Rollback Strategy** - Ensure migrations can be safely rolled back
- **Team Coordination** - Coordinate schema changes across team
- **CI/CD Integration** - Automate migration and schema verification

## 🔧 Troubleshooting

### Common Issues

1. **Schema file not generated** - Check `enable_auto_schema_sync` setting
2. **Migration conflicts** - Ensure migration versions are sequential
3. **Schema inconsistency** - Run `CQL.verify_schema(AppDB)` to check
4. **Rollback issues** - Ensure all migrations have proper `down` methods

### Debug Migration Issues

```crystal
# Check migration status
migrator = CQL.create_migrator(AppDB)
puts "Pending: #{migrator.pending_migrations.size}"
puts "Applied: #{migrator.applied_migrations.size}"

# Verify schema consistency
consistent = CQL.verify_schema(AppDB)
puts "Schema consistent: #{consistent}"

# Check schema file path
puts "Schema file: #{CQL.config.schema_file_path}"
puts "Schema file exists: #{File.exists?(CQL.config.schema_file_path)}"
```

---

## 🏁 Summary

This migration configuration example demonstrates:

- ✅ **Integrated migration workflow** with automatic schema synchronization
- ✅ **Environment-specific configurations** for different deployment stages
- ✅ **Automatic schema file generation** from database migrations
- ✅ **Schema consistency verification** between database and files
- ✅ **Team collaboration patterns** for schema management
- ✅ **Production-ready deployment** with proper migration handling
- ✅ **Configuration helpers** for common migration operations

Ready to implement migration workflows in your CQL application? Start with basic migrations and gradually add advanced features like schema synchronization! 🚀
