require "../connection_source"
require "./async_engine"
require "./refusal"

module CQL::Postgres
  # Runs a `CQL::Schema` on an `AsyncEngine`'s pool: models, queries, migrations,
  # `schema.transaction` and `schema.with_connection` use the engine's
  # fiber-safe pool, statement cache and health checks without `using(engine)`.
  #
  # ```
  # SOURCE = CQL::Postgres::EngineSource.connect("postgres://app@db/app?pool_size=10")
  #
  # AppDB = CQL::Schema.define(:app, "postgres://app@db/app", CQL::Adapter::Postgres, source: SOURCE) do
  #   table :users do
  #     primary :id, Int64, auto_increment: true
  #     text :name
  #   end
  # end
  #
  # SOURCE.engine.pipeline([AppDB.query.from(:users).select(:name)]) # the engine's own API stays reachable
  # ```
  #
  # A connection that cannot be opened raises `DB::ConnectionRefused` and a saturated pool `DB::PoolTimeout` (the
  # engine itself raises the underlying `IO::Error` and `CQL::Postgres::PoolTimeout`, kept as `cause`). crystal-db's
  # pool raises `DB::ConnectionRefused` only for the first connect and `DB::PoolRetryAttemptsExceeded` for a lazy one,
  # so code rescuing that class will not match here. A closed pool raises `CQL::Postgres::PoolClosed`. The engine
  # does not retry connects.
  # Closing the source closes the engine for every schema that shares it.
  class EngineSource < ConnectionSource
    getter engine : AsyncEngine

    def self.connect(url : String, adapter : CQL::Adapter? = nil,
                     setup : Proc(Connection, Nil)? = nil, reset : String? = nil) : EngineSource
      new(Refusal.translate { AsyncEngine.connect(url, adapter, setup, reset) })
    end

    def initialize(@engine : AsyncEngine)
    end

    def adapter : CQL::Adapter?
      @engine.adapter
    end

    def using_connection(& : ::DB::Connection -> _)
      connection = checkout
      begin
        yield connection
      ensure
        connection.release
      end
    end

    def transaction(& : ::DB::Transaction -> _)
      using_connection { |connection| connection.transaction { |transaction| yield transaction } }
    end

    def pool_stats : PoolStats
      stats = @engine.pool.stats
      PoolStats.new(stats.in_use + stats.idle, stats.idle, stats.in_use, stats.max_size)
    end

    # The URL without the engine's pool options (`pool_size`, `max_queries`, ...), for code that opens a second
    # connection from `Schema#uri` through crystal-db (`SchemaDump`). Connection settings (`sslmode`,
    # `max_protocol_version`, `binary_params`, ...) stay: that driver honours them too. It must name the same server
    # as the engine.
    def database_uri(uri : String) : String
      base, marker, fragment = uri.partition('#')
      location, _, query = base.partition('?')
      kept = query.split('&', remove_empty: true).reject { |pair| Config::POOL_OPTION_KEYS.includes?(URI.decode(pair.partition('=')[0])) }
      kept.empty? ? "#{location}#{marker}#{fragment}" : "#{location}?#{kept.join('&')}#{marker}#{fragment}"
    end

    def close : Nil
      @engine.close
    end

    private def checkout : Connection
      Refusal.translate(log: false) { @engine.pool.checkout }
    rescue ex : PoolTimeout
      raise ::DB::PoolTimeout.new(ex.message, cause: ex)
    end
  end
end
