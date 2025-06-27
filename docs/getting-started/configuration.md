# Configuration

The CQL::Configure module provides a centralized, thread-safe way to configure all fundamental settings of the CQL library. This guide covers how to use the configuration system effectively in your Crystal applications.

## Table of Contents

* [Quick Start](configuration.md#quick-start)
* [Configuration Options](configuration.md#configuration-options)
* [Environment-Specific Configuration](configuration.md#environment-specific-configuration)
* [Integration with Schema Definition](configuration.md#integration-with-schema-definition)
* [Performance Monitoring Configuration](configuration.md#performance-monitoring-configuration)
* [Database-Specific Configuration](configuration.md#database-specific-configuration)
* [Connection Pooling Configuration](configuration.md#connection-pooling-configuration)
* [SSL Configuration](configuration.md#ssl-configuration)
* [Thread Safety](configuration.md#thread-safety)
* [Validation](configuration.md#validation)
* [Best Practices](configuration.md#best-practices)
* [API Reference](configuration.md#api-reference)

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
puts CQL.config.connection_pool.size

# Using effective methods
puts CQL.config.effective_database_url
puts CQL.config.effective_logger
```

## Configuration Options

### Core Database Settings

| Option             | Type     | Default                                 | Description                           |
| ------------------ | -------- | --------------------------------------- | ------------------------------------- |
| `database_url`     | `String` | `"sqlite3://./db/development.db"`       | Database connection URL               |
| `logger`           | `Log`    | Environment-based                       | Logger instance for CQL operations    |
| `default_timezone` | `Symbol` | `:utc`                                  | Default timezone (`:utc` or `:local`) |
| `environment`      | `String` | `ENV["CRYSTAL_ENV"]` or `"development"` | Application environment               |

### Migration and Schema Management

| Option                     | Type     | Default                  | Description                                     |
| -------------------------- | -------- | ------------------------ | ----------------------------------------------- |
| `migration_table_name`     | `Symbol` | `:cql_schema_migrations` | Name of migration tracking table                |
| `schema_path`              | `String` | `"src/schemas"`          | Path where schema files are stored              |
| `schema_file_name`         | `String` | `"app_schema.cr"`        | Default schema file name                        |
| `schema_constant_name`     | `Symbol` | `:AppSchema`             | Schema constant name in generated file          |
| `schema_symbol`            | `Symbol` | `:app_schema`            | Schema symbol for internal use                  |
| `auto_load_models`         | `Bool`   | `true`                   | Whether to automatically load model files       |
| `enable_auto_schema_sync`  | `Bool`   | `true`                   | Enable automatic schema file synchronization    |
| `bootstrap_on_startup`     | `Bool`   | `false`                  | Whether to bootstrap schema on first run        |
| `verify_schema_on_startup` | `Bool`   | `false`                  | Whether to verify schema consistency on startup |

### Query and Performance Settings

| Option                          | Type                                  | Default                 | Description                          |
| ------------------------------- | ------------------------------------- | ----------------------- | ------------------------------------ |
| `enable_query_cache`            | `Bool`                                | `false`                 | Enable query result caching          |
| `cache_ttl`                     | `Time::Span`                          | `1.hour`                | Default cache time-to-live           |
| `enable_performance_monitoring` | `Bool`                                | `false`                 | Enable performance monitoring        |
| `performance_config`            | `CQL::Performance::PerformanceConfig` | `PerformanceConfig.new` | Performance monitoring configuration |

### Custom Configuration

| Option           | Type                   | Default                    | Description                  |
| ---------------- | ---------------------- | -------------------------- | ---------------------------- |
| `adapter_config` | `Hash(String, String)` | `Hash(String, String).new` | Custom adapter configuration |

### Composed Configuration Objects

The configuration system uses composed objects for specialized settings:

* `connection_pool` - Connection pooling settings
* `ssl` - SSL/TLS configuration
* `postgresql` - PostgreSQL-specific settings
* `mysql` - MySQL-specific settings
* `sqlite` - SQLite-specific settings

## Environment-Specific Configuration

CQL automatically applies environment-specific defaults based on the `CRYSTAL_ENV` environment variable:

### Development Environment

```crystal
CQL.configure do |config|
  config.environment = "development"
  config.database_url = "sqlite3://./db/development.db"
  config.enable_performance_monitoring = true
  config.connection_pool.size = 5
  config.connection_pool.initial_size = 2
  config.connection_pool.max_idle_size = 3
  config.sqlite.journal_mode = "wal"
  config.auto_load_models = true
  config.enable_auto_schema_sync = true
  config.verify_schema_on_startup = true
end
```

### Test Environment

```crystal
CQL.configure do |config|
  config.environment = "test"
  config.database_url = "sqlite3://:memory:"
  config.migration_table_name = :test_schema_migrations
  config.auto_load_models = false
  config.connection_pool.size = 1
  config.connection_pool.initial_size = 1
  config.connection_pool.max_idle_size = 1
  config.sqlite.journal_mode = "memory"
  config.schema_file_name = "test_schema.cr"
  config.schema_constant_name = :TestSchema
  config.schema_symbol = :test_schema
  config.enable_auto_schema_sync = true
  config.bootstrap_on_startup = false
  config.verify_schema_on_startup = false
end
```

### Production Environment

```crystal
CQL.configure do |config|
  config.environment = "production"
  config.database_url = ENV["DATABASE_URL"]
  config.auto_load_models = false
  config.connection_pool.size = 25
  config.connection_pool.initial_size = 5
  config.connection_pool.max_idle_size = 10
  config.connection_pool.checkout_timeout = 15.seconds
  config.connection_pool.max_retry_attempts = 5
  config.ssl.mode = "require"
  config.enable_auto_schema_sync = false
  config.verify_schema_on_startup = true
  config.bootstrap_on_startup = false
end
```

### Custom Environment Configuration

```crystal
CQL.configure do |config|
  case ENV["CRYSTAL_ENV"]? || "development"
  when "production"
    config.database_url = ENV["DATABASE_URL"]
    config.logger = Log.for("Production")
    config.connection_pool.size = 25
    config.enable_performance_monitoring = false
  when "staging"
    config.database_url = ENV["STAGING_DATABASE_URL"]
    config.logger = Log.for("Staging")
    config.connection_pool.size = 15
    config.enable_performance_monitoring = true
  when "test"
    config.database_url = "sqlite3://:memory:"
    config.logger = Log.for("Test")
    config.connection_pool.size = 1
  else # development
    config.database_url = "sqlite3://./db/development.db"
    config.logger = Log.for("Development")
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
  config.connection_pool.size = 15
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

  # Configure performance monitoring settings
  config.performance_config.query_profiling_enabled = true
  config.performance_config.n_plus_one_detection_enabled = true
  config.performance_config.plan_analysis_enabled = true
  config.performance_config.auto_analyze_slow_queries = true
  config.performance_config.context_tracking_enabled = true
  config.performance_config.endpoint_tracking_enabled = false
  config.performance_config.async_processing = false
  config.performance_config.current_endpoint = nil
  config.performance_config.current_user_id = nil
end

# Later, when creating your schema
schema = CQL::Schema.define(:app, adapter: CQL.config.database_adapter, uri: CQL.config.database_url)

# Automatically setup performance monitoring using configuration
CQL.config.setup_performance_monitoring(schema)
```

## Database-Specific Configuration

### PostgreSQL Configuration

```crystal
CQL.configure do |config|
  config.database_url = "postgresql://localhost/myapp"
  config.postgresql.auth_methods = "scram-sha-256,md5"
end
```

### MySQL Configuration

```crystal
CQL.configure do |config|
  config.database_url = "mysql://user:pass@localhost/myapp"
  config.mysql.encoding = "utf8mb4_unicode_ci"
end
```

### SQLite Configuration

```crystal
CQL.configure do |config|
  config.database_url = "sqlite3://./db/app.db"
  config.sqlite.journal_mode = "wal"
  config.sqlite.synchronous = "normal"
  config.sqlite.cache_size = -4000  # 4MB cache
  config.sqlite.foreign_keys = true
  config.sqlite.busy_timeout = 5000  # 5 seconds
end
```

## Connection Pooling Configuration

Configure connection pooling settings:

```crystal
CQL.configure do |config|
  config.connection_pool.size = 20
  config.connection_pool.initial_size = 5
  config.connection_pool.max_idle_size = 10
  config.connection_pool.checkout_timeout = 10.seconds
  config.connection_pool.query_timeout = 30.seconds
  config.connection_pool.max_retry_attempts = 3
  config.connection_pool.retry_delay = 1.second
  config.connection_pool.use_prepared_statements = true
end
```

### Connection Pool Settings

| Option                    | Type         | Default      | Description                 |
| ------------------------- | ------------ | ------------ | --------------------------- |
| `size`                    | `Int32`      | `10`         | Maximum pool size           |
| `initial_size`            | `Int32`      | `1`          | Initial pool size           |
| `max_idle_size`           | `Int32`      | `1`          | Maximum idle connections    |
| `checkout_timeout`        | `Time::Span` | `10.seconds` | Connection checkout timeout |
| `query_timeout`           | `Time::Span` | `30.seconds` | Query execution timeout     |
| `max_retry_attempts`      | `Int32`      | `3`          | Maximum retry attempts      |
| `retry_delay`             | `Time::Span` | `1.second`   | Delay between retries       |
| `use_prepared_statements` | `Bool`       | `true`       | Use prepared statements     |

## SSL Configuration

Configure SSL/TLS settings for secure database connections:

```crystal
CQL.configure do |config|
  config.ssl.mode = "require"
  config.ssl.cert_path = "/path/to/client-cert.pem"
  config.ssl.key_path = "/path/to/client-key.pem"
  config.ssl.ca_path = "/path/to/ca-cert.pem"
end
```

### SSL Settings

| Option      | Type      | Default    | Description                                                        |
| ----------- | --------- | ---------- | ------------------------------------------------------------------ |
| `mode`      | `String`  | `"prefer"` | SSL mode (disable, allow, prefer, require, verify-ca, verify-full) |
| `cert_path` | `String?` | `nil`      | Path to client certificate                                         |
| `key_path`  | `String?` | `nil`      | Path to client private key                                         |
| `ca_path`   | `String?` | `nil`      | Path to CA certificate                                             |

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
    config.connection_pool.size = -1  # Invalid: negative pool size
    config.default_timezone = :invalid # Invalid: unsupported timezone
  end
rescue ArgumentError => ex
  puts "Configuration error: #{ex.message}"
end
```

### Validation Rules

* `database_url` cannot be empty
* `schema_path` cannot be empty
* `schema_file_name` cannot be empty
* `schema_file_name` must end with `.cr` extension
* `connection_pool.size` must be positive
* `connection_pool.initial_size` must be positive
* `connection_pool.max_idle_size` must be positive
* `connection_pool.max_retry_attempts` must be positive
* `default_timezone` must be `:utc` or `:local`
* `ssl.mode` must be one of: `disable`, `allow`, `prefer`, `require`, `verify-ca`, `verify-full`
* `sqlite.journal_mode` must be one of: `delete`, `truncate`, `persist`, `memory`, `wal`, `off`
* `sqlite.synchronous` must be one of: `off`, `normal`, `full`, `extra`
* `sqlite.busy_timeout` must be non-negative

### Custom Validation

Add custom validators to the configuration:

```crystal
class CustomValidator < CQL::Configure::ConfigValidator
  def validate!(config : CQL::Configure::Config) : Nil
    if config.database_url.includes?("password123")
      raise ArgumentError.new("Weak password detected in database URL!")
    end
  end
end

CQL.configure do |config|
  config.database_url = "mysql://user:password123@localhost/test"
  config.add_validator(CustomValidator.new)
end
```

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
  config.connection_pool.size = ENV["DB_POOL_SIZE"]?.try(&.to_i) || 10
  config.enable_performance_monitoring = ENV["PERFORMANCE_MONITORING"]? == "true"
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
  config.connection_pool.size = 25
  config.auto_load_models = false
  config.enable_performance_monitoring = false
end

# config/development.cr
CQL.configure do |config|
  config.database_url = "sqlite3://./db/development.db"
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
    config.migration_table_name = :test_schema_migrations
    config.auto_load_models = false
  end
end
```

### 5. Use Configuration Validation

```crystal
def validate_production_config
  config = CQL.config

  raise "DATABASE_URL required in production" if config.database_url.empty?
  raise "Pool size too small for production" if config.connection_pool.size < 10
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

### CQL.reset\_config!

Resets configuration to defaults (useful for testing):

```crystal
CQL.reset_config!
```

### CQL::Configure::Config

Configuration object with all settings. See [Configuration Options](configuration.md#configuration-options) for complete list.

### CQL::Configure::Config Methods

#### Core Methods

* `effective_database_url : String` - Get effective database URL with all parameters
* `database_adapter : Adapter` - Get database adapter based on URL
* `database_config : DatabaseConfig` - Get database-specific configuration
* `effective_logger : Log` - Get the effective logger instance
* `schema_file_path : String` - Get full schema file path

#### Migration Methods

* `create_migrator_config(**args) : CQL::MigratorConfig` - Create migrator configuration
* `create_migrator_config_for_environment(env : String) : CQL::MigratorConfig` - Create environment-specific migrator config
* `create_migrator(schema : Schema) : CQL::Migrator` - Create migrator with configuration
* `setup_performance_monitoring(schema : Schema) : Nil` - Setup performance monitoring

#### Validation Methods

* `validate! : Nil` - Validate all configuration settings
* `add_validator(validator : ConfigValidator) : Nil` - Add custom validator

### CQL Schema and Migration Methods

* `CQL.create_schema(name : Symbol, &block) : Schema` - Create schema with configuration
* `CQL.create_migrator(schema : Schema, migrator_config : MigratorConfig? = nil) : Migrator` - Create migrator
* `CQL.bootstrap_schema(schema : Schema) : Migrator` - Bootstrap schema from existing database
* `CQL.verify_schema(schema : Schema, auto_fix : Bool = false) : Bool` - Verify schema consistency
* `CQL.create_migrator_config(**args) : MigratorConfig` - Create migrator config
* `CQL.create_migrator_config_for_environment(env : String) : MigratorConfig` - Create environment-specific migrator config

***

## Examples

For complete usage examples, see:

* `examples/configure_example.cr` - Basic configuration examples
* `examples/configure_migration_example.cr` - Migration workflow integration examples

## Related Guides

* [Getting Started](getting-started.md)
* [Schema Definition](../foundation/schemas.md)
* [Migrations](../foundation/migrations.md)
* [Integrated Migration Workflow](../active-record-with-cql/integrated-migration-workflow.md)
* [Performance Monitoring](../advanced-topics/performance-tools.md)
* [Testing Strategies](../advanced-topics/testing-strategies.md)
