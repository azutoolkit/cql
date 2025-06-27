#!/usr/bin/env crystal

# Example: Integrated Schema Migration Workflow with CQL
#
# This example demonstrates how to use CQL's integrated migration system
# with automatic schema synchronization to maintain an up-to-date AppSchema.cr file.

require "sqlite3"
require "../../src/cql"

# Step 1: Define Base Schema Connection
# This is your main schema connection - tables will be managed by migrations
AppDB = CQL::Schema.define(
  :app_database,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://examples/app_example.db"
) do
  # Minimal initial structure - will be populated by migrations
  # The migrator will ensure this stays in sync with the database
end

# Step 2: Configure Migration System
config = CQL::MigratorConfig.new(
  schema_file_path: "examples/generated_app_schema.cr",
  schema_name: :GeneratedAppSchema,
  schema_symbol: :generated_app_schema,
  auto_sync: true # Automatically update schema file after migrations
)

migrator = AppDB.migrator(config)

# Step 3: Define Migrations
# Migration 1: Create initial users table
class CreateUsersTable < CQL::Migration(1)
  def up
    puts "📄 Migration 1: Creating users table..."

    # Note: Since this is the first migration, we need to create the table
    # In the base schema, then alter it
    schema.table :users do
      primary :id, Int32
      column :name, String
      column :email, String
      timestamps
    end

    # Create the table in the database
    schema.users.create!
  end

  def down
    puts "📄 Migration 1 (rollback): Dropping users table..."
    schema.users.drop!
  end
end

# Migration 2: Add email index
class AddEmailIndex < CQL::Migration(2)
  def up
    puts "📄 Migration 2: Adding email index..."
    schema.alter :users do
      create_index :email_idx, [:email], unique: true
    end
  end

  def down
    puts "📄 Migration 2 (rollback): Dropping email index..."
    schema.alter :users do
      drop_index :email_idx
    end
  end
end

# Migration 3: Create posts table with foreign key
class CreatePostsTable < CQL::Migration(3)
  def up
    puts "📄 Migration 3: Creating posts table..."

    schema.table :posts do
      primary :id, Int32
      column :title, String
      column :content, String
      column :user_id, Int32
      timestamps

      # Include foreign key constraint during table creation (SQLite compatible)
      foreign_key [:user_id], references: :users, references_columns: [:id]
    end

    schema.posts.create!
  end

  def down
    puts "📄 Migration 3 (rollback): Dropping posts table..."
    schema.posts.drop!
  end
end

# Migration 4: Add published column to posts
class AddPublishedToPosts < CQL::Migration(4)
  def up
    puts "📄 Migration 4: Adding published column to posts..."
    schema.alter :posts do
      add_column :published, Bool, default: false
    end
  end

  def down
    puts "📄 Migration 4 (rollback): Removing published column from posts..."
    schema.alter :posts do
      drop_column :published
    end
  end
end

# Step 4: Demonstration Workflow
def demonstrate_workflow(migrator : CQL::Migrator)
  puts "🚀 CQL Schema Migration Workflow Demonstration"
  puts "=" * 50

  # Initialize fresh database
  File.delete("examples/app_example.db") if File.exists?("examples/app_example.db")
  File.delete("examples/generated_app_schema.cr") if File.exists?("examples/generated_app_schema.cr")

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

  puts "\n⬇️  Rolling back last migration..."
  migrator.rollback

  puts "\n📊 Migration Status After Rollback:"
  puts "Applied migrations:"
  migrator.applied_migrations.each do |migration|
    puts "  ✔ #{migration.name} (version #{migration.version})"
  end

  puts "\n📁 Schema File After Rollback:"
  if File.exists?("examples/generated_app_schema.cr")
    schema_content = File.read("examples/generated_app_schema.cr")
    puts "Notice how the 'published' column has been removed:"
    puts "-" * 40
    puts schema_content
    puts "-" * 40
  end

  puts "\n↩️  Redoing last migration..."
  migrator.redo

  puts "\n📊 Final Migration Status:"
  puts "Applied migrations:"
  migrator.applied_migrations.each do |migration|
    puts "  ✔ #{migration.name} (version #{migration.version})"
  end

  puts "\n✅ Final Schema Consistency Check:"
  consistent = migrator.verify_schema_consistency
  puts "Schema is consistent with database: #{consistent}"

  puts "\n🎯 Manual Schema Update Example:"
  puts "You can also manually update the schema file:"
  migrator.update_schema_file
  puts "Schema file manually updated!"

  puts "\n🏁 Workflow Complete!"
  puts "=" * 50
  puts "The AppSchema.cr file now reflects the exact current state of the database."
  puts "This file can be used in your application to ensure type-safety and consistency."
end

# Step 5: Practical Usage Example
def demonstrate_usage
  puts "\n🔧 Practical Usage Example:"
  puts "=" * 30

  # Load the generated schema
  if File.exists?("examples/generated_app_schema.cr")
    # In a real application, you would require the schema file
    puts "In your application, you would:"
    puts "require \"./examples/generated_app_schema\""
    puts ""
    puts "Then use it like:"
    puts "users = GeneratedAppSchema.query.from(:users).all"
    puts "posts = GeneratedAppSchema.query.from(:posts).where(published: true).all"
  end
end

# Step 6: Team Workflow Example
def demonstrate_team_scenarios
  puts "\n👥 Team Workflow Scenarios:"
  puts "=" * 30

  puts "\n🔄 Scenario 1: New Team Member Setup"
  puts "1. Clone repository"
  puts "2. Run: migrator.up  # Applies all migrations and generates schema"
  puts "3. Schema file is automatically created and ready to use"

  puts "\n🔀 Scenario 2: Resolving Schema Conflicts"
  puts "1. git pull origin main"
  puts "2. migrator.up  # Apply any new migrations"
  puts "3. migrator.update_schema_file  # Regenerate schema file"
  puts "4. git add examples/generated_app_schema.cr && git commit"

  puts "\n🚀 Scenario 3: Production Deployment"
  puts "1. Set auto_sync: false in production config"
  puts "2. migrator.up  # Apply migrations"
  puts "3. migrator.verify_schema_consistency  # Verify everything is correct"
  puts "4. Deploy application with updated schema file"
end

# Step 7: Configuration Examples
def demonstrate_configurations
  puts "\n⚙️  Configuration Examples:"
  puts "=" * 25

  puts "\n🔧 Development Config:"
  dev_config = CQL::MigratorConfig.new(
    schema_file_path: "src/schemas/app_schema.cr",
    schema_name: :AppSchema,
    schema_symbol: :app_schema,
    auto_sync: true
  )
  puts "auto_sync: true (automatic updates)"
  puts "schema_file_path: #{dev_config.schema_file_path}"

  puts "\n🏭 Production Config:"
  prod_config = CQL::MigratorConfig.new(
    schema_file_path: "src/schemas/production_schema.cr",
    schema_name: :ProductionSchema,
    schema_symbol: :production_schema,
    auto_sync: false # Manual control in production
  )
  puts "auto_sync: false (manual control)"
  puts "schema_file_path: #{prod_config.schema_file_path}"

  puts "\n🧪 Test Config:"
  test_config = CQL::MigratorConfig.new(
    schema_file_path: "src/schemas/test_schema.cr",
    schema_name: :TestSchema,
    schema_symbol: :test_schema,
    auto_sync: true
  )
  puts "auto_sync: true (automatic updates for testing)"
  puts "schema_file_path: #{test_config.schema_file_path}"
end

# Run the complete demonstration
begin
  demonstrate_workflow(migrator)
  demonstrate_usage
  demonstrate_team_scenarios
  demonstrate_configurations

  puts "\n✨ Integration Benefits:"
  puts "=" * 20
  puts "✅ Always up-to-date schema files"
  puts "✅ No manual schema maintenance"
  puts "✅ Type-safe database interactions"
  puts "✅ Team synchronization made easy"
  puts "✅ Production-ready deployment process"
  puts "✅ Rollback safety with schema consistency"
rescue ex : Exception
  puts "❌ Error occurred: #{ex.message}"
  puts ex.backtrace.join("\n")
ensure
  # Cleanup
  puts "\n🧹 Cleaning up example files..."
  File.delete("examples/app_example.db") if File.exists?("examples/app_example.db")
  File.delete("examples/generated_app_schema.cr") if File.exists?("examples/generated_app_schema.cr")
  puts "Cleanup complete!"
end
