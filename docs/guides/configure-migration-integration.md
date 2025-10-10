# CQL Configuration + Migration Workflow Integration

This guide demonstrates the powerful integration between CQL's centralized configuration system and the migration workflow with automatic schema generation.

## Overview

The integrated system provides:

- **Centralized Configuration**: All database and migration settings in one place
- **Environment-Aware Migrations**: Automatic environment-specific migration behavior
- **Auto Schema Sync**: Schema files automatically generated and updated
- **Type-Safe Models**: Compile-time safety for Active Record models
- **Team Collaboration**: Consistent schema synchronization across team members

## Quick Start

### 1. Configure CQL with Migration Settings

```crystal
require "cql"

CQL.configure do |config|
  # Database settings
  config.database_url = "postgresql://localhost/myapp_development"
  config.pool_size = 10

  # Migration and schema settings
  config.schema_path = "src/schemas"
  config.schema_file_name = "app_schema.cr"
  config.schema_constant_name = :AppSchema
  config.enable_auto_schema_sync = true
  config.verify_schema_on_startup = true
end
```

### 2. Create Schema Using Configuration

```crystal
# Create schema using centralized configuration
AppDB = CQL.create_schema(:app_db) do
  # Tables will be managed by migrations
end
```

### 3. Define Migrations

```crystal
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

class CreatePosts < CQL::Migration(2)
  def up
    schema.table :posts do
      primary :id, Int64, auto_increment: true
      column :title, String, null: false
      column :content, String
      column :user_id, Int64, null: false
      column :published, Bool, default: false
      timestamps
    end
    schema.posts.create!

    schema.alter :posts do
      foreign_key [:user_id], references: :users, references_columns: [:id]
    end
  end

  def down
    schema.posts.drop!
  end
end
```

### 4. Run Migrations with Auto Schema Sync

```crystal
# Create migrator using configuration
migrator = CQL.create_migrator(AppDB)

# Run migrations - schema file automatically generated!
migrator.up

# Schema file now exists at src/schemas/app_schema.cr
```

### 5. Use Generated Schema in Active Record Models

```crystal
require "./src/schemas/app_schema"

class User
  include CQL::ActiveRecord::Model(Int64)
  db_context AppSchema, :users

  property id : Int64?
  property name : String
  property email : String
  property created_at : Time?
  property updated_at : Time?

  has_many :posts, Post, foreign_key: :user_id
end

class Post
  include CQL::ActiveRecord::Model(Int64)
  db_context AppSchema, :posts

  property id : Int64?
  property title : String
  property content : String?
  property user_id : Int64
  property published : Bool = false
  property created_at : Time?
  property updated_at : Time?

  belongs_to :user, User, :user_id
end
```

## Environment-Specific Configuration

### Development Environment

```crystal
CQL.configure do |config|
  config.environment = "development"
  # Automatically applied:
  # config.enable_auto_schema_sync = true
  # config.verify_schema_on_startup = true
  # config.enable_sql_logging = true
  # config.pool_size = 5

  config.database_url = "sqlite3://./db/development.db"
end
```

### Test Environment

```crystal
CQL.configure do |config|
  config.environment = "test"
  # Automatically applied:
  # config.database_url = "sqlite3://:memory:"
  # config.schema_file_name = "test_schema.cr"
  # config.schema_constant_name = :TestSchema
  # config.schema_symbol = :test_schema
  # config.enable_auto_schema_sync = true
  # config.pool_size = 1
end
```

### Production Environment

```crystal
CQL.configure do |config|
  config.environment = "production"
  config.database_url = ENV["DATABASE_URL"]
  # Automatically applied:
  # config.enable_auto_schema_sync = false  # Manual control
  # config.verify_schema_on_startup = true
  # config.pool_size = 25
  # config.enable_sql_logging = false
end
```

## Advanced Features

### Bootstrap from Existing Database

```crystal
# For existing databases
CQL.configure do |config|
  config.bootstrap_on_startup = true
  config.database_url = "postgresql://localhost/existing_app"
end

# Schema file automatically generated from existing database structure
schema = CQL.create_schema(:existing_app)
```

### Schema Verification and Auto-Fix

```crystal
# Verify schema consistency
consistent = CQL.verify_schema(AppDB)

# Auto-fix inconsistencies
consistent = CQL.verify_schema(AppDB, auto_fix: true)
```

### Helper Methods

```crystal
# Configuration helpers
puts CQL::ConfigHelpers.schema_file_path
puts CQL::ConfigHelpers.auto_schema_sync?

# Create migrator config
migrator_config = CQL::ConfigHelpers.create_migrator_config

# Schema operations
migrator = CQL.create_migrator(AppDB)
CQL.bootstrap_schema(AppDB)  # Bootstrap from existing DB
```

## Configuration Options

### Migration-Specific Options

| Option                     | Type     | Default           | Description                                  |
| -------------------------- | -------- | ----------------- | -------------------------------------------- |
| `enable_auto_schema_sync`  | `Bool`   | `true`            | Enable automatic schema file synchronization |
| `schema_file_name`         | `String` | `"app_schema.cr"` | Schema file name (without path)              |
| `schema_constant_name`     | `Symbol` | `:AppSchema`      | Schema constant name in generated file       |
| `schema_symbol`            | `Symbol` | `:app_schema`     | Schema symbol for internal use               |
| `bootstrap_on_startup`     | `Bool`   | `false`           | Bootstrap schema on first run                |
| `verify_schema_on_startup` | `Bool`   | `false`           | Verify schema consistency on startup         |

### Example Configuration

```crystal
CQL.configure do |config|
  # Database
  config.database_url = "postgresql://localhost/myapp"
  config.pool_size = 15

  # Schema Management
  config.schema_path = "src/schemas"
  config.schema_file_name = "myapp_schema.cr"
  config.schema_constant_name = :MyAppSchema
  config.schema_symbol = :myapp_schema

  # Migration Behavior
  config.enable_auto_schema_sync = true
  config.verify_schema_on_startup = true
  config.bootstrap_on_startup = false

  # Environment
  config.environment = "development"
  config.logger = Log.for("MyApp")
end
```

## Complete Workflow Example

Here's a complete example from configuration to model usage:

```crystal
# 1. Configuration
CQL.configure do |config|
  config.database_url = "postgresql://localhost/blog_app"
  config.schema_path = "src/schemas"
  config.enable_auto_schema_sync = true
end

# 2. Schema Creation
BlogDB = CQL.create_schema(:blog_db)

# 3. Migrations
class CreateUsers < CQL::Migration(20240101120000)
  def up
    schema.table :users do
      primary :id, Int64, auto_increment: true
      column :username, String, null: false
      column :email, String, null: false
      column :password_hash, String, null: false
      timestamps
    end
    schema.users.create!

    schema.alter :users do
      index [:email], unique: true
      index [:username], unique: true
    end
  end

  def down
    schema.users.drop!
  end
end

class CreatePosts < CQL::Migration(20240101130000)
  def up
    schema.table :posts do
      primary :id, Int64, auto_increment: true
      column :title, String, null: false
      column :content, String
      column :user_id, Int64, null: false
      column :published, Bool, default: false
      timestamps
    end
    schema.posts.create!

    schema.alter :posts do
      foreign_key [:user_id], references: :users, references_columns: [:id]
      index [:user_id, :published]
    end
  end

  def down
    schema.posts.drop!
  end
end

# 4. Run Migrations
migrator = CQL.create_migrator(BlogDB)
migrator.up

# 5. Schema File Generated at src/schemas/app_schema.cr
require "./src/schemas/app_schema"

# 6. Active Record Models
class User
  include CQL::ActiveRecord::Model(Int64)
  db_context AppSchema, :users

  property id : Int64?
  property username : String
  property email : String
  property password_hash : String
  property created_at : Time?
  property updated_at : Time?

  has_many :posts, foreign_key: :user_id

  validate :username, presence: true
  validate :email, presence: true, match: EMAIL_REGEX
end

class Post
  include CQL::ActiveRecord::Model(Int64)
  db_context AppSchema, :posts

  property id : Int64?
  property title : String
  property content : String?
  property user_id : Int64
  property published : Bool = false
  property created_at : Time?
  property updated_at : Time?

  belongs_to :user, User, :user_id

  validate :title, presence: true, size: 3..255
  validate :user_id, presence: true

  scope :published, -> { where(published: true) }
  scope :recent, -> { order(:created_at, :desc) }
end

# 7. Usage
user = User.create!(username: "alice", email: "alice@example.com", password_hash: "...")
post = user.posts.create!(title: "My First Post", content: "Hello, World!")

published_posts = Post.published.recent.limit(10).all
```

## Benefits

### For Developers

- **Single Configuration Point**: All database settings in one place
- **Type Safety**: Compile-time guarantees for model properties
- **Auto-Generated Code**: Schema files maintained automatically
- **Environment Awareness**: Smart defaults per environment

### For Teams

- **Consistent Setup**: Same configuration across all team members
- **Version Control**: Schema changes tracked with migrations
- **Easy Onboarding**: New team members get schema automatically
- **Conflict Resolution**: Automatic schema file updates

### For Production

- **Manual Control**: Disable auto-sync in production for safety
- **Verification**: Built-in schema consistency checking
- **Rollback Safety**: Full migration rollback with schema sync
- **Performance**: Optimized for production workloads

## Migration Commands

```crystal
# Create migrator
migrator = CQL.create_migrator(AppDB)

# Apply all pending migrations
migrator.up

# Rollback last migration
migrator.down(1)

# Rollback all migrations
migrator.down

# Redo last migration
migrator.redo

# Check migration status
pending = migrator.pending_migrations
applied = migrator.applied_migrations
last = migrator.last

# Schema operations
migrator.bootstrap_schema          # Generate from existing DB
migrator.update_schema_file        # Manual schema file update
migrator.verify_schema_consistency # Check consistency
```

## Best Practices

### 1. Environment-Specific Configuration

```crystal
# config/database.cr
case ENV["CRYSTAL_ENV"]? || "development"
when "production"
  CQL.configure do |config|
    config.environment = "production"
    config.database_url = ENV["DATABASE_URL"]
    config.enable_auto_schema_sync = false
  end
when "test"
  CQL.configure do |config|
    config.environment = "test"
    # Defaults applied automatically
  end
else
  CQL.configure do |config|
    config.environment = "development"
    config.database_url = "postgresql://localhost/myapp_dev"
  end
end
```

### 2. Migration Organization

```crystal
# migrations/001_create_users.cr
class CreateUsers < CQL::Migration(20240101120000)
  # Implementation
end

# migrations/002_create_posts.cr
class CreatePosts < CQL::Migration(20240101130000)
  # Implementation
end

# Load all migrations
Dir.glob("./migrations/*.cr").each { |file| require file }
```

### 3. Schema File Management

```crystal
# Add to .gitignore for auto-generated schemas in development
# src/schemas/app_schema.cr

# But commit schema files for production deployments
# Keep schema files in version control for production
```

### 4. Testing Strategy

```crystal
# spec/spec_helper.cr
CQL.configure do |config|
  config.environment = "test"
  config.database_url = "sqlite3://:memory:"
  config.migration_table_name = "test_schema_migrations"
end

# Set up test database
Spec.before_suite do
  TestDB = CQL.create_schema(:test_db)
  migrator = CQL.create_migrator(TestDB)
  migrator.up
end

# Clean up between tests
Spec.before_each do
  TestDB.query("DELETE FROM posts").commit
  TestDB.query("DELETE FROM users").commit
end
```

## Troubleshooting

### Schema File Not Generated

```crystal
# Check configuration
puts CQL.config.enable_auto_schema_sync?
puts CQL.config.schema_file_path

# Manual schema file generation
migrator = CQL.create_migrator(AppDB)
migrator.update_schema_file
```

### Schema Inconsistency

```crystal
# Check consistency
consistent = migrator.verify_schema_consistency
puts "Consistent: #{consistent}"

# Fix automatically
CQL.verify_schema(AppDB, auto_fix: true)
```

### Migration Errors

```crystal
# Check migration status
puts "Applied: #{migrator.applied_migrations.size}"
puts "Pending: #{migrator.pending_migrations.size}"

# Rollback and retry
migrator.down(1)  # Rollback problematic migration
# Fix migration code
migrator.up       # Reapply
```

---

## Examples

For complete working examples, see:

- `examples/configure_migration_example.cr` - Full integration demonstration
- `examples/schema_migration_workflow.cr` - SQLite workflow example
- `examples/schema_migration_workflow_pg.cr` - PostgreSQL workflow example

This integration provides a powerful, type-safe, and developer-friendly approach to database management in Crystal applications using CQL.
