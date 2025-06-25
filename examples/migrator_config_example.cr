require "sqlite3"
require "../src/cql"

# Example: MigratorConfig Integration with CQL Configuration
puts "🔧 MigratorConfig Integration Example"
puts "=" * 40

# Example 1: Basic MigratorConfig from Configuration
puts "\n📋 Example 1: Basic MigratorConfig Creation"
puts "-" * 35

CQL.configure do |config|
  config.database_url = "sqlite3://examples/migrator_demo.db"
  config.schema_path = "examples"
  config.schema_file_name = "demo_schema.cr"
  config.schema_constant_name = :DemoSchema
  config.enable_auto_schema_sync = true
end

# Create MigratorConfig using configuration
migrator_config = CQL.create_migrator_config
puts "Default MigratorConfig:"
puts "  Schema file: #{migrator_config.schema_file_path}"
puts "  Schema name: #{migrator_config.schema_name}"
puts "  Schema symbol: #{migrator_config.schema_symbol}"
puts "  Auto sync: #{migrator_config.auto_sync?}"

# Example 2: MigratorConfig with Custom Overrides
puts "\n🎛️  Example 2: Custom MigratorConfig Overrides"
puts "-" * 40

custom_config = CQL.create_migrator_config(
  schema_file_path: "examples/custom_schema.cr",
  schema_name: :CustomSchema,
  auto_sync: false
)

puts "Custom MigratorConfig:"
puts "  Schema file: #{custom_config.schema_file_path}"
puts "  Schema name: #{custom_config.schema_name}"
puts "  Schema symbol: #{custom_config.schema_symbol}"
puts "  Auto sync: #{custom_config.auto_sync?}"

# Example 3: Environment-Specific MigratorConfig
puts "\n🌍 Example 3: Environment-Specific MigratorConfig"
puts "-" * 45

# Development config
dev_config = CQL.create_migrator_config_for_environment("development")
puts "Development MigratorConfig:"
puts "  Schema file: #{dev_config.schema_file_path}"
puts "  Schema name: #{dev_config.schema_name}"
puts "  Auto sync: #{dev_config.auto_sync?}"

# Test config
test_config = CQL.create_migrator_config_for_environment("test")
puts "\nTest MigratorConfig:"
puts "  Schema file: #{test_config.schema_file_path}"
puts "  Schema name: #{test_config.schema_name}"
puts "  Auto sync: #{test_config.auto_sync?}"

# Production config
prod_config = CQL.create_migrator_config_for_environment("production")
puts "\nProduction MigratorConfig:"
puts "  Schema file: #{prod_config.schema_file_path}"
puts "  Schema name: #{prod_config.schema_name}"
puts "  Auto sync: #{prod_config.auto_sync?}"

# Example 4: Using MigratorConfig with Schema
puts "\n🏗️  Example 4: Using MigratorConfig with Schema"
puts "-" * 40

# Create schema
DemoSchema = CQL.create_schema(:demo_schema) do
  # Empty schema - will be managed by migrations
end

# Create migrator using default config
migrator1 = CQL.create_migrator(DemoSchema)
puts "Default migrator config: #{migrator1.config.schema_file_path}"

# Create migrator using custom config
migrator2 = CQL.create_migrator(DemoSchema, custom_config)
puts "Custom migrator config: #{migrator2.config.schema_file_path}"

# Example 5: ConfigHelpers for MigratorConfig
puts "\n🛠️  Example 5: ConfigHelpers for MigratorConfig"
puts "-" * 40

# Using helpers
helper_config = CQL::ConfigHelpers.create_migrator_config
puts "Helper MigratorConfig:"
puts "  Schema file: #{helper_config.schema_file_path}"
puts "  Auto sync: #{helper_config.auto_sync?}"

# Using helpers with overrides
helper_custom = CQL::ConfigHelpers.create_migrator_config(
  schema_name: :HelperSchema,
  auto_sync: false
)
puts "\nHelper Custom MigratorConfig:"
puts "  Schema name: #{helper_custom.schema_name}"
puts "  Auto sync: #{helper_custom.auto_sync?}"

# Using environment-specific helper
helper_prod = CQL::ConfigHelpers.create_migrator_config_for_environment("production")
puts "\nHelper Production MigratorConfig:"
puts "  Schema file: #{helper_prod.schema_file_path}"
puts "  Schema name: #{helper_prod.schema_name}"

# Example 6: Complete Workflow with MigratorConfig
puts "\n🔄 Example 6: Complete Workflow"
puts "-" * 25

# Configure for a specific workflow
CQL.configure do |config|
  config.environment = "development"
  config.database_url = "sqlite3://examples/workflow_demo.db"
  config.schema_path = "examples"
  config.enable_auto_schema_sync = true
end

# Create workflow-specific config
workflow_config = CQL.create_migrator_config(
  schema_file_path: "examples/workflow_schema.cr",
  schema_name: :WorkflowSchema
)

# Create schema and migrator
WorkflowSchema = CQL.create_schema(:workflow_schema) do
  # Migrations will define tables
end

workflow_migrator = CQL.create_migrator(WorkflowSchema, workflow_config)

puts "Workflow complete:"
puts "  Schema: #{WorkflowSchema.name}"
puts "  Migrator config: #{workflow_migrator.config.schema_name}"
puts "  Auto sync enabled: #{workflow_migrator.config.auto_sync?}"

puts "\n✅ MigratorConfig Integration Examples Complete!"
puts "\n📋 Summary of Available Methods:"
puts "  • CQL.create_migrator_config"
puts "  • CQL.create_migrator_config(overrides...)"
puts "  • CQL.create_migrator_config_for_environment(env)"
puts "  • CQL.create_migrator(schema, config)"
puts "  • CQL::ConfigHelpers.create_migrator_config"
puts "  • CQL::ConfigHelpers.create_migrator_config(overrides...)"
puts "  • CQL::ConfigHelpers.create_migrator_config_for_environment(env)"

# Cleanup
begin
  File.delete("examples/migrator_demo.db") if File.exists?("examples/migrator_demo.db")
  File.delete("examples/workflow_demo.db") if File.exists?("examples/workflow_demo.db")
rescue
  # Ignore cleanup errors
end
