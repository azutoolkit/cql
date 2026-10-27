require "db"
require "./checkout_budget"
require "./pool_stats"

module CQL
  # Where a `Schema` borrows its connections and transactions from. The Schema
  # keeps the per-fiber transaction pinning and the telemetry; a source only
  # knows how to lend a connection and how to open a transaction on one.
  #
  # `DatabaseSource` (crystal-db's pool) is the default. `Postgres::EngineSource`
  # runs a schema on the native `AsyncEngine`'s pool.
  abstract class ConnectionSource
    # Lends one connection to the block and takes it back afterwards.
    abstract def using_connection(& : DB::Connection -> _)

    # Runs the block in a transaction on one connection: committed when the
    # block returns, rolled back when it raises. `DB::Rollback` rolls back
    # quietly and makes this return nil.
    abstract def transaction(& : DB::Transaction -> _)

    abstract def pool_stats : PoolStats

    abstract def close : Nil

    # The URI a `Schema` reports (`Schema#uri`), which code such as `SchemaDump` opens through crystal-db.
    def database_uri(uri : String) : String
      uri
    end

    # The adapter this source speaks, when it is bound to one (a `Schema` refuses a different one).
    def adapter : Adapter?
    end
  end

  # crystal-db's own pool, opened from the schema's URI.
  class DatabaseSource < ConnectionSource
    def initialize(@db : DB::Database)
    end

    # Skips connections found closed at checkout (bounded, see `checkout_open`), all within one `CheckoutBudget`.
    # Nothing is retried once the block started: a statement whose reply was lost may have run.
    def using_connection(& : DB::Connection -> _)
      connection = CheckoutBudget.within { checkout_open }
      begin
        yield connection
      ensure
        connection.release
      end
    end

    def transaction(& : DB::Transaction -> _)
      using_connection { |connection| connection.transaction { |transaction| yield transaction } }
    end

    def pool_stats : PoolStats
      PoolStats.from(@db.pool.stats)
    end

    def close : Nil
      @db.close
    end

    # A driver may find at checkout that the server ended an idle connection (`Postgres::Connection#before_checkout`
    # closes it). Releasing a closed connection drops it from the pool; every other idle one may be dead too (a
    # server restart), so the bound is those plus one new connection. The last one is lent whatever its state.
    private def checkout_open : DB::Connection
      connection = @db.checkout
      return connection unless connection.closed?
      (@db.pool.stats.idle_connections + 1).times do
        connection.release
        connection = @db.checkout
        break unless connection.closed?
      end
      connection
    end
  end
end
