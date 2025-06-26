require "sqlite3"
require "../../src/cql"
require "../../src/performance"

# Configure CQL immediately after requiring it
puts "🚀 CQL Blog Application Demo"
puts "=" * 40

puts "\n📋 Configuration"

CQL.configure do |config|
  config.database_url = "sqlite3://examples/blog/blog.db"
  config.logger = Log.for("cql.*")
  config.environment = "development"
  config.sqlite.journal_mode = "wal"
  config.sqlite.foreign_keys = true
  config.migration_table_name = :cql_schema_migrations
  config.schema_path = "./examples/blog/schemas"
  config.schema_file_name = "app_schema.cr"
  config.schema_constant_name = :BlogDB
  config.schema_symbol = :app_schema
  config.auto_load_models = true
  config.enable_auto_schema_sync = true
  config.bootstrap_on_startup = true
  config.verify_schema_on_startup = true
  config.enable_performance_monitoring = true
end

puts "✅ Configuration complete"
puts "  Database: #{CQL.config.database_url}"

module BlogDemo
  def self.run
    run_migrations
    seed_data = BlogDemo::Seeders.seed_data

    sleep 1.second
    CQL::Performance.monitor.generate_comprehensive_report("logger")
    sleep 1.second
    BlogDemo::Demos.crud_operations(seed_data)

    BlogDemo::Demos.complex_queries(BlogDB)
    BlogDemo::Demos.relationships(seed_data)
    BlogDemo::Demos.performance_features
    BlogDemo::Demos.statistics_and_reporting(BlogDB)

    puts "\n🎉 Demo Complete!"

    total_records = User.count + Category.count + Post.count + Comment.count
    puts "\nSummary:"
    puts "  Total records created: #{total_records}"
    puts "  Database file: examples/blog/blog_demo.db"

    puts "\n🚀 CQL Features Demonstrated:"
    puts "  ✅ Configuration management"
    puts "  ✅ Schema definition with relationships"
    puts "  ✅ Database migrations"
    puts "  ✅ Active Record models"
    puts "  ✅ CRUD operations"
    puts "  ✅ Complex queries and joins"
    puts "  ✅ Aggregations and statistics"
    puts "  ✅ Relationship navigation"
    puts "  ✅ Performance optimizations"
    puts "  ✅ Raw SQL capabilities"
    puts "  ✅ Performance monitoring and reporting"

    puts "\n📊 Performance Monitoring Features:"
    puts "  ✅ Real-time query performance tracking"
    puts "  ✅ N+1 query detection"
    puts "  ✅ Slow query identification"
    puts "  ✅ Beautiful developer-friendly reports"
    puts "  ✅ Performance recommendations"
    puts "  ✅ Query pattern analysis"

    puts "\n💡 This demonstrates CQL as a production-ready ORM with advanced performance monitoring!"
    puts "=" * 40
  end

  def self.run_migrations
    puts "\n📝 Step 1: Running Migrations"
    migrator = CQL.config.create_migrator(BlogDB)
    migrator.up
    puts "✅ Migrations applied successfully"
  end
end

# Require all demo components AFTER configuration
require "./schemas/*"
require "./migrations/*"
require "./seeders"
require "./models/*"
require "./demos/*"
# Run the demo
BlogDemo.run
