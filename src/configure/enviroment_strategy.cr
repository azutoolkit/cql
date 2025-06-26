module CQL::Configure
  # Environment configuration strategy using Strategy pattern
  abstract class EnvironmentStrategy
    abstract def apply(config : Config) : Nil
  end

  class ProductionStrategy < EnvironmentStrategy
    def apply(config : Config) : Nil
      config.auto_load_models = false
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
      config.migration_table_name = :test_schema_migrations
      config.auto_load_models = false
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
end
