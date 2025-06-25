require "log"
require "mutex"
require "./migrations"
require "./performance"

module CQL
  # Centralized configuration management for CQL library
  #
  # This module provides a thread-safe way to configure all fundamental
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
  #
  # **Example** Environment-specific configuration
  # ```
  # CQL.configure do |config|
  #   case ENV["CRYSTAL_ENV"]? || "development"
  #   when "production"
  #     config.database_url = ENV["DATABASE_URL"]
  #     config.logger = Log.for("Production")
  #     config.auto_load_models = false
  #   when "test"
  #     config.database_url = "sqlite3://:memory:"
  #     config.logger = Log.for("Test")
  #     config.migration_table_name = "test_schema_migrations"
  #   else
  #     config.database_url = "sqlite3://./db/development.db"
  #     config.logger = Log.for("Development")
  #     config.auto_load_models = true
  #   end
  # end
  # ```
  module Configure
    # Thread-safe mutex for configuration access
    @@config_mutex = Mutex.new
    @@config_instance : Config? = nil

    # Configuration object that holds all CQL settings
    class Config
      # Database connection URL
      property database_url : String = "sqlite3://./db/development.db"

      # Logger instance for CQL operations
      property logger : Log? = nil

      # Default timezone for timestamp operations
      property default_timezone : Symbol = :utc

      # Name of the migration table in the database
      property migration_table_name : String = "cql_schema_migrations"

      # Path where schema files are stored
      property schema_path : String = "src/schemas"

      # Whether to automatically load model files
      property? auto_load_models : Bool = true

      # Connection pool size (default: 10)
      property pool_size : Int32 = 10

      # Connection checkout timeout
      property checkout_timeout : Time::Span = 10.seconds

      # Query timeout for database operations
      property query_timeout : Time::Span = 30.seconds

      # Enable query caching
      property? enable_query_cache : Bool = false

      # Default cache TTL for query results
      property cache_ttl : Time::Span = 1.hour

      # Environment name (development, test, production)
      property environment : String = ENV["CRYSTAL_ENV"]? || "development"

      # Maximum number of connection retry attempts
      property max_retry_attempts : Int32 = 3

      # Delay between connection retry attempts
      property retry_delay : Time::Span = 1.second

      # Enable SQL query logging
      property? enable_sql_logging : Bool = false

      # Log level for SQL queries
      property sql_log_level : Log::Severity = Log::Severity::Debug

      # Enable performance monitoring
      property? enable_performance_monitoring : Bool = false

      # Performance monitoring configuration
      property performance_config : CQL::Performance::PerformanceConfig? = nil

      # Custom adapter configuration
      property adapter_config : Hash(String, String) = Hash(String, String).new

      # Migration and Schema Management
      # Whether to enable automatic schema file synchronization
      property? enable_auto_schema_sync : Bool = true

      # Default schema file name (without path)
      property schema_file_name : String = "app_schema.cr"

      # Schema constant name in generated file
      property schema_constant_name : Symbol = :AppSchema

      # Schema symbol for internal use
      property schema_symbol : Symbol = :app_schema

      # Whether to bootstrap schema on first run
      property? bootstrap_on_startup : Bool = false

      # Whether to verify schema consistency on startup
      property? verify_schema_on_startup : Bool = false

      def initialize
        # Set default logger based on environment
        setup_default_logger

        # Set environment-specific defaults
        apply_environment_defaults
      end

      # Apply environment-specific default configurations
      private def apply_environment_defaults
        case environment
        when "production"
          self.auto_load_models = false
          self.enable_sql_logging = false
          self.pool_size = 25
          self.checkout_timeout = 15.seconds
          self.max_retry_attempts = 5
        when "test"
          self.database_url = "sqlite3://:memory:"
          self.migration_table_name = "test_schema_migrations"
          self.auto_load_models = false
          self.enable_sql_logging = false
          self.pool_size = 1
        when "development"
          self.enable_sql_logging = true
          self.enable_performance_monitoring = true
          self.pool_size = 5
        end

        # Apply schema-specific environment defaults
        apply_schema_environment_defaults
      end

      # Setup default logger based on environment
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

      # Validate configuration settings
      def validate!
        raise ArgumentError.new("database_url cannot be empty") if database_url.empty?
        raise ArgumentError.new("schema_path cannot be empty") if schema_path.empty?
        raise ArgumentError.new("migration_table_name cannot be empty") if migration_table_name.empty?
        raise ArgumentError.new("schema_file_name cannot be empty") if schema_file_name.empty?
        raise ArgumentError.new("pool_size must be positive") if pool_size <= 0
        raise ArgumentError.new("max_retry_attempts must be positive") if max_retry_attempts <= 0

        unless [:utc, :local].includes?(default_timezone)
          raise ArgumentError.new("default_timezone must be :utc or :local")
        end

        # Validate schema file name has .cr extension
        unless schema_file_name.ends_with?(".cr")
          raise ArgumentError.new("schema_file_name must end with .cr extension")
        end
      end

      # Get the effective logger (return a default if none set)
      def effective_logger : Log
        @logger || Log.for("CQL")
      end

      # Configure performance monitoring if enabled
      def setup_performance_monitoring(schema : Schema)
        return unless enable_performance_monitoring?

        perf_config = performance_config || CQL::Performance::PerformanceConfig.new
        Performance.setup(schema) do |config|
          config.query_profiling_enabled = perf_config.query_profiling_enabled?
          config.n_plus_one_detection_enabled = perf_config.n_plus_one_detection_enabled?
          config.plan_analysis_enabled = perf_config.plan_analysis_enabled?
        end
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

      # Convert timezone symbol to actual timezone
      def timezone : Time::Location
        case default_timezone
        when :utc
          Time::Location::UTC
        when :local
          Time::Location.local
        else
          Time::Location::UTC
        end
      end

      # Migration and Schema Integration Methods

      # Get full path to schema file
      def schema_file_path : String
        File.join(schema_path, schema_file_name)
      end

      # Create MigratorConfig from current configuration
      def create_migrator_config : CQL::MigratorConfig
        CQL::MigratorConfig.new(
          schema_file_path: schema_file_path,
          schema_name: schema_constant_name,
          schema_symbol: schema_symbol,
          auto_sync: enable_auto_schema_sync?
        )
      end

      # Create MigratorConfig with custom overrides
      def create_migrator_config(
        schema_file_path : String? = nil,
        schema_name : Symbol? = nil,
        schema_symbol : Symbol? = nil,
        auto_sync : Bool? = nil,
      ) : CQL::MigratorConfig
        CQL::MigratorConfig.new(
          schema_file_path: schema_file_path || self.schema_file_path,
          schema_name: schema_name || self.schema_constant_name,
          schema_symbol: schema_symbol || self.schema_symbol,
          auto_sync: auto_sync.nil? ? enable_auto_schema_sync? : auto_sync
        )
      end

      # Create environment-specific MigratorConfig
      def create_migrator_config_for_environment(env : String) : CQL::MigratorConfig
        case env
        when "production"
          create_migrator_config(
            schema_file_path: File.join(schema_path, "production_schema.cr"),
            schema_name: :ProductionSchema,
            schema_symbol: :production_schema,
            auto_sync: false
          )
        when "test"
          create_migrator_config(
            schema_file_path: File.join(schema_path, "test_schema.cr"),
            schema_name: :TestSchema,
            schema_symbol: :test_schema,
            auto_sync: true
          )
        when "development"
          create_migrator_config(auto_sync: true)
        else
          create_migrator_config
        end
      end

      # Create a configured migrator for a schema
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

      # Environment-specific schema settings
      def apply_schema_environment_defaults
        case environment
        when "production"
          self.enable_auto_schema_sync = false # Manual control in production
          self.verify_schema_on_startup = true
          self.bootstrap_on_startup = false
        when "test"
          self.schema_file_name = "test_schema.cr"
          self.schema_constant_name = :TestSchema
          self.schema_symbol = :test_schema
          self.enable_auto_schema_sync = true
          self.bootstrap_on_startup = false
          self.verify_schema_on_startup = false
        when "development"
          self.enable_auto_schema_sync = true
          self.verify_schema_on_startup = true
          self.bootstrap_on_startup = false
        end
      end
    end

    # Get the current configuration instance (thread-safe)
    def self.current : Config
      @@config_mutex.synchronize do
        @@config_instance ||= Config.new
      end
    end

    # Reset configuration to defaults (useful for testing)
    def self.reset!
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
  #   config.pool_size = 25
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
  def self.reset_config!
    Configure.reset!
  end

  # Migration workflow integration methods

  # Create a schema with automatic migration support
  def self.create_schema(name : Symbol, &block) : Schema
    schema = Schema.define(name, config.database_url, config.database_adapter, &block)

    # Setup performance monitoring if enabled
    config.setup_performance_monitoring(schema) if config.enable_performance_monitoring?

    schema
  end

  # Create a migrator using centralized configuration
  def self.create_migrator(schema : Schema) : Migrator
    config.create_migrator(schema)
  end

  # Bootstrap schema from existing database
  def self.bootstrap_schema(schema : Schema)
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

  # Create MigratorConfig using centralized configuration
  def self.create_migrator_config : MigratorConfig
    config.create_migrator_config
  end

  # Create MigratorConfig with custom overrides
  def self.create_migrator_config(
    schema_file_path : String? = nil,
    schema_name : Symbol? = nil,
    schema_symbol : Symbol? = nil,
    auto_sync : Bool? = nil,
  ) : MigratorConfig
    config.create_migrator_config(schema_file_path, schema_name, schema_symbol, auto_sync)
  end

  # Create environment-specific MigratorConfig
  def self.create_migrator_config_for_environment(env : String) : MigratorConfig
    config.create_migrator_config_for_environment(env)
  end

  # Create migrator with custom MigratorConfig
  def self.create_migrator(schema : Schema, migrator_config : MigratorConfig) : Migrator
    schema.migrator(migrator_config)
  end

  # Quick access methods for commonly used configuration values
  module ConfigHelpers
    def self.database_url : String
      CQL.config.database_url
    end

    def self.logger : Log
      CQL.config.effective_logger
    end

    def self.timezone : Time::Location
      CQL.config.timezone
    end

    def self.environment : String
      CQL.config.environment
    end

    def self.auto_load_models? : Bool
      CQL.config.auto_load_models?
    end

    # Migration-related helpers
    def self.schema_file_path : String
      CQL.config.schema_file_path
    end

    def self.schema_path : String
      CQL.config.schema_path
    end

    def self.auto_schema_sync? : Bool
      CQL.config.enable_auto_schema_sync?
    end

    def self.create_migrator_config : CQL::MigratorConfig
      CQL.config.create_migrator_config
    end

    # Create MigratorConfig with custom overrides
    def self.create_migrator_config(
      schema_file_path : String? = nil,
      schema_name : Symbol? = nil,
      schema_symbol : Symbol? = nil,
      auto_sync : Bool? = nil,
    ) : CQL::MigratorConfig
      CQL.config.create_migrator_config(schema_file_path, schema_name, schema_symbol, auto_sync)
    end

    # Create environment-specific MigratorConfig
    def self.create_migrator_config_for_environment(env : String) : CQL::MigratorConfig
      CQL.config.create_migrator_config_for_environment(env)
    end
  end
end
