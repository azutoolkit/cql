require "log"
require "mutex"
require "./migrations"
require "./performance"
require "./configure/*"

module CQL
  # Centralized configuration management for CQL library using SOLID principles
  #
  # This module provides a thread-safe, extensible way to configure all fundamental
  # settings of the CQL library from one centralized place.
  #
  # **Example** Basic configuration
  # ```
  # CQL.configure do |config|
  #   config.database_url = "postgresql://localhost/myapp"
  #   config.logger = Log.for("MyApp")
  #   config.default_timezone = :utc
  # end
  # ```
  module Configure
    # Thread-safe mutex for configuration access
    @@config_mutex = Mutex.new
    @@config_instance : Config? = nil

    # Main configuration class with single responsibility
    class Config
      # Core settings
      property database_url : String = "sqlite3://./db/development.db"
      property logger : Log = Log.for("cql.*")
      property default_timezone : Symbol = :utc
      property environment : String = ENV["CRYSTAL_ENV"]? || "development"
      # Migration and Schema Management
      property migration_table_name : Symbol = :cql_schema_migrations
      property schema_path : String = "src/schemas"
      property schema_file_name : String = "app_schema.cr"
      property schema_constant_name : Symbol = :AppSchema
      property schema_symbol : Symbol = :app_schema
      property? auto_load_models : Bool = true
      property? enable_auto_schema_sync : Bool = true
      property? bootstrap_on_startup : Bool = false
      property? verify_schema_on_startup : Bool = false

      # Query and Performance settings
      property? enable_query_cache : Bool = false
      property cache_ttl : Time::Span = 1.hour
      property? enable_performance_monitoring : Bool = false
      property performance_config : CQL::Performance::PerformanceConfig = CQL::Performance::PerformanceConfig.new

      # Custom adapter configuration
      property adapter_config : Hash(String, String) = Hash(String, String).new

      # Composed configuration objects
      getter connection_pool : ConnectionPoolConfig = ConnectionPoolConfig.new
      getter ssl : SSLConfig = SSLConfig.new
      getter postgresql : PostgreSQLConfig = PostgreSQLConfig.new
      getter mysql : MySQLConfig = MySQLConfig.new
      getter sqlite : SQLiteConfig = SQLiteConfig.new

      # Validators and strategies
      @validators = [BasicConfigValidator.new] of ConfigValidator

      def initialize
        setup_default_logger
        apply_environment_defaults
      end

      # Validation using composite pattern
      def validate! : Nil
        @validators.each(&.validate!(self))
        connection_pool.validate!
        ssl.validate!
        database_config.validate!
      end

      # Get effective database URL using Builder pattern
      def effective_database_url : String
        DatabaseURLBuilder.new(database_url)
          .with_connection_pool(connection_pool)
          .with_ssl(ssl)
          .with_database_config(database_config)
          .with_adapter_config(adapter_config)
          .build
      end

      # Get database adapter based on URL
      def database_adapter : Adapter
        case database_url
        when .starts_with?("postgresql://"), .starts_with?("postgres://")
          Adapter::Postgres
        when .starts_with?("mysql://")
          Adapter::MySql
        when .starts_with?("sqlite3://")
          Adapter::SQLite
        else
          raise ArgumentError.new("Unsupported database URL format: #{database_url}")
        end
      end

      # Get database-specific configuration
      def database_config : DatabaseConfig
        case database_adapter
        when Adapter::Postgres
          postgresql
        when Adapter::MySql
          mysql
        when Adapter::SQLite
          sqlite
        else
          raise ArgumentError.new("Unsupported adapter: #{database_adapter}")
        end
      end

      # Get the effective logger
      def effective_logger : Log
        @logger || Log.for("CQL")
      end

      # Configure performance monitoring if enabled
      def setup_performance_monitoring(schema : Schema) : Nil
        return unless enable_performance_monitoring?

        Performance.setup(schema) do |config|
          config.query_profiling_enabled = performance_config.query_profiling_enabled?
          config.n_plus_one_detection_enabled = performance_config.n_plus_one_detection_enabled?
          config.plan_analysis_enabled = performance_config.plan_analysis_enabled?
          config.auto_analyze_slow_queries = performance_config.auto_analyze_slow_queries?
          config.context_tracking_enabled = performance_config.context_tracking_enabled?
          config.endpoint_tracking_enabled = performance_config.endpoint_tracking_enabled?
          config.async_processing = performance_config.async_processing?
          config.current_endpoint = performance_config.current_endpoint?
          config.current_user_id = performance_config.current_user_id?
        end
      end

      # Migration and Schema Integration Methods

      def schema_file_path : String
        File.join(schema_path, schema_file_name)
      end

      # Consolidated migrator config creation with optional parameters
      def create_migrator_config(
        schema_file_path : String? = nil,
        schema_name : Symbol? = nil,
        schema_symbol : Symbol? = nil,
        migration_table_name : Symbol? = nil,
        auto_sync : Bool? = nil,
      ) : CQL::MigratorConfig
        CQL::MigratorConfig.new(
          schema_file_path: schema_file_path || self.schema_file_path,
          schema_name: schema_name || self.schema_constant_name,
          schema_symbol: schema_symbol || self.schema_symbol,
          migration_table_name: migration_table_name || self.migration_table_name,
          auto_sync: auto_sync.nil? ? enable_auto_schema_sync? : auto_sync
        )
      end

      def create_migrator_config_for_environment(env : String) : CQL::MigratorConfig
        case env
        when "production"
          create_migrator_config(
            schema_file_path: File.join(schema_path, "production_schema.cr"),
            schema_name: :ProductionSchema,
            schema_symbol: :production_schema,
            migration_table_name: :cql_schema_migrations,
            auto_sync: false
          )
        when "test"
          create_migrator_config(
            schema_file_path: File.join(schema_path, "test_schema.cr"),
            schema_name: :TestSchema,
            schema_symbol: :test_schema,
            migration_table_name: :test_schema_migrations,
            auto_sync: true
          )
        when "development"
          create_migrator_config(auto_sync: true)
        else
          create_migrator_config
        end
      end

      def create_migrator(schema : Schema) : CQL::Migrator
        migrator_config = create_migrator_config
        migrator = schema.migrator(migrator_config)

        # Handle startup options
        if bootstrap_on_startup?
          effective_logger.info { "Bootstrapping schema from existing database..." }
          migrator.bootstrap_schema
        elsif verify_schema_on_startup?
          unless migrator.verify_schema_consistency
            effective_logger.warn { "Schema file is out of sync with database" }
            if enable_auto_schema_sync?
              effective_logger.info { "Auto-updating schema file..." }
              migrator.update_schema_file
            end
          end
        end

        migrator
      end

      # Add custom validator
      def add_validator(validator : ConfigValidator) : Nil
        @validators << validator
      end

      private def setup_default_logger
        @logger = case environment
                  when "production"
                    Log.for("CQL::Production")
                  when "test"
                    Log.for("CQL::Test")
                  else
                    Log.for("CQL::Development")
                  end
      end

      private def apply_environment_defaults
        strategy = EnvironmentStrategyFactory.create(environment)
        strategy.apply(self)
      end
    end

    # Get the current configuration instance (thread-safe)
    def self.current : Config
      @@config_mutex.synchronize do
        @@config_instance ||= Config.new
      end
    end

    # Reset configuration to defaults (useful for testing)
    def self.reset! : Nil
      @@config_mutex.synchronize do
        @@config_instance = nil
      end
    end

    # Check if configuration has been initialized
    def self.configured? : Bool
      @@config_mutex.synchronize do
        !@@config_instance.nil?
      end
    end
  end

  # Main configuration method for CQL
  #
  # **Example** Basic usage
  # ```
  # CQL.configure do |config|
  #   config.database_url = "postgresql://localhost/myapp"
  #   config.logger = Log.for("MyApp")
  #   config.default_timezone = :utc
  #   config.auto_load_models = true
  # end
  # ```
  #
  # **Example** Production configuration
  # ```
  # CQL.configure do |config|
  #   config.database_url = ENV["DATABASE_URL"]
  #   config.logger = Log.for("Production")
  #   config.environment = "production"
  #   config.connection_pool.size = 25
  #   config.enable_performance_monitoring = false
  #   config.auto_load_models = false
  # end
  # ```
  def self.configure(& : Configure::Config ->)
    config = Configure.current
    yield config
    config.validate!
    config
  end

  # Get current configuration (read-only access)
  def self.config : Configure::Config
    Configure.current
  end

  # Reset configuration to defaults
  def self.reset_config! : Nil
    Configure.reset!
  end

  # Schema and Migration Methods

  # Create a schema with automatic migration support
  def self.create_schema(name : Symbol, &block) : Schema
    schema = Schema.define(name, config.database_url, config.database_adapter, &block)

    # Setup performance monitoring if enabled
    config.setup_performance_monitoring(schema) if config.enable_performance_monitoring?

    schema
  end

  # Create a migrator using centralized configuration
  def self.create_migrator(schema : Schema, migrator_config : MigratorConfig? = nil) : Migrator
    if migrator_config
      schema.migrator(migrator_config)
    else
      config.create_migrator(schema)
    end
  end

  # Bootstrap schema from existing database
  def self.bootstrap_schema(schema : Schema) : Migrator
    migrator = create_migrator(schema)
    migrator.bootstrap_schema
    migrator
  end

  # Verify and optionally fix schema consistency
  def self.verify_schema(schema : Schema, auto_fix : Bool = false) : Bool
    migrator = create_migrator(schema)
    consistent = migrator.verify_schema_consistency

    if !consistent && auto_fix && config.enable_auto_schema_sync?
      config.effective_logger.info { "Auto-fixing schema inconsistency..." }
      migrator.update_schema_file
      true
    else
      consistent
    end
  end

  # Delegate migrator config creation to the config object
  def self.create_migrator_config(**args) : MigratorConfig
    config.create_migrator_config(**args)
  end

  # Create environment-specific MigratorConfig
  def self.create_migrator_config_for_environment(env : String) : MigratorConfig
    config.create_migrator_config_for_environment(env)
  end
end
