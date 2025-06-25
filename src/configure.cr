require "log"
require "mutex"
require "./migrations"
require "./performance"

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

    # Database-specific configuration interface
    abstract class DatabaseConfig
      abstract def apply_to_params(params : HTTP::Params) : Nil
      abstract def validate! : Nil
    end

    # PostgreSQL-specific configuration
    class PostgreSQLConfig < DatabaseConfig
      property auth_methods : String = "scram-sha-256,md5"

      def apply_to_params(params : HTTP::Params) : Nil
        params.add("auth_methods", auth_methods)
      end

      def validate! : Nil
        # Add PostgreSQL-specific validation if needed
      end
    end

    # MySQL-specific configuration
    class MySQLConfig < DatabaseConfig
      property encoding : String = "utf8mb4_unicode_ci"

      def apply_to_params(params : HTTP::Params) : Nil
        params.add("encoding", encoding)
      end

      def validate! : Nil
        # Add MySQL-specific validation if needed
      end
    end

    # SQLite-specific configuration
    class SQLiteConfig < DatabaseConfig
      property journal_mode : String = "wal"
      property synchronous : String = "normal"
      property cache_size : Int32 = -4000
      property? foreign_keys : Bool = true
      property busy_timeout : Int32 = 5000

      def apply_to_params(params : HTTP::Params) : Nil
        params.add("journal_mode", journal_mode)
        params.add("synchronous", synchronous)
        params.add("cache_size", cache_size.to_s)
        params.add("foreign_keys", foreign_keys? ? "1" : "0")
        params.add("busy_timeout", busy_timeout.to_s)
      end

      def validate! : Nil
        raise ArgumentError.new("sqlite_busy_timeout must be non-negative") if busy_timeout < 0

        valid_journal_modes = %w[delete truncate persist memory wal off]
        unless valid_journal_modes.includes?(journal_mode)
          raise ArgumentError.new("sqlite_journal_mode must be one of: #{valid_journal_modes.join(", ")}")
        end

        valid_sync_modes = %w[off normal full extra]
        unless valid_sync_modes.includes?(synchronous)
          raise ArgumentError.new("sqlite_synchronous must be one of: #{valid_sync_modes.join(", ")}")
        end
      end
    end

    # SSL/TLS configuration
    class SSLConfig
      property mode : String = "prefer"
      property cert_path : String? = nil
      property key_path : String? = nil
      property ca_path : String? = nil

      def apply_to_params(params : HTTP::Params, adapter : Adapter) : Nil
        case adapter
        when Adapter::Postgres, Adapter::MySql
          params.add("sslmode", mode)
          params.add("sslcert", cert_path) if cert_path
          params.add("sslkey", key_path) if key_path
          params.add("sslca", ca_path) if ca_path
        end
      end

      def validate! : Nil
        valid_ssl_modes = %w[disable allow prefer require verify-ca verify-full]
        unless valid_ssl_modes.includes?(mode)
          raise ArgumentError.new("ssl_mode must be one of: #{valid_ssl_modes.join(", ")}")
        end
      end
    end

    # Connection pool configuration
    class ConnectionPoolConfig
      property size : Int32 = 10
      property initial_size : Int32 = 1
      property max_idle_size : Int32 = 1
      property checkout_timeout : Time::Span = 10.seconds
      property query_timeout : Time::Span = 30.seconds
      property max_retry_attempts : Int32 = 3
      property retry_delay : Time::Span = 1.second
      property? use_prepared_statements : Bool = true

      def apply_to_params(params : HTTP::Params) : Nil
        params.add("initial_pool_size", initial_size.to_s)
        params.add("max_pool_size", size.to_s)
        params.add("max_idle_pool_size", max_idle_size.to_s)
        params.add("checkout_timeout", checkout_timeout.total_seconds.to_s)
        params.add("retry_attempts", max_retry_attempts.to_s)
        params.add("retry_delay", retry_delay.total_seconds.to_s)
        params.add("prepared_statements", use_prepared_statements?.to_s)
      end

      def validate! : Nil
        raise ArgumentError.new("pool_size must be positive") if size <= 0
        raise ArgumentError.new("initial_pool_size must be positive") if initial_size <= 0
        raise ArgumentError.new("max_idle_pool_size must be positive") if max_idle_size <= 0
        raise ArgumentError.new("max_retry_attempts must be positive") if max_retry_attempts <= 0
      end
    end

    # Database URL builder using Builder pattern
    class DatabaseURLBuilder
      def initialize(@database_url : String)
      end

      def with_connection_pool(pool_config : ConnectionPoolConfig) : self
        @pool_config = pool_config
        self
      end

      def with_ssl(ssl_config : SSLConfig) : self
        @ssl_config = ssl_config
        self
      end

      def with_database_config(db_config : DatabaseConfig) : self
        @db_config = db_config
        self
      end

      def with_adapter_config(adapter_config : Hash(String, String)) : self
        @adapter_config = adapter_config
        self
      end

      def build : String
        uri = URI.parse(@database_url)
        params = HTTP::Params.new

        # Apply connection pool configuration
        @pool_config.try(&.apply_to_params(params))

        # Apply SSL configuration
        adapter = detect_adapter(@database_url)
        @ssl_config.try(&.apply_to_params(params, adapter))

        # Apply database-specific configuration
        @db_config.try(&.apply_to_params(params))

        # Apply custom adapter configuration
        @adapter_config.try do |config|
          config.each { |key, value| params.add(key, value) }
        end

        # Rebuild the URL with parameters
        uri.query = params.to_s
        uri.to_s
      end

      private def detect_adapter(url : String) : Adapter
        case url
        when .starts_with?("postgresql://"), .starts_with?("postgres://")
          Adapter::Postgres
        when .starts_with?("mysql://")
          Adapter::MySql
        when .starts_with?("sqlite3://")
          Adapter::SQLite
        else
          raise ArgumentError.new("Unsupported database URL format: #{url}")
        end
      end
    end

    # Configuration validator using Strategy pattern
    abstract class ConfigValidator
      abstract def validate!(config : Config) : Nil
    end

    class BasicConfigValidator < ConfigValidator
      def validate!(config : Config) : Nil
        raise ArgumentError.new("database_url cannot be empty") if config.database_url.empty?
        raise ArgumentError.new("schema_path cannot be empty") if config.schema_path.empty?
        raise ArgumentError.new("migration_table_name cannot be empty") if config.migration_table_name.empty?
        raise ArgumentError.new("schema_file_name cannot be empty") if config.schema_file_name.empty?

        unless [:utc, :local].includes?(config.default_timezone)
          raise ArgumentError.new("default_timezone must be :utc or :local")
        end

        unless config.schema_file_name.ends_with?(".cr")
          raise ArgumentError.new("schema_file_name must end with .cr extension")
        end
      end
    end

    # Environment configuration strategy using Strategy pattern
    abstract class EnvironmentStrategy
      abstract def apply(config : Config) : Nil
    end

    class ProductionStrategy < EnvironmentStrategy
      def apply(config : Config) : Nil
        config.auto_load_models = false
        config.enable_sql_logging = false
        config.connection_pool.size = 25
        config.connection_pool.initial_size = 5
        config.connection_pool.max_idle_size = 10
        config.connection_pool.checkout_timeout = 15.seconds
        config.connection_pool.max_retry_attempts = 5
        config.ssl.mode = "require"

        # Schema settings
        config.enable_auto_schema_sync = false
        config.verify_schema_on_startup = true
        config.bootstrap_on_startup = false
      end
    end

    class TestStrategy < EnvironmentStrategy
      def apply(config : Config) : Nil
        config.database_url = "sqlite3://:memory:"
        config.migration_table_name = "test_schema_migrations"
        config.auto_load_models = false
        config.enable_sql_logging = false
        config.connection_pool.size = 1
        config.connection_pool.initial_size = 1
        config.connection_pool.max_idle_size = 1
        config.sqlite.journal_mode = "memory"

        # Schema settings
        config.schema_file_name = "test_schema.cr"
        config.schema_constant_name = :TestSchema
        config.schema_symbol = :test_schema
        config.enable_auto_schema_sync = true
        config.bootstrap_on_startup = false
        config.verify_schema_on_startup = false
      end
    end

    class DevelopmentStrategy < EnvironmentStrategy
      def apply(config : Config) : Nil
        config.enable_sql_logging = true
        config.enable_performance_monitoring = true
        config.connection_pool.size = 5
        config.connection_pool.initial_size = 2
        config.connection_pool.max_idle_size = 3
        config.sqlite.journal_mode = "wal"

        # Schema settings
        config.enable_auto_schema_sync = true
        config.verify_schema_on_startup = true
        config.bootstrap_on_startup = false
      end
    end

    # Factory for creating environment strategies
    class EnvironmentStrategyFactory
      def self.create(environment : String) : EnvironmentStrategy
        case environment
        when "production"
          ProductionStrategy.new
        when "test"
          TestStrategy.new
        when "development"
          DevelopmentStrategy.new
        else
          DevelopmentStrategy.new
        end
      end
    end

    # Factory for creating database configurations
    class DatabaseConfigFactory
      def self.create(adapter : Adapter) : DatabaseConfig
        case adapter
        when Adapter::Postgres
          PostgreSQLConfig.new
        when Adapter::MySql
          MySQLConfig.new
        when Adapter::SQLite
          SQLiteConfig.new
        else
          raise ArgumentError.new("Unsupported adapter: #{adapter}")
        end
      end
    end

    # Main configuration class with single responsibility
    class Config
      # Core settings
      property database_url : String = "sqlite3://./db/development.db"
      property logger : Log? = nil
      property default_timezone : Symbol = :utc
      property environment : String = ENV["CRYSTAL_ENV"]? || "development"

      # Migration and Schema Management
      property migration_table_name : String = "cql_schema_migrations"
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
      property? enable_sql_logging : Bool = false
      property sql_log_level : Log::Severity = Log::Severity::Debug
      property? enable_performance_monitoring : Bool = false
      property performance_config : CQL::Performance::PerformanceConfig? = nil

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
      @environment_strategy : EnvironmentStrategy? = nil

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

      # Configure performance monitoring if enabled
      def setup_performance_monitoring(schema : Schema) : Nil
        return unless enable_performance_monitoring?

        perf_config = performance_config || CQL::Performance::PerformanceConfig.new
        Performance.setup(schema) do |config|
          config.query_profiling_enabled = perf_config.query_profiling_enabled?
          config.n_plus_one_detection_enabled = perf_config.n_plus_one_detection_enabled?
          config.plan_analysis_enabled = perf_config.plan_analysis_enabled?
        end
      end

      # Migration and Schema Integration Methods

      def schema_file_path : String
        File.join(schema_path, schema_file_name)
      end

      def create_migrator_config : CQL::MigratorConfig
        CQL::MigratorConfig.new(
          schema_file_path: schema_file_path,
          schema_name: schema_constant_name,
          schema_symbol: schema_symbol,
          auto_sync: enable_auto_schema_sync?
        )
      end

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
