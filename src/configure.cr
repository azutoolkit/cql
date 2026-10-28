require "log"
require "mutex"
require "./compat"
require "./migrations"
require "./cache/*"
require "./configure/*"

module CQL
  # Centralized configuration for CQL.
  #
  # Quick setup for different environments:
  #
  # **Development** (run with `CRYSTAL_ENV=development` to get SQL logging)
  # ```
  # CQL.configure do |config|
  #   config.db = "postgresql://localhost/myapp"
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
  #   config.sql_logging_colorize = false # Plain SQL logging output
  # end
  # ```
  module Configure
    # Thread-safe mutex for configuration access
    @@config_mutex = CQL::Compat::Mutex.new
    @@config_instance : Config? = nil

    # The settings `CQL.configure` yields. Read them back with `CQL.config`.
    class Config
      # Primary database connection URL
      property db : String = "sqlite3://./db/development.db"

      # Environment (auto-detects from CRYSTAL_ENV; unset means development)
      getter env : String = ENV["CRYSTAL_ENV"]? || "development"

      # Whether the environment was named (CRYSTAL_ENV or `env=`) rather than defaulted.
      @env_named : Bool = ENV.has_key?("CRYSTAL_ENV")

      def env=(value : String)
        @env = value
        @env_named = true
      end

      # Timezone for date/time operations
      property timezone : Symbol = :utc

      # Custom database adapter settings
      property adapter_options : Hash(String, String) = Hash(String, String).new

      # Main application logger
      property logger : Log = Log.for("cql.*")

      # Shortcut for log level (maps to logger.level)
      property log_level : Log::Severity = Log::Severity::Info

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

      # Auto-load model files on startup
      property auto_load : Bool = true

      # Keep schema file in sync with database
      property auto_sync : Bool = true

      # Create schema from existing database on first run
      property bootstrap : Bool = false

      # Verify schema matches database on startup
      property verify_schema : Bool = false

      # Enable SQL logging (on by default when CRYSTAL_ENV=development or `env = "development"`)
      @sql_logging : Bool?

      def sql_logging=(@sql_logging : Bool?)
      end

      def sql_logging : Bool
        sql_logging?
      end

      # SQL logging options
      property sql_logging_colorize : Bool = true # Colorize SQL output
      property sql_logging_async : Bool = false   # Unused: kept for compatibility

      # Enable performance monitoring and tracking
      property monitor_performance : Bool = false

      # Centralized cache configuration (use config.cache.* to configure)
      getter cache : CacheConfig = CacheConfig.new

      # Number of database connections in pool
      getter pool_size : Int32 = 10

      def pool_size=(size : Int32)
        @pool_size = size
        pool.size = size
        return unless size.positive?

        pool.initial_size = Math.min(pool.initial_size, size)
        pool.max_idle_size = Math.min(pool.max_idle_size, size)
      end

      # Detailed connection pool settings
      getter pool : ConnectionPoolConfig = ConnectionPoolConfig.new

      # SSL/TLS configuration
      getter ssl : SSLConfig = SSLConfig.new

      getter postgres : PostgreSQLConfig = PostgreSQLConfig.new
      getter mysql : MySQLConfig = MySQLConfig.new
      getter sqlite : SQLiteConfig = SQLiteConfig.new

      @validators = [BasicConfigValidator.new] of ConfigValidator

      def initialize
        setup_smart_defaults
        sync_pool_size
        apply_environment_config
      end

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
        explicit = @sql_logging
        explicit.nil? ? development_logging_default? : explicit
      end

      private def development_logging_default? : Bool
        @env_named && env == "development" && !ENV.has_key?("CQL_NO_SQL_LOG")
      end

      # Check if performance monitoring is enabled
      def monitor_performance? : Bool
        @monitor_performance
      end

      # Get the database adapter type
      def adapter : Adapter
        case db
        when .starts_with?("postgresql://"), .starts_with?("postgres://")
          Adapter::Postgres
        when .starts_with?("cockroachdb://")
          Adapter::CockroachDB
        when .starts_with?("mysql://")
          Adapter::MySql
        when .starts_with?("sqlite3:")
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
        when Adapter::Postgres, Adapter::CockroachDB then postgres
        when Adapter::MySql                          then mysql
        when Adapter::SQLite                         then sqlite
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

      def validate! : Nil
        @validators.each(&.validate!(self))
        pool.validate!(adapter)
        warn_unread_query_timeout
        ssl.validate!
        db_config.validate!
        cache.validate!
      end

      # The pg shard, when linked, takes postgres:// and ignores query_timeout: statements would run unbounded.
      private def warn_unread_query_timeout : Nil
        return unless pool.query_timeout && adapter.postgres_compatible?
        reason = CQL::Postgres::Driver.unread_query_timeout(URI.parse(adapter.driver_uri(db)).scheme.to_s)
        effective_logger.warn { "pool.#{reason}" } if reason
      end

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

      def setup_sql_logging : Nil
        return unless sql_logging?

        effective_logger.info { "🎨 Setting up beautiful SQL logging..." }

        CQL::Performance.enable_sql_logging(colorize: sql_logging_colorize)

        effective_logger.info { "✅ SQL logging ready" }
      end

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

  # **Minimal Development Setup**
  # ```
  # CQL.configure do |c|
  #   c.db = "postgresql://localhost/myapp"
  # end
  # # With CRYSTAL_ENV=development this also turns on SQL logging
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
    CQL::Performance.enable_monitoring if config.monitor_performance?
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

  # Create a schema with smart defaults
  def self.build_schema(name : Symbol, &) : Schema
    schema = Schema.new(name, config.full_db_url, config.adapter)
    with schema yield

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

  # Whether the schema file matches the database; with `auto_fix` (and `auto_sync`) a stale file is
  # rewritten instead. Uses a plain migrator: `build_migrator` rewrites a stale file before the check
  # when `verify_schema` and `auto_sync` are on.
  def self.verify_schema(schema : Schema, auto_fix : Bool = false) : Bool
    migrator = schema.migrator(config.migrator_config)
    return true if migrator.verify_schema_consistency
    return false unless auto_fix && config.auto_sync?

    config.effective_logger.info { "🔧 Auto-fixing schema..." }
    migrator.update_schema_file
    true
  end

  # Create migrator configuration
  def self.migrator_config(**args) : MigratorConfig
    config.migrator_config(**args)
  end

  # Create environment-specific migrator configuration
  def self.migrator_config_for(env : String) : MigratorConfig
    config.migrator_config_for(env)
  end

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

  # Whether request-scoped caching starts requests: `cache.on` and `cache.request_cache`.
  def self.request_cache_tracking? : Bool
    config.cache.on? && config.cache.request_cache?
  end

  # Start request-scoped caching
  def self.start_request_cache(request_id : String? = nil) : Nil
    return unless request_cache_tracking?
    CQL::Cache::RequestQueryCacheHelper.start_request(request_id)
  end

  # End request-scoped caching. Not gated on the switches, so a request started before one of them was turned
  # off still ends; on a fiber without a request it does nothing. With the switches off it still ends a request
  # someone else started on this fiber: prefer `with_request_cache`, which ends only what it started.
  def self.end_request_cache : Nil
    CQL::Cache::RequestQueryCacheHelper.end_request
  end

  # Execute block with request-scoped caching. The switches are read once: the block's request is started and
  # ended only when they were on at the start, so a request started outside the block is never ended by it.
  def self.with_request_cache(request_id : String? = nil, &)
    tracking = request_cache_tracking?
    CQL::Cache::RequestQueryCacheHelper.start_request(request_id) if tracking
    begin
      yield
    ensure
      CQL::Cache::RequestQueryCacheHelper.end_request if tracking
    end
  end
end
