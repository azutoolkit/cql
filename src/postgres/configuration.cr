module CQL::Postgres
  # Runtime environment, used for the default database name and the production guards.
  enum Environment
    Development
    Test
    Production

    def self.detect : Environment
      value = ENV["CQL_ENV"]? || ENV["APP_ENV"]? || "development"
      parse?(value) || Development
    end
  end

  # Settings for the PostgreSQL layer. Only `url` is ever needed; everything else has a
  # sensible default. The URL is resolved from, in order: `url`, `DATABASE_URL`,
  # `PG*` variables, and finally the convention `postgres://localhost/<app>_<env>`.
  class Configuration
    # What to do when an association is read without having been preloaded.
    enum NPlusOne
      Off
      Warn
      Raise
    end

    # Connection URL, e.g. "postgres://user:pass@localhost:5432/app_development".
    property url : String? = nil
    # Maximum connections in the pool (appended to the URL as `max_pool_size`).
    property pool_size : Int32? = ENV["CQL_DB_POOL"]?.try(&.to_i?)
    # Seconds to wait for a free connection (appended to the URL as `checkout_timeout`).
    property checkout_timeout : Float64? = ENV["CQL_DB_CHECKOUT_TIMEOUT"]?.try(&.to_f?)
    # Association access without preload: `Off`, `Warn` (log) or `Raise`.
    property n_plus_one : NPlusOne = NPlusOne.parse?(ENV.fetch("CQL_DB_N_PLUS_ONE", "off")) || NPlusOne::Off
    # Queries slower than this (ms) are logged as warnings; 0 disables the check.
    property slow_query_ms : Float64 = ENV.fetch("CQL_DB_SLOW_QUERY_MS", "0").to_f? || 0.0
    property env : Environment = Environment.detect
    # Receives migration progress, slow-query and N+1 warnings, connection notices.
    property log : ::Log = ::Log.for("cql.postgres")
  end

  @@config = Configuration.new

  def self.config : Configuration
    @@config
  end

  def self.config=(config : Configuration) : Configuration
    @@config = config
  end

  # ```
  # CQL::Postgres.configure { |c| c.url = ENV["DATABASE_URL"] }
  # ```
  def self.configure(& : Configuration ->) : Configuration
    yield @@config
    @@config
  end
end
