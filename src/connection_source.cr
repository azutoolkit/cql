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
    Log = CQL.config.logger

    # :nodoc: Called even when a schema has an active transaction frame.
    def validate! : Nil
    end

    # Lends one connection to the block and takes it back afterwards.
    abstract def using_connection(& : DB::Connection -> _)

    # Runs the block in a transaction on one connection: committed when the
    # block returns, rolled back when it raises. `DB::Rollback` rolls back
    # quietly and makes this return nil.
    def transaction(& : DB::Transaction -> _)
      using_connection { |connection| transaction_on(connection) { |transaction| yield transaction } }
    end

    # As `transaction`, after running *before_begin* on that connection (MySQL takes the transaction's modes there).
    # It opens the transaction through `using_connection`: a source that overrides `transaction` overrides this too.
    # A connection whose transaction never began is closed, so what *before_begin* left reaches no later borrower.
    def transaction(before_begin : String, & : DB::Transaction -> _)
      using_connection { |connection| transaction_on(connection, before_begin) { |transaction| yield transaction } }
    end

    # crystal-db commits in its `ensure`, and a COMMIT that raised leaves the transaction open on the connection (on
    # SQLite after BUSY or a deferred foreign key, in the database too): it ends here, before the pool lends the
    # connection again.
    private def transaction_on(connection : DB::Connection, before_begin : String? = nil, & : DB::Transaction -> _)
      begun = nil
      # `exec`, not `unprepared`: crystal-sqlite3 has no unprepared statements, and MySQL can prepare SET.
      connection.exec(before_begin) if before_begin
      connection.transaction do |transaction|
        begun = transaction
        yield transaction
      end
    rescue ex
      if begun.nil?
        connection.close if before_begin
      elsif !begun.closed?
        roll_back_or_release(begun)
      end
      raise ex
    end

    # ROLLBACK also releases crystal-db's transaction flag. When it fails (SQLite rolled back by itself after a disk
    # error, say), the flag is released without sending anything: closing the connection can fail halfway on SQLite
    # and hand the pool a connection whose statements were freed. Nothing here replaces the COMMIT's error.
    private def roll_back_or_release(transaction : DB::Transaction) : Nil
      transaction.rollback
    rescue ex
      Log.warn &.emit("ROLLBACK after a failed COMMIT failed", error: ex.class.name, error_message: ex.message.to_s)
      transaction.close
    end

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
