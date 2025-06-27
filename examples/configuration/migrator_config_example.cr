require "sqlite3"
require "../../src/cql"

# 🗂️ Migrator Configuration Example - Updated for New API
# Demonstrating the new developer-friendly configuration syntax

puts "=== 🗂️ CQL Migrator Configuration Example ==="

# Basic migrator configuration with new syntax
CQL.configure do |config|
  config.db = "sqlite3://examples/migrator_demo.db"
  config.schema_dir = "examples"
  config.schema_file = "demo_schema.cr"
  config.schema_class = :DemoSchema
  config.auto_sync = true
end

puts "✅ Basic migrator configuration applied"
puts "Database: #{CQL.config.db}"
puts "Schema direcbtory: #{CQL.config.schema_dir}"
puts "Schema file: #{CQL.config.schema_file}"
puts "Schema class: #{CQL.config.schema_class}"
puts "Auto-sync enabled: #{CQL.config.auto_sync?}"

# Create and demonstrate migrator usage
puts "\n=== 🔧 Migrator Usage Example ==="

# Schema definition (simulated)
puts "Creating demo schema..."

# Environment-specific configuration
puts "\n=== 🌍 Environment-Specific Configuration ==="

environments = [
  {env: "development", auto_sync: true},
  {env: "test", auto_sync: true},
  {env: "production", auto_sync: false},
]

environments.each do |env_config|
  puts "\n--- #{env_config[:env].capitalize} Environment ---"

  CQL.configure do |config|
    config.db = "sqlite3://examples/#{env_config[:env]}_demo.db"
    config.env = env_config[:env]
    config.schema_dir = "examples"
    config.auto_sync = env_config[:auto_sync]
  end

  puts "  Database: #{CQL.config.db}"
  puts "  Environment: #{CQL.config.env}"
  puts "  Auto-sync: #{CQL.config.auto_sync?}"
end

# Advanced migrator configuration
puts "\n=== ⚙️ Advanced Configuration ==="

CQL.configure do |config|
  config.db = "sqlite3://examples/workflow_demo.db"
  config.schema_dir = "examples"
  config.auto_sync = true
  config.verify_schema = true
  config.bootstrap = false
  config.migrations_table = :demo_migrations
end

puts "Advanced configuration applied:"
puts "  Verify schema on startup: #{CQL.config.verify_schema?}"
puts "  Bootstrap on startup: #{CQL.config.bootstrap?}"
puts "  Migrations table: #{CQL.config.migrations_table}"

# Create migrator configurations
puts "\n=== 🏗️ Migrator Config Creation ==="

# Basic migrator config
basic_config = CQL.migrator_config
puts "Basic config created with:"
puts "  Schema path: #{basic_config.schema_file_path}"
puts "  Schema name: #{basic_config.schema_name}"
puts "  Migration table: #{basic_config.migration_table_name}"
puts "  Auto-sync: #{basic_config.auto_sync?}"

# Environment-specific migrator configs
["development", "test", "production"].each do |env|
  puts "\n--- #{env.capitalize} Migrator Config ---"
  env_config = CQL.migrator_config_for(env)
  puts "  Schema path: #{env_config.schema_file_path}"
  puts "  Schema name: #{env_config.schema_name}"
  puts "  Auto-sync: #{env_config.auto_sync?}"
end

puts "\n✅ Migrator configuration example completed!"

# Cleanup
begin
  File.delete("examples/migrator_demo.db") if File.exists?("examples/migrator_demo.db")
  File.delete("examples/workflow_demo.db") if File.exists?("examples/workflow_demo.db")
rescue
  # Ignore cleanup errors
end
