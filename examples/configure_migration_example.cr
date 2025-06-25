require "sqlite3"
require "../src/cql"

# Example: Integrated CQL Configuration with Migration Workflow
#
# This example demonstrates how to use the CQL::Configure module
# with the migration system for automatic schema generation and synchronization

puts "🚀 CQL Configuration + Migration Workflow Integration Example"
puts "=" * 60

# Example 1: Basic Configuration with Migration Settings
puts "\n📋 Example 1: Environment-Aware Configuration"
puts "-" * 40

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

puts "Environment: #{CQL.config.environment}"
puts "Schema file path: #{CQL.config.schema_file_path}"
puts "Auto sync enabled: #{CQL.config.enable_auto_schema_sync?}"
puts "Migration table: #{CQL.config.migration_table_name}"

# Example 2: Creating Schema with Integrated Configuration
puts "\n🏗️  Example 2: Schema Creation with Configuration"
puts "-" * 45

# Create schema using configuration
AppDB = CQL.create_schema(:app_db) do
  # Initial minimal schema - will be managed by migrations
end

puts "Database adapter: #{AppDB.adapter}"
puts "Database URI: #{AppDB.uri}"
puts "Schema name: #{AppDB.name}"

# Example 3: Define Migrations
puts "\n📝 Example 3: Defining Migrations"
puts "-" * 30

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

# Migration 2: Add index to users
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

# Migration 3: Create posts table
class CreatePosts < CQL::Migration(3)
  def up
    puts "  📄 Creating posts table..."
    schema.table :posts do
      primary :id, Int32
      column :title, String, null: false
      column :content, String
      column :user_id, Int32, null: false
      column :published, Bool, default: false
      timestamps
    end
    schema.posts.create!

    # Add foreign key
    schema.alter :posts do
      foreign_key [:user_id], references: :users, references_columns: [:id]
    end
  end

  def down
    puts "  📄 Dropping posts table..."
    schema.posts.drop!
  end
end

# Example 4: Migration Execution with Auto Schema Sync
puts "\n⚡ Example 4: Running Migrations with Auto Schema Sync"
puts "-" * 50

# Create migrator using configuration
migrator = CQL.create_migrator(AppDB)

puts "Migrator configuration:"
puts "  Schema file: #{migrator.config.schema_file_path}"
puts "  Schema name: #{migrator.config.schema_name}"
puts "  Auto sync: #{migrator.config.auto_sync?}"

# Check initial state
pending = migrator.pending_migrations
puts "\nPending migrations: #{pending.size}"
pending.each { |migration| puts "  - #{migration.name} (v#{migration.version})" }

# Run migrations - schema file will be automatically generated/updated
puts "\n🔄 Running migrations..."
migrator.up

# Check what was applied
applied = migrator.applied_migrations
puts "\nApplied migrations: #{applied.size}"
applied.each { |migration| puts "  ✅ #{migration.name} (v#{migration.version})" }

# Check if schema file was created
schema_file = CQL.config.schema_file_path
if File.exists?(schema_file)
  puts "\n📄 Schema file created: #{schema_file}"
  puts "First few lines:"
  File.read(schema_file).lines[0..5].each_with_index do |line, i|
    puts "  #{i + 1}: #{line}"
  end
else
  puts "\n❌ Schema file not created"
end

# Example 5: Schema Verification
puts "\n🔍 Example 5: Schema Verification"
puts "-" * 30

consistent = CQL.verify_schema(AppDB)
puts "Schema consistency check: #{consistent ? "✅ PASSED" : "❌ FAILED"}"

# Example 6: Environment-Specific Migration Configurations
puts "\n🌍 Example 6: Environment-Specific Configurations"
puts "-" * 45

# Development configuration
puts "\n🔧 Development Configuration:"
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
puts "\n🧪 Test Configuration:"
CQL.configure do |config|
  config.environment = "test"
  # Environment defaults automatically applied
end

test_migrator_config = CQL.config.create_migrator_config
puts "  Schema file: #{test_migrator_config.schema_file_path}"
puts "  Schema name: #{test_migrator_config.schema_name}"

# Production configuration
puts "\n🏭 Production Configuration:"
CQL.configure do |config|
  config.environment = "production"
  # Environment defaults automatically applied
end

prod_migrator_config = CQL.config.create_migrator_config
puts "  Auto sync: #{prod_migrator_config.auto_sync?}"
puts "  Verify on startup: #{CQL.config.verify_schema_on_startup?}"

# Example 7: Migration Rollback with Schema Sync
puts "\n↩️  Example 7: Migration Rollback with Schema Sync"
puts "-" * 45

# Reset to development config for rollback test
CQL.configure do |config|
  config.environment = "development"
  config.schema_file_name = "generated_schema.cr"
  config.enable_auto_schema_sync = true
end

migrator = CQL.create_migrator(AppDB)

puts "Rolling back last migration..."
migrator.down(1)

# Check updated state
last_migration = migrator.last
puts "Last applied migration: #{last_migration ? "#{last_migration.name} (v#{last_migration.version})" : "None"}"

puts "Re-applying migration..."
migrator.up

# Example 8: Using Generated Schema in Models
puts "\n🎯 Example 8: Using Generated Schema in Models"
puts "-" * 40

if File.exists?(CQL.config.schema_file_path)
  puts "Generated schema can now be used in Active Record models:"
  puts
  puts "```crystal"
  puts "require \"./#{CQL.config.schema_file_path}\""
  puts
  puts "class User"
  puts "  include CQL::ActiveRecord::Model(Int32)"
  puts "  db_context #{CQL.config.schema_constant_name}, :users"
  puts "  "
  puts "  property id : Int32?"
  puts "  property name : String"
  puts "  property email : String"
  puts "  property created_at : Time?"
  puts "  property updated_at : Time?"
  puts "end"
  puts "```"
else
  puts "❌ Schema file not generated"
end

# Example 9: Configuration Helpers
puts "\n🛠️  Example 9: Using Configuration Helpers"
puts "-" * 35

puts "Schema file path: #{CQL::ConfigHelpers.schema_file_path}"
puts "Schema path: #{CQL::ConfigHelpers.schema_path}"
puts "Auto sync enabled: #{CQL::ConfigHelpers.auto_schema_sync?}"
puts "Environment: #{CQL::ConfigHelpers.environment}"

# Create migrator config using helper
helper_config = CQL::ConfigHelpers.create_migrator_config
puts "Helper-created config auto_sync: #{helper_config.auto_sync?}"

# Example 10: Complete Workflow Summary
puts "\n📋 Example 10: Complete Workflow Summary"
puts "-" * 35

puts
puts "✅ Complete CQL Configuration + Migration Workflow:"
puts "   1. Configure CQL with migration settings"
puts "   2. Create schema using CQL.create_schema"
puts "   3. Define migrations as CQL::Migration subclasses"
puts "   4. Create migrator using CQL.create_migrator"
puts "   5. Run migrations with automatic schema file sync"
puts "   6. Use generated schema file in Active Record models"
puts "   7. Verify schema consistency with CQL.verify_schema"
puts
puts "🎯 Benefits:"
puts "   • Centralized configuration for all database settings"
puts "   • Automatic schema file generation and synchronization"
puts "   • Environment-aware migration behavior"
puts "   • Type-safe database interactions"
puts "   • Team synchronization made easy"
puts "   • Production-ready deployment process"

# Cleanup
puts "\n🧹 Cleaning up example files..."
begin
  File.delete("examples/migration_example.db") if File.exists?("examples/migration_example.db")
  File.delete("examples/generated_schema.cr") if File.exists?("examples/generated_schema.cr")
  puts "Cleanup complete!"
rescue ex
  puts "Cleanup error (non-critical): #{ex.message}"
end

puts "\n✨ Configuration + Migration Integration Example Complete!"
