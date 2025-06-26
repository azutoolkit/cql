module CQL::Configure
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
end
