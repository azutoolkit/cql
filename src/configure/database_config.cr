module CQL::Configure
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
end
