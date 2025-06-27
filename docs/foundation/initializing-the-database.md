# Database Initialization

## What Does "Database Initialization" Actually Mean?

Database initialization is like setting up the foundation of a house before you start building. It's the process of creating the basic database structure that your application needs to store and retrieve data. But here's where CQL differs from traditional approaches - it's not just about creating tables, it's about setting up a **system that evolves with your application**.

### The Old Way vs. The CQL Way

```crystal
# Traditional approach: Define everything upfront
# (What if you need to change something later? 😰)
MyDB = CQL::Schema.define(:my_db, ...) do
  table :users do
    primary :id, Int32
    text :name
    text :email
    # Hope you got everything right the first time!
  end
end

# CQL's approach: Start simple, evolve through migrations
# (Changes are tracked, reversible, and shareable! 🎉)
MyDB = CQL::Schema.define(:my_db, ...) do
  # Empty! We'll build this step by step through migrations
end
# Your AppSchema.cr file grows automatically as you add features
```

**Why this matters:**

* **Flexibility**: Add features without breaking existing code
* **Collaboration**: Team members get the same database structure
* **Safety**: Every change is reversible and trackable
* **Type Safety**: Your Crystal code always knows the current database structure

### Three Scenarios, Three Approaches

CQL handles three common scenarios you'll encounter as a developer:

1. **Starting fresh** → Migration-based approach (recommended)
2. **Existing database** → Bootstrap then migrate
3. **Simple/experimental** → Direct schema definition

***

## Database Initialization Approaches

### 1. New Database with Migration-Based Schema (Recommended)

For new projects, the modern approach uses migrations to build your database schema incrementally while maintaining an automatically synchronized AppSchema.cr file:

```crystal
# 1. Define your base schema connection
AppDB = CQL::Schema.define(
  :app_database,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do
  # Empty - tables will be managed by migrations
end

# 2. Configure the migrator for automatic schema synchronization
config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  schema_symbol: :app_schema,
  auto_sync: true
)

# 3. Initialize the base database structure
AppDB.init

# 4. Create and run initial migrations
migrator = AppDB.migrator(config)
migrator.up  # This will also create/update AppSchema.cr automatically
```

### 2. Existing Database with Schema Bootstrap

If you have an existing database and want to adopt the migration workflow:

```crystal
# 1. Define a minimal schema connection
AppDB = CQL::Schema.define(
  :app_database,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do
  # Will be populated by bootstrap process
end

# 2. Configure the migrator
config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  auto_sync: true
)

# 3. Bootstrap the schema file from existing database
migrator = AppDB.migrator(config)
migrator.bootstrap_schema

# This creates src/schemas/app_schema.cr with your current database structure:
# AppSchema = CQL::Schema.define(:app_schema, adapter: CQL::Adapter::Postgres, uri: ENV["DATABASE_URL"]) do
#   table :users do
#     primary :id, Int32
#     text :name
#     text :email
#     # ... existing columns
#   end
#   # ... existing tables
# end
```

### 3. Traditional Direct Schema Definition

For simple applications or development environments where you want direct control:

```crystal
# Define your complete schema upfront
AcmeDB = CQL::Schema.define(
  :acme_db,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do
  table :movies do
    primary :id, Int64, auto_increment: true
    text :title
  end

  table :actors do
    primary :id, Int64, auto_increment: true
    text :name
  end

  table :movies_actors do
    primary :id, Int64, auto_increment: true
    bigint :movie_id
    bigint :actor_id

    foreign_key [:movie_id], references: :movies, references_columns: [:id]
    foreign_key [:actor_id], references: :actors, references_columns: [:id]
  end
end

# Initialize the database
AcmeDB.init
```

***

## Migration-Based Initialization Workflow

### Step 1: Create Initial Migrations

Instead of defining all tables in your schema, create migrations for each major component:

```crystal
# migrations/001_create_movies.cr
class CreateMovies < CQL::Migration(1)
  def up
    schema.table :movies do
      primary :id, Int64, auto_increment: true
      text :title, null: false
      text :description, null: true
      timestamp :created_at, null: true
      timestamp :updated_at, null: true
    end
  end

  def down
    schema.drop :movies
  end
end

# migrations/002_create_actors.cr
class CreateActors < CQL::Migration(2)
  def up
    schema.table :actors do
      primary :id, Int64, auto_increment: true
      text :name, null: false
      date :birth_date, null: true
      timestamp :created_at, null: true
      timestamp :updated_at, null: true
    end
  end

  def down
    schema.drop :actors
  end
end

# migrations/003_create_movies_actors.cr
class CreateMoviesActors < CQL::Migration(3)
  def up
    schema.table :movies_actors do
      primary :id, Int64, auto_increment: true
      bigint :movie_id, null: false
      bigint :actor_id, null: false
      timestamp :created_at, null: true

      foreign_key [:movie_id], references: :movies, references_columns: [:id], on_delete: "CASCADE"
      foreign_key [:actor_id], references: :actors, references_columns: [:id], on_delete: "CASCADE"
    end

    schema.alter :movies_actors do
      create_index :idx_movies_actors_movie_id, [:movie_id]
      create_index :idx_movies_actors_actor_id, [:actor_id]
      create_index :idx_movies_actors_unique, [:movie_id, :actor_id], unique: true
    end
  end

  def down
    schema.drop :movies_actors
  end
end
```

### Step 2: Initialize and Run Migrations

```crystal
# Initialize your database structure
AppDB = CQL::Schema.define(
  :app_database,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do
  # Tables will be created by migrations
end

# Configure migrator
config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  auto_sync: true
)

# Initialize base database
AppDB.init

# Run all migrations to build your schema
migrator = AppDB.migrator(config)
migrator.up

puts "✅ Database initialized with #{migrator.applied_migrations.size} migrations"
```

### Step 3: Verify Generated Schema

After running migrations, your AppSchema.cr file is automatically generated:

```crystal
# This is automatically created/updated in src/schemas/app_schema.cr
AppSchema = CQL::Schema.define(
  :app_schema,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do
  table :movies do
    primary :id, Int64, auto_increment: true
    text :title, null: false
    text :description, null: true
    timestamp :created_at, null: true
    timestamp :updated_at, null: true
  end

  table :actors do
    primary :id, Int64, auto_increment: true
    text :name, null: false
    date :birth_date, null: true
    timestamp :created_at, null: true
    timestamp :updated_at, null: true
  end

  table :movies_actors do
    primary :id, Int64, auto_increment: true
    bigint :movie_id, null: false
    bigint :actor_id, null: false
    timestamp :created_at, null: true

    foreign_key [:movie_id], references: :movies, references_columns: [:id], on_delete: "CASCADE"
    foreign_key [:actor_id], references: :actors, references_columns: [:id], on_delete: "CASCADE"
  end
end
```

***

## Environment-Specific Initialization

### Development Environment

```crystal
# config/development.cr
AppDB = CQL::Schema.define(
  :app_database,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"] || "postgres://localhost/myapp_development"
) do
  # Development tables managed by migrations
end

config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  auto_sync: true  # Auto-sync enabled for development
)

# Initialize and migrate
AppDB.init
migrator = AppDB.migrator(config)
migrator.up
```

### Test Environment

```crystal
# config/test.cr
TestDB = CQL::Schema.define(
  :test_database,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["TEST_DATABASE_URL"] || "postgres://localhost/myapp_test"
) do
  # Test tables managed by migrations
end

config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/test_schema.cr",
  schema_name: :TestSchema,
  auto_sync: true
)

# Initialize test database
TestDB.init
migrator = TestDB.migrator(config)
migrator.up
```

### Production Environment

```crystal
# config/production.cr
ProdDB = CQL::Schema.define(
  :production_database,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do
  # Production tables managed by migrations
end

config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/production_schema.cr",
  schema_name: :ProductionSchema,
  auto_sync: false  # Manual control in production
)

# Initialize (typically done once)
ProdDB.init

# Migrations run separately with manual verification
migrator = ProdDB.migrator(config)
# migrator.up
# migrator.verify_schema_consistency
```

***

## Complete Initialization Example

Here's a comprehensive example showing the full initialization workflow:

```crystal
require "cql"

# 1. Define your database connection
AppDB = CQL::Schema.define(
  :movie_database,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"] || "postgres://localhost/movies"
) do
  # Schema will be built through migrations
end

# 2. Configure migration management
config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/movie_schema.cr",
  schema_name: :MovieSchema,
  schema_symbol: :movie_schema,
  auto_sync: true
)

# 3. Initialize database infrastructure
puts "Initializing database..."
AppDB.init

# 4. Set up migrator and apply migrations
puts "Setting up migrations..."
migrator = AppDB.migrator(config)

# 5. Check if this is initial setup or existing database
if migrator.applied_migrations.empty?
  puts "Fresh database detected. Running initial migrations..."
  migrator.up
  puts "✅ Database initialized with #{migrator.applied_migrations.size} migrations"
else
  puts "Existing database detected. Checking for pending migrations..."
  pending = migrator.pending_migrations
  if pending.any?
    puts "Found #{pending.size} pending migrations. Applying..."
    migrator.up
    puts "✅ Applied #{pending.size} migrations"
  else
    puts "✅ Database is up to date"
  end
end

# 6. Verify schema consistency
if migrator.verify_schema_consistency
  puts "✅ Schema file is synchronized with database"
else
  puts "⚠️  Schema file out of sync. Updating..."
  migrator.update_schema_file
  puts "✅ Schema file updated"
end

# 7. Load the generated schema for use in your application
require "./src/schemas/movie_schema"

# Now you can use MovieSchema for Active Record models
puts "🎬 Movie database ready for use!"
```

***

## Database Setup Scripts

### Setup Script for New Projects

```crystal
# scripts/setup_database.cr
require "../src/config/database"

puts "🚀 Setting up database for the first time..."

# Initialize database
AppDB.init
puts "✅ Database structure initialized"

# Run migrations
migrator = AppDB.migrator(DATABASE_CONFIG)
migrator.up
puts "✅ Migrations applied: #{migrator.applied_migrations.size}"

# Verify setup
if migrator.verify_schema_consistency
  puts "✅ Schema file synchronized"
  puts "🎉 Database setup complete!"
else
  puts "❌ Schema synchronization failed"
  exit(1)
end
```

### Reset Script for Development

```crystal
# scripts/reset_database.cr
require "../src/config/database"

puts "🔄 Resetting development database..."

# Drop and recreate
AppDB.drop if AppDB.exists?
AppDB.init

# Re-run all migrations
migrator = AppDB.migrator(DATABASE_CONFIG)
migrator.up

puts "✅ Database reset complete with #{migrator.applied_migrations.size} migrations"
```

***

## Troubleshooting Database Initialization

### Common Issues and Solutions

#### 1. Schema File Out of Sync

```crystal
# Check consistency
migrator = AppDB.migrator(config)
unless migrator.verify_schema_consistency
  puts "Schema file is out of sync with database"

  # Option 1: Update schema file to match database
  migrator.update_schema_file

  # Option 2: Rebuild database to match schema file
  # AppDB.drop && AppDB.init && migrator.up
end
```

#### 2. Migration Conflicts

```crystal
# Check for conflicts before applying
pending = migrator.pending_migrations
if pending.size > 1
  puts "Multiple pending migrations detected:"
  pending.each { |m| puts "  - #{m.name}" }
  puts "Applying in order..."
end

migrator.up
```

#### 3. Database Connection Issues

```crystal
begin
  AppDB.init
rescue CQL::DatabaseConnectionError => e
  puts "Database connection failed: #{e.message}"
  puts "Check your DATABASE_URL environment variable"
  exit(1)
end
```

***

## Best Practices

### 1. Use Migrations for All Schema Changes

```crystal
# ✅ Good - Schema managed by migrations
AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::Postgres, uri: ENV["DATABASE_URL"]) do
  # Empty - let migrations handle schema
end

# ❌ Avoid - Direct schema definition for production apps
AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::Postgres, uri: ENV["DATABASE_URL"]) do
  table :users do
    # ... many tables defined here
  end
end
```

### 2. Environment-Specific Configurations

```crystal
database_config = case ENV["CRYSTAL_ENV"]?
when "production"
  CQL::MigratorConfig.new(auto_sync: false)  # Manual control
when "test"
  CQL::MigratorConfig.new(schema_file_path: "src/schemas/test_schema.cr")
else
  CQL::MigratorConfig.new(auto_sync: true)   # Development default
end
```

### 3. Initialization Scripts

Create scripts for common database operations:

```
scripts/
├── setup_database.cr    # Initial setup
├── reset_database.cr    # Development reset
├── migrate.cr          # Apply pending migrations
└── rollback.cr         # Rollback migrations
```

***

## Related Documentation

* [Migrations](migrations.md) - Complete migration system guide
* [Altering the Schema](altering-the-schema.md) - Schema modification operations
* [Schema Dump](../database-management/schema-dump.md) - Reverse engineering existing databases
* [Migration Workflow Guide](../active-record-with-cql/integrated-migration-workflow.md) - End-to-end examples

***

Database initialization in CQL provides flexible approaches for both new and existing databases. The migration-based approach ensures your database structure is version-controlled, maintainable, and automatically synchronized with your schema files, making it the recommended method for production applications.
