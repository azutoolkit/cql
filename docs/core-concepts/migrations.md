# Migrations

Migrations in CQL provide a structured way to manage incremental changes to your database schema over time. They work in conjunction with the SchemaDump feature to maintain an up-to-date representation of your database schema.

## Overview

CQL migrations consist of three main components:

1. **Migration Classes**: Define incremental schema changes
2. **Migrator**: Executes migrations and manages schema synchronization
3. **AppSchema.cr**: Central schema file that reflects the current database state

## Schema Synchronization Workflow

### 1. Initial Bootstrap (Existing Database)

If you have an existing database, start by bootstrapping your AppSchema.cr:

```crystal
# Initialize your schema connection
MyDB = CQL::Schema.define(
  :my_database,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do
  # This will be populated by bootstrap
end

# Configure the migrator for schema synchronization
config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  schema_symbol: :app_schema,
  auto_sync: true
)

migrator = MyDB.migrator(config)

# Bootstrap the schema file from existing database
migrator.bootstrap_schema
```

This creates `src/schemas/app_schema.cr` with the current database structure:

```crystal
AppSchema = CQL::Schema.define(
  :app_schema,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]) do

  table :users do
    primary :id, Int32
    text :name
    text :email
    timestamp :created_at, null: true
    timestamp :updated_at, null: true
  end

  table :posts do
    primary :id, Int32
    text :title
    text :content
    integer :user_id
    timestamp :created_at, null: true
    timestamp :updated_at, null: true

    foreign_key [:user_id], references: :users, references_columns: [:id]
  end
end
```

### 2. Creating Migrations

Create migration classes to define schema changes:

```crystal
# migrations/001_add_email_index.cr
class AddEmailIndex < CQL::Migration(1)
  def up
    schema.alter :users do
      create_index :email_idx, [:email], unique: true
    end
  end

  def down
    schema.alter :users do
      drop_index :email_idx
    end
  end
end

# migrations/002_add_posts_published_column.cr
class AddPostsPublishedColumn < CQL::Migration(2)
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
```

### 3. Running Migrations with Auto-Sync

When you run migrations, the AppSchema.cr file is automatically updated:

```crystal
# Initialize your working schema (can be minimal)
MyDB = CQL::Schema.define(
  :my_database,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do
  # Tables will be managed by migrations
end

# Configure migrator with auto-sync enabled (default)
config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  schema_symbol: :app_schema,
  auto_sync: true  # Automatically update schema file after migrations
)

migrator = MyDB.migrator(config)

# Apply all pending migrations
# This will automatically update AppSchema.cr after each migration
migrator.up

# Roll back the last migration
# This will automatically update AppSchema.cr to reflect the rollback
migrator.rollback

# Apply migrations up to a specific version
migrator.up_to(5)
```

### 4. Manual Schema Synchronization

You can also manually update the schema file:

```crystal
# Manually update the schema file to match current database state
migrator.update_schema_file

# Verify that the schema file matches the database
consistent = migrator.verify_schema_consistency
puts "Schema is consistent: #{consistent}"
```

## Migration Management

### Checking Migration Status

```crystal
# List applied migrations
migrator.print_applied_migrations

# List pending migrations
migrator.print_pending_migrations

# Get the last applied migration
last_migration = migrator.last
puts "Last migration: #{last_migration.try(&.name)}" if last_migration
```

### Rollback Operations

```crystal
# Rollback last migration
migrator.rollback

# Rollback multiple migrations
migrator.rollback(3)

# Rollback to specific version
migrator.down_to(2)

# Redo last migration (rollback then apply)
migrator.redo
```

## Configuration Options

### MigratorConfig

```crystal
config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",  # Where to save schema file
  schema_name: :AppSchema,                        # Constant name in schema file
  schema_symbol: :app_schema,                     # Symbol name for schema
  auto_sync: true                                 # Auto-update schema file after migrations
)
```

### Disabling Auto-Sync

If you prefer manual control over schema synchronization:

```crystal
config = CQL::MigratorConfig.new(auto_sync: false)
migrator = MyDB.migrator(config)

# Run migrations without auto-updating schema file
migrator.up

# Manually update when needed
migrator.update_schema_file
```

## Best Practices

### 1. Version Control Integration

Always commit both your migrations and the updated AppSchema.cr:

```bash
git add migrations/003_add_user_roles.cr
git add src/schemas/app_schema.cr
git commit -m "Add user roles migration and update schema"
```

### 2. Schema File Organization

Keep your schema files organized:

```
src/schemas/
├── app_schema.cr          # Main application schema (auto-generated)
├── test_schema.cr         # Test-specific schema
└── development_schema.cr  # Development overrides
```

### 3. Environment-Specific Configurations

Use different configurations for different environments:

```crystal
# config/database.cr
database_config = case ENV["CRYSTAL_ENV"]?
when "production"
  CQL::MigratorConfig.new(
    schema_file_path: "src/schemas/production_schema.cr",
    schema_name: :ProductionSchema,
    auto_sync: false  # Manual control in production
  )
when "test"
  CQL::MigratorConfig.new(
    schema_file_path: "src/schemas/test_schema.cr",
    schema_name: :TestSchema,
    auto_sync: true
  )
else
  CQL::MigratorConfig.new(
    schema_file_path: "src/schemas/app_schema.cr",
    schema_name: :AppSchema,
    auto_sync: true
  )
end
```

### 4. Continuous Integration

Verify schema consistency in CI:

```crystal
# In your test setup
migrator = AppDB.migrator(config)
unless migrator.verify_schema_consistency
  puts "ERROR: Schema file is out of sync with database!"
  puts "Run: migrator.update_schema_file"
  exit(1)
end
```

## Important Considerations

### 1. Schema File Conflicts

When working in teams, schema file conflicts can occur. To resolve:

1. Pull latest changes
2. Run migrations to sync database
3. Update schema file: `migrator.update_schema_file`
4. Commit the updated schema file

### 2. Production Deployments

For production environments:

1. Set `auto_sync: false` in production config
2. Run migrations: `migrator.up`
3. Manually verify: `migrator.verify_schema_consistency`
4. Update schema file if needed: `migrator.update_schema_file`

### 3. Database Consistency

The AppSchema.cr file represents the expected database state after migrations. Always ensure your database matches by running pending migrations before using the schema file.

### 4. Rollback Considerations

When rolling back migrations:

- The schema file is automatically updated to reflect the rollback
- Ensure your application code is compatible with the rolled-back schema
- Test rollbacks in development before applying to production

## Example: Complete Workflow

Here's a complete example of the integrated workflow:

```crystal
# 1. Define your base schema connection
AppDB = CQL::Schema.define(
  :app_database,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do
  # Minimal definition - tables managed by migrations
end

# 2. Configure the migrator
config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  schema_symbol: :app_schema
)

# 3. Initialize migrator
migrator = AppDB.migrator(config)

# 4. Bootstrap from existing database (first time only)
# migrator.bootstrap_schema

# 5. Create and run migrations
migrator.up

# 6. Verify everything is in sync
if migrator.verify_schema_consistency
  puts "✅ Database and schema file are in sync"
else
  puts "❌ Schema inconsistency detected"
  puts "Run: migrator.update_schema_file"
end

# 7. Use the generated schema in your application
require "./src/schemas/app_schema"

# Now AppSchema reflects the current database state
users = AppSchema.query.from(:users).all
```

This integrated approach ensures that your schema file always represents the true state of your database, making it easier to manage schema changes across development, testing, and production environments.
