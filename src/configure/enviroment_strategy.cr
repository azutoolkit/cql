module CQL::Configure
  # Environment configuration strategy using Strategy pattern
  abstract class EnvironmentStrategy
    abstract def apply(config : Config) : Nil
  end

  class ProductionStrategy < EnvironmentStrategy
    def apply(config : Config) : Nil
      # === 📊 PERFORMANCE & SCALING ===
      config.auto_load = false
      config.pool_size = 25
      config.pool.size = 25
      config.pool.initial_size = 5
      config.pool.max_idle_size = 10
      config.pool.checkout_timeout = 15.seconds
      config.pool.max_retry_attempts = 5
      config.ssl.mode = "require"

      # === 🗂️ SCHEMA MANAGEMENT ===
      config.auto_sync = false
      config.verify_schema = true
      config.bootstrap = false

      # === 📋 LOGGING ===
      config.log_level = Log::Severity::Info
    end
  end

  class TestStrategy < EnvironmentStrategy
    def apply(config : Config) : Nil
      # === 🔌 DATABASE ===
      config.db = "sqlite3://:memory:"
      config.migrations_table = :test_migrations

      # === ⚡ BEHAVIOR ===
      config.auto_load = false
      config.pool_size = 1
      config.pool.size = 1
      config.pool.initial_size = 1
      config.pool.max_idle_size = 1
      config.sqlite.journal_mode = "memory"

      # === 🗂️ SCHEMA ===
      config.schema_file = "test_schema.cr"
      config.schema_class = :TestSchema
      config.schema_name = :test_schema
      config.auto_sync = true
      config.bootstrap = false
      config.verify_schema = false

      # === 📋 LOGGING ===
      config.log_level = Log::Severity::Error
    end
  end

  class DevelopmentStrategy < EnvironmentStrategy
    def apply(config : Config) : Nil
      # === 📊 PERFORMANCE ===
      config.pool_size = 5
      config.pool.size = 5
      config.pool.initial_size = 2
      config.pool.max_idle_size = 3
      config.sqlite.journal_mode = "wal"

      # === 🗂️ SCHEMA ===
      config.auto_sync = true
      config.verify_schema = true
      config.bootstrap = false

      # === 📋 LOGGING ===
      config.log_level = Log::Severity::Debug
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
