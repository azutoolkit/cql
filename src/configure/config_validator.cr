module CQL::Configure
  # Configuration validator using Strategy pattern
  abstract class ConfigValidator
    abstract def validate!(config : Config) : Nil
  end

  class BasicConfigValidator < ConfigValidator
    def validate!(config : Config) : Nil
      # === 🔌 DATABASE VALIDATION ===
      raise ArgumentError.new("db (database_url) cannot be empty") if config.db.empty?

      # === 🗂️ SCHEMA VALIDATION ===
      raise ArgumentError.new("schema_dir cannot be empty") if config.schema_dir.empty?
      raise ArgumentError.new("schema_file cannot be empty") if config.schema_file.empty?

      unless [:utc, :local].includes?(config.timezone)
        raise ArgumentError.new("timezone must be :utc or :local")
      end

      unless config.schema_file.ends_with?(".cr")
        raise ArgumentError.new("schema_file must end with .cr extension")
      end

      # === 🔗 CONNECTION POOL VALIDATION ===
      if config.pool_size <= 0
        raise ArgumentError.new("pool_size must be positive")
      end
    end
  end
end
