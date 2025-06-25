# CQL Configuration Guide

The CQL::Configure module provides a centralized, thread-safe way to configure all fundamental settings of the CQL library. This guide covers how to use the configuration system effectively in your Crystal applications.

## Table of Contents

- [Quick Start](#quick-start)
- [Configuration Options](#configuration-options)
- [Environment-Specific Configuration](#environment-specific-configuration)
- [Integration with Schema Definition](#integration-with-schema-definition)
- [Performance Monitoring Configuration](#performance-monitoring-configuration)
- [Configuration Helpers](#configuration-helpers)
- [Thread Safety](#thread-safety)
- [Validation](#validation)
- [Best Practices](#best-practices)
- [API Reference](#api-reference)

## Quick Start

### Basic Configuration

The simplest way to configure CQL is using the `CQL.configure` block:

```crystal
require "cql"

CQL.configure do |config|
  config.database_url = "postgresql://localhost/myapp_development"
  config.logger = Log.for("MyApp")
  config.default_timezone = :utc
  config.auto_load_models = true
end
```

### Accessing Configuration

After configuration, you can access settings throughout your application:

```crystal
# Direct access
puts CQL.config.database_url
puts CQL.config.pool_size

# Using helper methods
puts CQL::ConfigHelpers.database_url
puts CQL::ConfigHelpers.environment
```

## Configuration Options

### Core Database Settings

| Option               | Type         | Default                           | Description                       |
| -------------------- | ------------ | --------------------------------- | --------------------------------- |
| `database_url`       | `String`     | `"sqlite3://./db/development.db"` | Database connection URL           |
| `pool_size`          | `Int32`      | `10`                              | Connection pool size              |
| `checkout_timeout`   | `Time::Span` | `10.seconds`                      | Connection checkout timeout       |
| `query_timeout`      | `Time::Span` | `30.seconds`                      | Query execution timeout           |
| `max_retry_attempts` | `Int32`      | `3`                               | Maximum connection retry attempts |
| `retry_delay`        | `Time::Span` | `1.second`                        | Delay between retry attempts      |

### Application Settings

| Option             | Type     | Default                                 | Description                               |
| ------------------ | -------- | --------------------------------------- | ----------------------------------------- |
| `logger`           | `Log?`   | Environment-based                       | Logger instance for CQL operations        |
| `default_timezone` | `Symbol` | `:utc`                                  | Default timezone (`:utc` or `:local`)     |
| `environment`      | `String` | `ENV["CRYSTAL_ENV"]` or `"development"` | Application environment                   |
| `auto_load_models` | `Bool`   | `true`                                  | Whether to automatically load model files |

### Schema Management

| Option                 | Type     | Default                   | Description                        |
| ---------------------- | -------- | ------------------------- | ---------------------------------- |
| `migration_table_name` | `String` | `"cql_schema_migrations"` | Name of migration tracking table   |
| `schema_path`          | `String` | `"src/schemas"`           | Path where schema files are stored |

### Query Caching

| Option               | Type         | Default  | Description                 |
| -------------------- | ------------ | -------- | --------------------------- |
| `enable_query_cache` | `Bool`       | `false`  | Enable query result caching |
| `cache_ttl`          | `Time::Span` | `1.hour` | Default cache time-to-live  |

### Logging and Monitoring

| Option                          | Type                                   | Default                | Description                          |
| ------------------------------- | -------------------------------------- | ---------------------- | ------------------------------------ |
| `enable_sql_logging`            | `Bool`                                 | Environment-based      | Enable SQL query logging             |
| `sql_log_level`                 | `Log::Severity`                        | `Log::Severity::Debug` | Log level for SQL queries            |
| `enable_performance_monitoring` | `Bool`                                 | Environment-based      | Enable performance monitoring        |
| `performance_config`            | `CQL::Performance::PerformanceConfig?` | `nil`                  | Performance monitoring configuration |

### Migration and Schema Management

| Option                     | Type     | Default           | Description                                     |
| -------------------------- | -------- | ----------------- | ----------------------------------------------- |
| `enable_auto_schema_sync`  | `Bool`   | `true`            | Enable automatic schema file synchronization    |
| `schema_file_name`         | `String` | `"app_schema.cr"` | Default schema file name (without path)         |
| `schema_constant_name`     | `Symbol` | `:AppSchema`      | Schema constant name in generated file          |
| `schema_symbol`            | `Symbol` | `:app_schema`     | Schema symbol for internal use                  |
| `bootstrap_on_startup`     | `Bool`   | `false`           | Whether to bootstrap schema on first run        |
| `verify_schema_on_startup` | `Bool`   | `false`           | Whether to verify schema consistency on startup |

## Environment-Specific Configuration

CQL automatically applies environment-specific defaults based on the `CRYSTAL_ENV` environment variable:

### Development Environment

```crystal
CQL.configure do |config|
  config.environment = "development"
  config.database_url = "sqlite3://./db/development.db"
  config.enable_sql_logging = true
  config.enable_performance_monitoring = true
  config.pool_size = 5
  config.auto_load_models = true
end
```

### Test Environment

```crystal
CQL.configure do |config|
  config.environment = "test"
  config.database_url = "sqlite3://:memory:"
  config.migration_table_name = "test_schema_migrations"
  config.auto_load_models = false
  config.enable_sql_logging = false
  config.pool_size = 1
end
```

### Production Environment

```crystal
CQL.configure do |config|
  config.environment = "production"
  config.database_url = ENV["DATABASE_URL"]
  config.auto_load_models = false
  config.enable_sql_logging = false
  config.pool_size = 25
  config.checkout_timeout = 15.seconds
  config.max_retry_attempts = 5
end
```

### Custom Environment Configuration

```crystal
CQL.configure do |config|
  case ENV["CRYSTAL_ENV"]? || "development"
  when "production"
    config.database_url = ENV["DATABASE_URL"]
    config.logger = Log.for("Production")
    config.pool_size = 25
    config.enable_performance_monitoring = false
  when "staging"
    config.database_url = ENV["STAGING_DATABASE_URL"]
    config.logger = Log.for("Staging")
    config.pool_size = 15
    config.enable_performance_monitoring = true
  when "test"
    config.database_url = "sqlite3://:memory:"
    config.logger = Log.for("Test")
    config.pool_size = 1
  else # development
    config.database_url = "sqlite3://./db/development.db"
    config.logger = Log.for("Development")
    config.enable_sql_logging = true
    config.enable_performance_monitoring = true
  end
end
```

## Integration with Schema Definition

Use the configuration in your schema definitions:

```crystal
# Configure CQL first
CQL.configure do |config|
  config.database_url = "postgresql://localhost/myapp"
  config.pool_size = 15
end

# Then use configuration in schema
MyAppDB = CQL::Schema.define(
  :myapp_db,
  adapter: CQL.config.database_adapter,
  uri: CQL.config.database_url
) do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String, null: false
    column :email, String, null: false
    timestamps
  end
end
```

### Configuration-Aware Schema Setup

```crystal
module DatabaseSetup
  def self.create_schema
    CQL::Schema.define(
      :app_db,
      adapter: CQL.config.database_adapter,
      uri: CQL.config.database_url
    ) do
      # Load schema from configured path
      schema_file = File.join(CQL.config.schema_path, "app_schema.cr")

      if File.exists?(schema_file)
        # Include schema definitions from file
        instance_eval(File.read(schema_file))
      else
        # Define basic schema inline
        table :users do
          primary :id, Int64, auto_increment: true
          column :name, String
          column :email, String
          timestamps
        end
      end
    end
  end
end

AppDB = DatabaseSetup.create_schema
```

## Performance Monitoring Configuration

Configure performance monitoring through the main configuration:

```crystal
CQL.configure do |config|
  config.enable_performance_monitoring = true

  # Create detailed performance configuration
  perf_config = CQL::Performance::PerformanceConfig.new
  perf_config.query_profiling_enabled = true
  perf_config.n_plus_one_detection_enabled = true
  perf_config.plan_analysis_enabled = true
  perf_config.auto_analyze_slow_queries = true
  perf_config.context_tracking_enabled = true

  config.performance_config = perf_config
end

# Later, when creating your schema
schema = CQL::Schema.define(:app, adapter: CQL.config.database_adapter, uri: CQL.config.database_url)

# Automatically setup performance monitoring using configuration
CQL.config.setup_performance_monitoring(schema)
```

## Migration Workflow Integration

CQL's configuration system integrates seamlessly with the migration workflow to provide automatic schema generation and synchronization.

### Basic Migration Setup

```crystal
CQL.configure do |config|
  config.database_url = "postgresql://localhost/myapp"
  config.schema_path = "src/schemas"
  config.schema_file_name = "app_schema.cr"
  config.schema_constant_name = :AppSchema
  config.enable_auto_schema_sync = true
end

# Create schema using configuration
AppDB = CQL.create_schema(:app_db) do
  # Tables will be managed by migrations
end

# Create migrator using configuration
migrator = CQL.create_migrator(AppDB)

# Run migrations with automatic schema sync
migrator.up
```

### Environment-Specific Migration Settings

The configuration automatically applies environment-specific migration defaults:

```crystal
# Development: Auto-sync enabled, verification on startup
CQL.configure do |config|
  config.environment = "development"
  # Automatically sets:
  # config.enable_auto_schema_sync = true
  # config.verify_schema_on_startup = true
end

# Test: Separate schema file, auto-sync enabled
CQL.configure do |config|
  config.environment = "test"
  # Automatically sets:
  # config.schema_file_name = "test_schema.cr"
  # config.schema_constant_name = :TestSchema
  # config.schema_symbol = :test_schema
end

# Production: Manual control, verification only
CQL.configure do |config|
  config.environment = "production"
  # Automatically sets:
  # config.enable_auto_schema_sync = false
  # config.verify_schema_on_startup = true
end
```

### Migration Helper Methods

CQL provides helper methods for common migration operations:

```crystal
# Create schema with automatic migration support
schema = CQL.create_schema(:app_db) do
  # Schema definition
end

# Create migrator using centralized configuration
migrator = CQL.create_migrator(schema)

# Bootstrap schema from existing database
CQL.bootstrap_schema(schema)

# Verify and optionally fix schema consistency
consistent = CQL.verify_schema(schema, auto_fix: true)
```

### Complete Migration Workflow Example

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

## Configuration Helpers

CQL provides helper methods for commonly accessed configuration values:

```crystal
# Instead of CQL.config.database_url
database_url = CQL::ConfigHelpers.database_url

# Instead of CQL.config.effective_logger
logger = CQL::ConfigHelpers.logger

# Instead of CQL.config.timezone
timezone = CQL::ConfigHelpers.timezone

# Instead of CQL.config.environment
env = CQL::ConfigHelpers.environment

# Instead of CQL.config.auto_load_models?
auto_load = CQL::ConfigHelpers.auto_load_models?
```

## Thread Safety

The configuration system is fully thread-safe:

```crystal
# Multiple threads can safely access configuration
channel = Channel(String).new

10.times do |i|
  spawn do
    url = CQL.config.database_url
    logger = CQL.config.effective_logger
    channel.send("Thread #{i}: configured")
  end
end

# All threads will receive consistent configuration
10.times do
  puts channel.receive
end
```

### Configuration Initialization

Configuration is lazily initialized and cached:

```crystal
# First access initializes configuration with defaults
config1 = CQL.config

# Subsequent accesses return the same instance
config2 = CQL.config

puts config1.object_id == config2.object_id # => true
```

## Validation

Configuration settings are validated when the configuration block completes:

```crystal
begin
  CQL.configure do |config|
    config.database_url = ""      # Invalid: empty URL
    config.pool_size = -1         # Invalid: negative pool size
    config.default_timezone = :invalid # Invalid: unsupported timezone
  end
rescue ArgumentError => ex
  puts "Configuration error: #{ex.message}"
end
```

### Validation Rules

- `database_url` cannot be empty
- `schema_path` cannot be empty
- `migration_table_name` cannot be empty
- `pool_size` must be positive
- `max_retry_attempts` must be positive
- `default_timezone` must be `:utc` or `:local`

## Best Practices

### 1. Configure Early

Configure CQL before defining schemas or models:

```crystal
# ✅ Good: Configure first
CQL.configure do |config|
  config.database_url = "postgresql://localhost/myapp"
end

MyAppDB = CQL::Schema.define(:app, adapter: CQL.config.database_adapter, uri: CQL.config.database_url)

# ❌ Bad: Configure after schema definition
MyAppDB = CQL::Schema.define(:app, adapter: CQL::Adapter::Postgres, uri: "postgresql://localhost/myapp")

CQL.configure do |config|
  config.database_url = "postgresql://localhost/myapp"  # Won't affect already defined schema
end
```

### 2. Use Environment Variables

```crystal
CQL.configure do |config|
  config.database_url = ENV["DATABASE_URL"]? || "sqlite3://./db/development.db"
  config.pool_size = ENV["DB_POOL_SIZE"]?.try(&.to_i) || 10
  config.enable_sql_logging = ENV["SQL_LOGGING"]? == "true"
end
```

### 3. Separate Configuration by Environment

```crystal
# config/database.cr
case ENV["CRYSTAL_ENV"]? || "development"
when "production"
  require "./production"
when "test"
  require "./test"
else
  require "./development"
end

# config/production.cr
CQL.configure do |config|
  config.database_url = ENV["DATABASE_URL"]
  config.pool_size = 25
  config.auto_load_models = false
  config.enable_performance_monitoring = false
end

# config/development.cr
CQL.configure do |config|
  config.database_url = "sqlite3://./db/development.db"
  config.enable_sql_logging = true
  config.enable_performance_monitoring = true
end
```

### 4. Reset Configuration in Tests

```crystal
# spec/spec_helper.cr
Spec.before_each do
  CQL.reset_config!

  CQL.configure do |config|
    config.database_url = "sqlite3://:memory:"
    config.migration_table_name = "test_schema_migrations"
    config.auto_load_models = false
  end
end
```

### 5. Use Configuration Validation

```crystal
def validate_production_config
  config = CQL.config

  raise "DATABASE_URL required in production" if config.database_url.empty?
  raise "Pool size too small for production" if config.pool_size < 10
  raise "Performance monitoring should be disabled in production" if config.enable_performance_monitoring?
end

if CQL.config.environment == "production"
  validate_production_config
end
```

## API Reference

### CQL.configure

Main configuration method that yields a configuration object:

```crystal
CQL.configure do |config|
  # Configure settings
end
```

### CQL.config

Returns the current configuration instance (read-only):

```crystal
config = CQL.config
puts config.database_url
```

### CQL.reset_config!

Resets configuration to defaults (useful for testing):

```crystal
CQL.reset_config!
```

### CQL::Configure::Config

Configuration object with all settings. See [Configuration Options](#configuration-options) for complete list.

### CQL::ConfigHelpers

Helper module providing quick access to common configuration values:

- `CQL::ConfigHelpers.database_url : String`
- `CQL::ConfigHelpers.logger : Log`
- `CQL::ConfigHelpers.timezone : Time::Location`
- `CQL::ConfigHelpers.environment : String`
- `CQL::ConfigHelpers.auto_load_models? : Bool`
- `CQL::ConfigHelpers.schema_file_path : String`
- `CQL::ConfigHelpers.schema_path : String`
- `CQL::ConfigHelpers.auto_schema_sync? : Bool`
- `CQL::ConfigHelpers.create_migrator_config : CQL::MigratorConfig`

---

## Examples

For complete usage examples, see:

- `examples/configure_example.cr` - Basic configuration examples
- `examples/configure_migration_example.cr` - Migration workflow integration examples

## Related Guides

- [Getting Started](getting-started.md)
- [Schema Definition](../core-concepts/schemas.md)
- [Migrations](../core-concepts/migrations.md)
- [Integrated Migration Workflow](active-record-with-cql/integrated-migration-workflow.md)
- [Performance Monitoring](performance-tools.md)
- [Testing Strategies](testing-strategies.md)
