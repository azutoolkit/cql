require "log"
require "mutex"
require "./migrations"
require "./cache/*"
require "./configure/*"

module CQL
  # 🚀 Developer-friendly centralized configuration for CQL
  #
  # Quick setup for different environments:
  #
  # **Development** (minimal config - auto-detects environment)
  # ```
  # CQL.configure do |config|
  #   config.db = "postgresql://localhost/myapp"
  #   # That's it! SQL logging auto-enabled
  # end
  # ```
  #
  # **Production**
  # ```
  # CQL.configure do |config|
  #   config.db = ENV["DATABASE_URL"]
  #   config.env = "production"
  #   config.pool_size = 25
  # end
  # ```
  #
  # **Custom Development Setup**
  # ```
  # CQL.configure do |config|
  #   config.db = "postgresql://localhost/myapp"
  #   config.sql_logging_async = true # Async SQL logging
  # end
  # ```
  module Configure
    # Thread-safe mutex for configuration access
    @@config_mutex = Mutex.new
    @@config_instance : Config? = nil

    # 🎯 Main configuration class - optimized for developer experience
    class Config
      # === 🔌 DATABASE CONNECTION ===
      # Primary database connection URL
      property db : String = "sqlite3://./db/development.db"

      # Environment (auto-detects from CRYSTAL_ENV)
      property env : String = ENV["CRYSTAL_ENV"]? || "development"

      # Timezone for date/time operations
      property timezone : Symbol = :utc

      # Custom database adapter settings
      property adapter_options : Hash(String, String) = Hash(String, String).new

      # === 📋 LOGGING ===
      # Main application logger
      property logger : Log = Log.for("cql.*")

      # Shortcut for log level (maps to logger.level)
      property log_level : Log::Severity = Log::Severity::Info

      # === 🗂️ SCHEMA & MIGRATIONS ===
      # Directory containing schema files
      property schema_dir : String = "src/schemas"

      # Main schema file name
      property schema_file : String = "app_schema.cr"

      # Schema class name in Crystal code
      property schema_class : Symbol = :AppSchema

      # Schema instance symbol
      property schema_name : Symbol = :app_schema

      # Database table for tracking migrations
      property migrations_table : Symbol = :schema_migrations

      # === ⚡ BEHAVIOR FLAGS ===
      # Auto-load model files on startup
      property auto_load : Bool = true

      # Keep schema file in sync with database
      property auto_sync : Bool = true

      # Create schema from existing database on first run
      property bootstrap : Bool = false

      # Verify schema matches database on startup
      property verify_schema : Bool = false

      # === 🎨 SQL LOGGING ===
      # Enable beautiful SQL logging (auto-enabled in development)
      property sql_logging : Bool = false

      # SQL logging options
      property sql_logging_colorize : Bool = true # Colorize SQL output
      property sql_logging_async : Bool = false   # Use async logging (not recommended for dev)

      # === 💾 CACHE SYSTEM ===
      # Centralized cache configuration (use config.cache.* to configure)
      getter cache : CacheConfig = CacheConfig.new

      # === 🔗 CONNECTION POOL ===
      # Number of database connections in pool
      property pool_size : Int32 = 10

      # Detailed connection pool settings
      getter pool : ConnectionPoolConfig = ConnectionPoolConfig.new

      # === 🔐 SECURITY ===
      # SSL/TLS configuration
      getter ssl : SSLConfig = SSLConfig.new

      # === 🗄️ DATABASE-SPECIFIC SETTINGS ===
      getter postgres : PostgreSQLConfig = PostgreSQLConfig.new
      getter mysql : MySQLConfig = MySQLConfig.new
      getter sqlite : SQLiteConfig = SQLiteConfig.new

      # === 🛡️ VALIDATION ===
      @validators = [BasicConfigValidator.new] of ConfigValidator

      def initialize
        setup_smart_defaults
        sync_pool_size
        apply_environment_config
      end

      # === 🔍 HELPER METHODS (more memorable syntax) ===

      # Check if auto-loading is enabled
      def auto_load? : Bool
        @auto_load
      end

      # Check if auto-sync is enabled
      def auto_sync? : Bool
        @auto_sync
      end

      # Check if bootstrap is enabled
      def bootstrap? : Bool
        @bootstrap
      end

      # Check if schema verification is enabled
      def verify_schema? : Bool
        @verify_schema
      end

      # Check if SQL logging is enabled
      def sql_logging? : Bool
        sql_logging || (env == "development" && !ENV.has_key?("CQL_NO_SQL_LOG"))
      end

      # === 🎯 SMART GETTERS ===

      # Get the database adapter type
      def adapter : Adapter
        case db
        when .starts_with?("postgresql://"), .starts_with?("postgres://")
          Adapter::Postgres
        when .starts_with?("mysql://")
          Adapter::MySql
        when .starts_with?("sqlite3://")
          Adapter::SQLite
        else
          raise ArgumentError.new("Unsupported database URL: #{db}")
        end
      end

      # Get the effective logger with proper level
      def effective_logger : Log
        @logger.level = @log_level
        @logger
      end

      # Get full path to schema file
      def schema_path : String
        File.join(schema_dir, schema_file)
      end

      # Get database-specific configuration
      def db_config : DatabaseConfig
        case adapter
        when Adapter::Postgres then postgres
        when Adapter::MySql    then mysql
        when Adapter::SQLite   then sqlite
        else
          raise ArgumentError.new("Unsupported adapter: #{adapter}")
        end
      end

      # Get complete database URL with all settings applied
      def full_db_url : String
        DatabaseURLBuilder.new(db)
          .with_connection_pool(pool)
          .with_ssl(ssl)
          .with_database_config(db_config)
          .with_adapter_config(adapter_options)
          .build
      end

      # === 🔧 VALIDATION ===

      def validate! : Nil
        @validators.each(&.validate!(self))
        pool.validate!
        ssl.validate!
        db_config.validate!
        cache.validate!
      end

      # === 🏗️ FACTORY METHODS ===

      # Create migrator configuration
      def migrator_config(
        schema_path : String? = nil,
        schema_class : Symbol? = nil,
        schema_name : Symbol? = nil,
        migrations_table : Symbol? = nil,
        auto_sync : Bool? = nil,
      ) : CQL::MigratorConfig
        CQL::MigratorConfig.new(
          schema_file_path: schema_path || self.schema_path,
          schema_name: schema_class || self.schema_class,
          schema_symbol: schema_name || self.schema_name,
          migration_table_name: migrations_table || self.migrations_table,
          auto_sync: auto_sync.nil? ? self.auto_sync : auto_sync
        )
      end

      # Create environment-specific migrator config
      def migrator_config_for(environment : String) : CQL::MigratorConfig
        case environment
        when "production"
          migrator_config(
            schema_path: File.join(schema_dir, "production_schema.cr"),
            schema_class: :ProductionSchema,
            schema_name: :production_schema,
            migrations_table: :schema_migrations,
            auto_sync: false
          )
        when "test"
          migrator_config(
            schema_path: File.join(schema_dir, "test_schema.cr"),
            schema_class: :TestSchema,
            schema_name: :test_schema,
            migrations_table: :test_migrations,
            auto_sync: true
          )
        when "development"
          migrator_config(auto_sync: true)
        else
          migrator_config
        end
      end

      # Create a configured migrator
      def build_migrator(schema : Schema) : CQL::Migrator
        config = migrator_config
        migrator = schema.migrator(config)

        # Handle startup behaviors
        if bootstrap?
          effective_logger.info { "🚀 Bootstrapping schema from database..." }
          migrator.bootstrap_schema
        elsif verify_schema?
          unless migrator.verify_schema_consistency
            effective_logger.warn { "⚠️  Schema file is out of sync with database" }
            if auto_sync?
              effective_logger.info { "🔄 Auto-updating schema file..." }
              migrator.update_schema_file
            end
          end
        end

        migrator
      end

      # === 🎨 SQL LOGGING SETUP ===

      def setup_sql_logging : Nil
        return unless sql_logging?

        effective_logger.info { "🎨 Setting up beautiful SQL logging..." }

        CQL.enable_sql_logging do |config|
          config.enabled = true
          config.colorize_output = sql_logging_colorize
          config.async_processing = sql_logging_async

          # Smart defaults for development
          if env == "development"
            config.show_params = true
            config.show_execution_time = true
            config.highlight_slow_queries = true
          end
        end

        effective_logger.info { "✅ SQL logging ready - #{sql_logging_async ? "async" : "sync"} mode" }
      end

      # === 💾 CACHE SETUP ===

      def setup_cache_system : Nil
        return unless cache.on?

        effective_logger.info { "💾 Setting up CQL cache system..." }
        cache.setup_cache_system
        effective_logger.info { "✅ CQL cache system ready" }
      end

      # Create memory cache with current settings
      def build_memory_cache : CQL::Cache::MemoryCache
        CQL::Cache::MemoryCache.new(cache.memory_size)
      end

      # Create fragment cache with current settings
      def build_fragment_cache : CQL::Cache::FragmentCache
        memory_cache = build_memory_cache
        strategy = cache.create_invalidation_strategy
        config = cache.create_cache_interface_config
        CQL::Cache::FragmentCache.new(memory_cache, strategy, config)
      end

      # Get cache statistics
      def cache_stats : Hash(String, String | Int32 | Int64 | Float64 | Bool)
        cache.cache_statistics
      end

      # Get cache performance summary
      def cache_summary : String
        cache.performance_summary
      end

      # Reset cache statistics
      def reset_cache! : Nil
        cache.reset_cache_statistics
      end

      # === 🔧 UTILITIES ===

      # Add custom validator
      def add_validator(validator : ConfigValidator) : Nil
        @validators << validator
      end

      private def setup_smart_defaults
        @logger = Log.for("CQL::#{env.capitalize}")
        @logger.level = case env
                        when "production" then Log::Severity::Info
                        when "test"       then Log::Severity::Error
                        else                   Log::Severity::Debug
                        end
        @log_level = @logger.level
      end

      private def sync_pool_size
        # Keep pool_size and pool.size in sync
        pool.size = @pool_size
      end

      private def apply_environment_config
        strategy = EnvironmentStrategyFactory.create(env)
        strategy.apply(self)
        sync_pool_size # Re-sync after environment changes

        # Auto-enable SQL logging in development unless explicitly disabled
        if env == "development"
          @sql_logging = true unless ENV.has_key?("CQL_NO_SQL_LOG")
        end
      end
    end

    # === 🔄 CONFIGURATION MANAGEMENT ===

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

  # === 🎯 MAIN CONFIGURATION METHOD ===
  #
  # **Minimal Development Setup**
  # ```
  # CQL.configure do |c|
  #   c.db = "postgresql://localhost/myapp"
  # end
  # # Auto-enables: SQL logging
  # ```
  #
  # **Production Ready**
  # ```
  # CQL.configure do |c|
  #   c.db = ENV["DATABASE_URL"]
  #   c.env = "production"
  #   c.pool_size = 25
  #   c.sql_logging = false # Disable SQL logging
  #   c.cache.on = true     # Enable caching
  # end
  # ```
  #
  # **Custom Configuration**
  # ```
  # CQL.configure do |c|
  #   c.db = "postgresql://localhost/myapp"
  #   c.sql_logging_colorize = false # Disable colors
  #   c.cache.on = true              # Enable caching
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

  # === 🗂️ SCHEMA & MIGRATION HELPERS ===

  # Create a schema with smart defaults
  def self.build_schema(name : Symbol, &block) : Schema
    schema = Schema.define(name, config.db, config.adapter, &block)

    # Auto-setup based on configuration
    config.setup_cache_system if config.cache.on?
    config.setup_sql_logging if config.sql_logging?

    schema
  end

  # Create a migrator using current configuration
  def self.build_migrator(schema : Schema, custom_config : MigratorConfig? = nil) : Migrator
    if custom_config
      schema.migrator(custom_config)
    else
      config.build_migrator(schema)
    end
  end

  # Quick schema bootstrap from existing database
  def self.bootstrap_schema(schema : Schema) : Migrator
    migrator = build_migrator(schema)
    migrator.bootstrap_schema
    migrator
  end

  # Verify schema consistency with auto-fix option
  def self.verify_schema(schema : Schema, auto_fix : Bool = false) : Bool
    migrator = build_migrator(schema)
    consistent = migrator.verify_schema_consistency

    if !consistent && auto_fix && config.auto_sync?
      config.effective_logger.info { "🔧 Auto-fixing schema..." }
      migrator.update_schema_file
      true
    else
      consistent
    end
  end

  # Create migrator configuration
  def self.migrator_config(**args) : MigratorConfig
    config.migrator_config(**args)
  end

  # Create environment-specific migrator configuration
  def self.migrator_config_for(env : String) : MigratorConfig
    config.migrator_config_for(env)
  end

  # === 💾 CACHE HELPERS ===

  # Quick cache enable/disable
  def self.cache_on(enabled : Bool = true) : Nil
    config.cache.on = enabled
    config.setup_cache_system if enabled
  end

  # Check if cache is enabled
  def self.cache_on? : Bool
    config.cache.on?
  end

  # Get cache statistics
  def self.cache_stats : Hash(String, String | Int32 | Int64 | Float64 | Bool)
    config.cache_stats
  end

  # Get cache performance summary
  def self.cache_summary : String
    config.cache_summary
  end

  # Reset cache statistics
  def self.reset_cache! : Nil
    config.reset_cache!
  end

  # Create memory cache instance
  def self.memory_cache : CQL::Cache::MemoryCache
    config.build_memory_cache
  end

  # Create fragment cache instance
  def self.fragment_cache : CQL::Cache::FragmentCache
    config.build_fragment_cache
  end

  # === 🌐 REQUEST-SCOPED CACHING ===

  # Start request-scoped caching
  def self.start_request_cache(request_id : String? = nil) : Nil
    return unless config.cache.on? && config.cache.request_cache?
    CQL::Cache::RequestQueryCacheHelper.start_request(request_id)
  end

  # End request-scoped caching
  def self.end_request_cache : Nil
    return unless config.cache.on? && config.cache.request_cache?
    CQL::Cache::RequestQueryCacheHelper.end_request
  end

  # Execute block with request-scoped caching
  def self.with_request_cache(request_id : String? = nil, &)
    start_request_cache(request_id)
    begin
      yield
    ensure
      end_request_cache
    end
  end
end
