# PostgreSQL Migration Workflow Example

A comprehensive demonstration of CQL's integrated schema migration workflow using PostgreSQL, showing how to manage database schema evolution with PostgreSQL-specific features, automatic schema file synchronization, and production-ready deployment patterns.

## 🎯 What You'll Learn

This example teaches you how to:

- **Set up PostgreSQL migration workflows** with automatic schema synchronization
- **Leverage PostgreSQL-specific features** like JSONB, arrays, and advanced indexing
- **Handle PostgreSQL migration patterns** with proper foreign key constraints
- **Manage production PostgreSQL deployments** with migration safety
- **Use PostgreSQL-specific data types** and constraints in migrations
- **Implement advanced PostgreSQL features** like partial indexes and expression indexes
- **Handle PostgreSQL-specific rollback scenarios** safely
- **Optimize migrations for PostgreSQL performance**

## 🚀 Quick Start

```bash
# Set up PostgreSQL database (if not already running)
# Ensure DATABASE_URL environment variable is set
export DATABASE_URL="postgresql://user:pass@localhost/cql_example_db"

# Run the PostgreSQL migration workflow example
crystal examples/schema_migration_workflow_pg.cr
```

## 📁 Code Structure

```
examples/
├── schema_migration_workflow_pg.cr    # Main PostgreSQL migration workflow example
└── generated_app_schema.cr            # Auto-generated schema file
```

## 🔧 Key Features

### 1. PostgreSQL Schema Definition

```crystal
# Step 1: Define Base Schema Connection for PostgreSQL
AppDB = CQL::Schema.define(
  :app_database,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]? || "postgresql://localhost/cql_example_db"
) do
  # Minimal initial structure - will be populated by migrations
  # The migrator will ensure this stays in sync with the database
end
```

### 2. PostgreSQL Migration System Configuration

```crystal
# Step 2: Configure Migration System for PostgreSQL
config = CQL::MigratorConfig.new(
  schema_file_path: "examples/generated_app_schema.cr",
  schema_name: :GeneratedAppSchema,
  schema_symbol: :generated_app_schema,
  auto_sync: true # Automatically update schema file after migrations
)

migrator = AppDB.migrator(config)
```

### 3. PostgreSQL-Specific Migration Definition

```crystal
# Migration 1: Create users table with PostgreSQL features
class CreateUsersTable < CQL::Migration(1)
  def up
    puts "📄 Migration 1: Creating users table..."

    schema.table :users do
      primary :id, Int32
      column :name, String
      column :email, String
      column :metadata, String, null: true # Will be JSONB in PostgreSQL
      timestamps
    end

    schema.users.create!
  end

  def down
    puts "📄 Migration 1 (rollback): Dropping users table..."
    schema.users.drop!
  end
end

# Migration 2: Add PostgreSQL-specific indexes
class AddPostgresIndexes < CQL::Migration(2)
  def up
    puts "📄 Migration 2: Adding PostgreSQL indexes..."
    schema.alter :users do
      create_index :email_idx, [:email], unique: true
      # PostgreSQL-specific: Partial index for active users
      create_index :active_users_idx, [:email], where: "active = true"
    end
  end

  def down
    puts "📄 Migration 2 (rollback): Dropping PostgreSQL indexes..."
    schema.alter :users do
      drop_index :email_idx
      drop_index :active_users_idx
    end
  end
end
```

## 🏗️ PostgreSQL Migration Workflow Architecture

```mermaid
graph TB
    subgraph "PostgreSQL Database"
        A[PostgreSQL Server] --> B[Database Schema]
        B --> C[Advanced Features]
        C --> D[JSONB Columns]
        C --> E[Array Types]
        C --> F[Advanced Indexes]
    end

    subgraph "Migration System"
        G[Schema Definition] --> H[Migrator Creation]
        H --> I[Migration Execution]
        I --> J[Schema File Sync]
    end

    subgraph "PostgreSQL Features"
        K[Foreign Key Constraints] --> L[Check Constraints]
        L --> M[Unique Constraints]
        M --> N[Expression Indexes]
    end

    I --> A
    J --> O[Generated Schema File]
    O --> P[Active Record Models]
```

## 📊 PostgreSQL Migration Examples

### Complete PostgreSQL Migration Workflow

```crystal
def demonstrate_workflow(migrator : CQL::Migrator)
  puts "🚀 CQL PostgreSQL Migration Workflow Demonstration"
  puts "=" * 50

  # Initialize fresh PostgreSQL database
  puts "🗃️  Setting up fresh PostgreSQL database..."

  # Clean up previous schema file
  File.delete("examples/generated_app_schema.cr") if File.exists?("examples/generated_app_schema.cr")

  # Drop and recreate all tables for a clean start
  begin
    # Try to drop tables if they exist (ignore errors if they don't exist)
    ["posts", "users", "schema_migrations"].each do |table|
      AppDB.exec("DROP TABLE IF EXISTS #{table} CASCADE") rescue nil
    end
  rescue ex
    puts "Error dropping tables: #{ex.message}"
    puts "Database might not exist yet"
  end

  puts "\n📊 Initial Migration Status:"
  puts "Pending migrations:"
  migrator.pending_migrations.each do |migration|
    puts "  ⏱ #{migration.name} (version #{migration.version})"
  end

  puts "\n⬆️  Applying all migrations..."
  puts "This will automatically update the schema file after each migration."
  migrator.up

  puts "\n📊 Migration Status After Up:"
  puts "Applied migrations:"
  migrator.applied_migrations.each do |migration|
    puts "  ✔ #{migration.name} (version #{migration.version})"
  end

  puts "\n📁 Generated Schema File:"
  if File.exists?("examples/generated_app_schema.cr")
    schema_content = File.read("examples/generated_app_schema.cr")
    puts "File: examples/generated_app_schema.cr"
    puts "-" * 40
    puts schema_content
    puts "-" * 40
  else
    puts "❌ Schema file not found!"
  end

  puts "\n✅ Verifying Schema Consistency:"
  consistent = migrator.verify_schema_consistency
  puts "Schema is consistent with database: #{consistent}"
end
```

### PostgreSQL-Specific Migration Patterns

```crystal
# Migration 3: Create posts table with PostgreSQL features
class CreatePostsTable < CQL::Migration(3)
  def up
    puts "📄 Migration 3: Creating posts table..."

    schema.table :posts do
      primary :id, Int32
      column :title, String
      column :content, String
      column :user_id, Int32
      column :tags, String, null: true # Will be text[] in PostgreSQL
      column :metadata, String, null: true # Will be JSONB in PostgreSQL
      timestamps

      # Include foreign key constraint during table creation
      foreign_key [:user_id], references: :users, references_columns: [:id]
    end

    schema.posts.create!
  end

  def down
    puts "📄 Migration 3 (rollback): Dropping posts table..."
    schema.posts.drop!
  end
end

# Migration 4: Add PostgreSQL-specific columns
class AddPostgresFeatures < CQL::Migration(4)
  def up
    puts "📄 Migration 4: Adding PostgreSQL features..."
    schema.alter :posts do
      add_column :published, Bool, default: false
      add_column :view_count, Int32, default: 0
      # PostgreSQL-specific: Add check constraint
      add_check_constraint :positive_view_count, "view_count >= 0"
    end
  end

  def down
    puts "📄 Migration 4 (rollback): Removing PostgreSQL features..."
    schema.alter :posts do
      drop_check_constraint :positive_view_count
      drop_column :view_count
      drop_column :published
    end
  end
end
```

## 🔧 PostgreSQL-Specific Features

### Advanced Indexing

```crystal
# Migration 5: PostgreSQL advanced indexes
class AddAdvancedIndexes < CQL::Migration(5)
  def up
    puts "📄 Migration 5: Adding PostgreSQL advanced indexes..."

    # Expression index for case-insensitive email search
    schema.exec("CREATE INDEX idx_users_email_lower ON users (LOWER(email))")

    # Partial index for published posts
    schema.exec("CREATE INDEX idx_posts_published ON posts (created_at) WHERE published = true")

    # GIN index for JSONB metadata (if using JSONB)
    schema.exec("CREATE INDEX idx_posts_metadata ON posts USING GIN (metadata)")
  end

  def down
    puts "📄 Migration 5 (rollback): Dropping PostgreSQL advanced indexes..."
    schema.exec("DROP INDEX IF EXISTS idx_users_email_lower")
    schema.exec("DROP INDEX IF EXISTS idx_posts_published")
    schema.exec("DROP INDEX IF EXISTS idx_posts_metadata")
  end
end
```

### JSONB and Array Support

```crystal
# Migration 6: PostgreSQL data types
class AddPostgresDataTypes < CQL::Migration(6)
  def up
    puts "📄 Migration 6: Adding PostgreSQL data types..."

    # Add JSONB column for flexible metadata
    schema.exec("ALTER TABLE users ADD COLUMN preferences JSONB DEFAULT '{}'")

    # Add array column for tags
    schema.exec("ALTER TABLE posts ADD COLUMN tag_list TEXT[] DEFAULT '{}'")

    # Add UUID column (PostgreSQL native)
    schema.exec("ALTER TABLE users ADD COLUMN external_id UUID")
    schema.exec("CREATE INDEX idx_users_external_id ON users (external_id)")
  end

  def down
    puts "📄 Migration 6 (rollback): Removing PostgreSQL data types..."
    schema.exec("DROP INDEX IF EXISTS idx_users_external_id")
    schema.exec("ALTER TABLE users DROP COLUMN IF EXISTS external_id")
    schema.exec("ALTER TABLE posts DROP COLUMN IF EXISTS tag_list")
    schema.exec("ALTER TABLE users DROP COLUMN IF EXISTS preferences")
  end
end
```

## 📊 Generated PostgreSQL Schema Files

### PostgreSQL Schema File Structure

```crystal
# Generated schema file (examples/generated_app_schema.cr)
GeneratedAppSchema = CQL::Schema.define(
  :generated_app_schema,
  adapter: CQL::Adapter::Postgres,
  uri: "postgresql://localhost/cql_example_db") do
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
    jsonb :preferences, default: "{}"
    uuid :external_id, null: true
    timestamps
  end

  table :posts do
    primary :id, Int32
    text :title
    text :content
    bigint :user_id
    text[] :tag_list, default: "{}"
    jsonb :metadata, null: true
    boolean :published, default: "false"
    integer :view_count, default: "0"
    timestamps
    foreign_key [:user_id], references: :users, references_columns: [:id]
    check_constraint :positive_view_count, "view_count >= 0"
  end
end
```

### Using PostgreSQL Schema in Models

```crystal
# Load the generated schema
require "./examples/generated_app_schema"

# Use in Active Record models with PostgreSQL features
class User
  include CQL::ActiveRecord::Model(Int32)
  db_context GeneratedAppSchema, :users

  property id : Int32?
  property name : String
  property email : String
  property preferences : String? # JSONB as String
  property external_id : String? # UUID as String
  property created_at : Time?
  property updated_at : Time?

  # Parse JSONB preferences
  def parsed_preferences
    return {} of String => String if preferences.nil?
    JSON.parse(preferences.not_nil!).as_h
  end
end

class Post
  include CQL::ActiveRecord::Model(Int32)
  db_context GeneratedAppSchema, :posts

  property id : Int32?
  property title : String
  property content : String
  property user_id : Int32
  property tag_list : String? # Array as String
  property metadata : String? # JSONB as String
  property published : Bool
  property view_count : Int32
  property created_at : Time?
  property updated_at : Time?

  belongs_to :user, User, foreign_key: :user_id

  # Parse tag array
  def tags
    return [] of String if tag_list.nil?
    tag_list.not_nil!.split(",").map(&.strip)
  end

  # Parse JSONB metadata
  def parsed_metadata
    return {} of String => String if metadata.nil?
    JSON.parse(metadata.not_nil!).as_h
  end
end
```

## 🎯 PostgreSQL-Specific Workflow Scenarios

### New Team Member Setup (PostgreSQL)

```bash
# 1. Clone repository
git clone <repository>

# 2. Set up local PostgreSQL database
createdb cql_example_db

# 3. Set DATABASE_URL environment variable
export DATABASE_URL="postgresql://localhost/cql_example_db"

# 4. Run migrations
crystal run migration_runner.cr

# 5. Schema file automatically created and ready to use
```

### Resolving Schema Conflicts (PostgreSQL)

```bash
# 1. Pull latest changes
git pull origin main

# 2. Ensure DATABASE_URL is correctly set
export DATABASE_URL="postgresql://localhost/cql_example_db"

# 3. Apply any new migrations
crystal run migration_runner.cr

# 4. Regenerate schema file
crystal run -e "CQL.create_migrator(AppDB).update_schema_file"

# 5. Commit updated schema
git add examples/generated_app_schema.cr
git commit -m "Update schema file after PostgreSQL migrations"
```

### Production Deployment (PostgreSQL)

```bash
# 1. Set production configuration
export CRYSTAL_ENV=production
export DATABASE_URL="postgresql://user:pass@prod-db/app"

# 2. Apply migrations
crystal run migration_runner.cr

# 3. Verify schema consistency
crystal run -e "puts CQL.verify_schema(AppDB)"

# 4. Deploy application with updated schema file
```

## 🔧 PostgreSQL Configuration Examples

### Development Configuration (PostgreSQL)

```crystal
# Development configuration
puts "\n🔧 Development Configuration (PostgreSQL):"
CQL.configure do |config|
  config.environment = "development"
  config.database_url = "postgresql://localhost/myapp_development"
  config.enable_auto_schema_sync = true
  config.verify_schema_on_startup = true
  config.bootstrap_on_startup = false
end

dev_migrator_config = CQL.config.create_migrator_config
puts "  Adapter: CQL::Adapter::Postgres"
puts "  Auto sync: #{dev_migrator_config.auto_sync?}"
puts "  Schema file: #{dev_migrator_config.schema_file_path}"
puts "  Database URL: #{CQL.config.database_url}"
```

### Production Configuration (PostgreSQL)

```crystal
# Production configuration
puts "\n🏭 Production Configuration (PostgreSQL):"
CQL.configure do |config|
  config.environment = "production"
  config.database_url = ENV["DATABASE_URL"]
  config.enable_auto_schema_sync = false
  config.verify_schema_on_startup = true
end

prod_migrator_config = CQL.config.create_migrator_config
puts "  Adapter: CQL::Adapter::Postgres"
puts "  Auto sync: #{prod_migrator_config.auto_sync?}"
puts "  Schema file: #{prod_migrator_config.schema_file_path}"
puts "  Database URL: production DATABASE_URL from environment"
```

## 🎯 PostgreSQL Best Practices

### 1. PostgreSQL-Specific Migration Naming

```crystal
# Use descriptive migration names for PostgreSQL features
class CreateUsersTable < CQL::Migration(1)
class AddPostgresIndexes < CQL::Migration(2)
class CreatePostsTable < CQL::Migration(3)
class AddPostgresFeatures < CQL::Migration(4)
class AddAdvancedIndexes < CQL::Migration(5)
class AddPostgresDataTypes < CQL::Migration(6)
```

### 2. PostgreSQL Migration Safety

```crystal
# Always implement both up and down methods for PostgreSQL
class SafePostgresMigration < CQL::Migration(7)
  def up
    # Add PostgreSQL-specific feature
    schema.exec("ALTER TABLE users ADD COLUMN last_login TIMESTAMP WITH TIME ZONE")
    schema.exec("CREATE INDEX idx_users_last_login ON users (last_login)")
  end

  def down
    # Remove PostgreSQL-specific feature safely
    schema.exec("DROP INDEX IF EXISTS idx_users_last_login")
    schema.exec("ALTER TABLE users DROP COLUMN IF EXISTS last_login")
  end
end
```

### 3. PostgreSQL Schema File Management

```crystal
# Always commit schema files with PostgreSQL migrations
git add examples/generated_app_schema.cr
git commit -m "Update PostgreSQL schema after migration: Add JSONB support"

# Verify PostgreSQL schema consistency in CI/CD
crystal run -e "exit 1 unless CQL.verify_schema(AppDB)"
```

## 📚 Next Steps

### Related Examples

- **[Schema Migration Workflow](schema-migration-workflow.md)** - SQLite migration workflow
- **[Migration Configuration](migration-configuration-example.md)** - Configuration integration
- **[Blog Engine](blog-engine.md)** - See migrations in a complete application

### Advanced Topics

- **[Migration Guide](../guides/active-record-with-cql/migrations.md)** - Complete migration documentation
- **[Integrated Migration Workflow](../guides/active-record-with-cql/integrated-migration-workflow.md)** - Advanced workflow patterns
- **[Schema Management](../core-concepts/schemas.md)** - Schema definition and management

### PostgreSQL-Specific Considerations

- **Performance Optimization** - Use PostgreSQL-specific indexes and features
- **Data Type Selection** - Choose appropriate PostgreSQL data types
- **Constraint Management** - Leverage PostgreSQL constraints and checks
- **Backup Strategy** - Implement PostgreSQL-specific backup procedures
- **Connection Pooling** - Configure PostgreSQL connection pools appropriately

## 🔧 PostgreSQL Troubleshooting

### Common PostgreSQL Issues

1. **Connection issues** - Check DATABASE_URL and PostgreSQL server status
2. **Permission errors** - Ensure database user has proper permissions
3. **Data type conflicts** - Verify PostgreSQL data type compatibility
4. **Index creation failures** - Check for duplicate index names

### Debug PostgreSQL Migration Issues

```crystal
# Check PostgreSQL connection
begin
  AppDB.exec("SELECT version()")
  puts "PostgreSQL connection successful"
rescue ex
  puts "PostgreSQL connection failed: #{ex.message}"
end

# Check migration status
puts "Pending migrations: #{migrator.pending_migrations.size}"
puts "Applied migrations: #{migrator.applied_migrations.size}"

# Verify PostgreSQL schema consistency
consistent = migrator.verify_schema_consistency
puts "PostgreSQL schema consistent: #{consistent}"

# Check PostgreSQL-specific features
begin
  AppDB.exec("SELECT jsonb_typeof('{}')")
  puts "JSONB support available"
rescue ex
  puts "JSONB support not available: #{ex.message}"
end
```

---

## 🏁 Summary

This PostgreSQL migration workflow example demonstrates:

- ✅ **PostgreSQL-specific migration patterns** with advanced features
- ✅ **JSONB and array data type support** for flexible data storage
- ✅ **Advanced indexing strategies** including expression and partial indexes
- ✅ **Production-ready PostgreSQL deployment** with proper migration handling
- ✅ **PostgreSQL-specific constraints** and data validation
- ✅ **Team collaboration patterns** for PostgreSQL schema management
- ✅ **PostgreSQL performance optimization** techniques

Ready to implement PostgreSQL migration workflows in your CQL application? Start with basic migrations and gradually add PostgreSQL-specific features as needed! 🚀
