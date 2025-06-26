module CQL::Configure
  # Configuration validator using Strategy pattern
  abstract class ConfigValidator
    abstract def validate!(config : Config) : Nil
  end

  class BasicConfigValidator < ConfigValidator
    def validate!(config : Config) : Nil
      raise ArgumentError.new("database_url cannot be empty") if config.database_url.empty?
      raise ArgumentError.new("schema_path cannot be empty") if config.schema_path.empty?
      raise ArgumentError.new("schema_file_name cannot be empty") if config.schema_file_name.empty?

      unless [:utc, :local].includes?(config.default_timezone)
        raise ArgumentError.new("default_timezone must be :utc or :local")
      end

      unless config.schema_file_name.ends_with?(".cr")
        raise ArgumentError.new("schema_file_name must end with .cr extension")
      end
    end
  end
end
