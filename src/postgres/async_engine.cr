require "../executor"
require "./pool"
require "../operation_kind"
require "./query_streaming"
require "./transaction_scope"
require "./pipeline_result"

module CQL::Postgres
  # Runs CQL statements over the native wire driver, with a connection pool.
  # It is an `Executor`, so any statement can be pointed at it:
  #
  # ```
  # engine = CQL::Postgres::AsyncEngine.connect("postgres://app:secret@db/app?pool_size=10")
  # User.query.where(active: true).using(engine).to_a
  # engine.transaction { |tx| User.query.where(name: "Ada").using(tx).to_a }
  # engine.exec("INSERT INTO notes (body) VALUES ($1)", ["first".as(DB::Any)])
  # ```
  #
  # `using(engine)` changes where a statement runs, not its SQL, so the statement's schema must
  # use a PostgreSQL or CockroachDB adapter.
  #
  # Statements run through `CQL::Execution`, so telemetry and performance
  # tracking see them like any other.
  class AsyncEngine
    include CQL::Executor
    include QueryStreaming

    getter adapter : CQL::Adapter
    getter pool : Pool

    # *setup* runs once on every new pooled connection (e.g. `SET search_path`);
    # *reset* is a statement run each time a connection returns to the pool
    # (e.g. `DISCARD ALL`). Pool sizing and lifetimes come from the URL:
    # `pool_size`, `pool_min_size`, `max_queries`, `max_idle_lifetime`.
    # The adapter defaults from the URL: `cockroachdb://` is CockroachDB, anything else PostgreSQL.
    def self.connect(url : String, adapter : CQL::Adapter? = nil,
                     setup : Proc(Connection, Nil)? = nil, reset : String? = nil) : AsyncEngine
      config = Config.parse(url)
      adapter ||= config.cockroachdb? ? CQL::Adapter::CockroachDB : CQL::Adapter::Postgres
      options = Pool::Options.from(config).copy_with(setup: setup, reset_sql: reset)
      new(Pool.new(config, options).warm_up, adapter)
    end

    def initialize(@pool : Pool, @adapter : CQL::Adapter = CQL::Adapter::Postgres)
      raise ArgumentError.new("#{@adapter} does not speak the PostgreSQL protocol") unless @adapter.postgres? || @adapter.cockroach_db?
    end

    def exec_query(& : ::DB::Connection -> _)
      with_connection { |connection| yield connection }
    end

    # One pooled connection for the block, returned afterwards.
    def with_connection(& : Connection -> T) : T forall T
      @pool.with_connection { |connection| yield connection }
    end

    # Runs the block inside BEGIN/COMMIT on one connection; it is rolled back
    # when the block raises (raise `DB::Rollback` to roll back without an error,
    # which makes this return nil). The yielded scope pins statements to that
    # connection (`query.using(tx)`) and offers `tx.savepoint { ... }`.
    #
    # ```
    # engine = CQL::Postgres::AsyncEngine.connect(ENV["DATABASE_URL"])
    # engine.transaction(isolation: :serializable, read_only: true, deferrable: true) { |tx| User.query.using(tx).to_a }
    # engine.transaction(synchronous_commit: false) do |tx| # SET LOCAL: this commit may be lost in a crash
    #   tx.savepoint { |inner| User.query.where(name: "Ada").using(inner).to_a }
    # end
    # ```
    #
    # `synchronous_commit: false` makes the commit return before the WAL is
    # flushed: the database stays consistent, but the most recent commits
    # (about three `wal_writer_delay`s' worth) can vanish if the server
    # crashes. `true` forces `on` (overriding e.g. `remote_apply`); the default
    # follows the server's setting.
    def transaction(isolation : IsolationLevel? = nil, read_only : Bool = false, deferrable : Bool = false,
                    synchronous_commit : Bool? = nil, & : TransactionScope -> T) : T? forall T
      raise ArgumentError.new("CockroachDB does not support deferrable transactions") if deferrable && @adapter.cockroach_db?
      with_connection do |connection|
        connection.transaction do |transaction|
          apply_transaction_options(connection, isolation, read_only, deferrable, synchronous_commit)
          scope = TransactionScope.new(@adapter, connection, transaction)
          begin
            yield scope
          ensure
            scope.finish
          end
        end
      end
    end

    # Sends several queries in one network round trip (see `Session#pipeline`).
    # Each query is observed by telemetry like any other (the first one's
    # duration covers the whole round trip); one failing leaves the others
    # unaffected and appears as its `ServerError` in the returned array.
    #
    # ```
    # engine = CQL::Postgres::AsyncEngine.connect(ENV["DATABASE_URL"])
    # users, posts = engine.pipeline([User.query.where(active: true), Post.query])
    # users.as(CQL::Postgres::PipelineResult).all(as: User)
    # ```
    def pipeline(queries : Array(Q)) : Array(PipelineResult | ServerError) forall Q
      pipeline(queries.map { |query| sql_and_params(query) })
    end

    def pipeline(statements : Array({String, Array(::DB::Any)})) : Array(PipelineResult | ServerError)
      return [] of PipelineResult | ServerError if statements.empty?
      with_connection do |connection|
        batch = LazyBatch.new(connection, statements)
        pinned = CQL::ConnectionExecutor.new(@adapter, connection)
        statements.map_with_index do |(sql, params), index|
          pipelined_statement(pinned, connection, batch, sql, params, index)
        end
      end
    end

    # Runs raw SQL (no rows wanted) as a telemetry-observed statement.
    # Without arguments the text may be a script of several statements.
    def exec(sql : String, args : Array(::DB::Any) = [] of ::DB::Any) : ::DB::ExecResult
      CQL::Execution.run(self, sql, args, CQL::OperationKind.of(sql), track: false) do |connection|
        args.empty? ? connection.unprepared.exec(sql) : connection.exec(sql, args: args)
      end
    end

    def close : Nil
      @pool.close
    end

    # Must run before the transaction's first query.
    private def apply_transaction_options(connection : Connection, isolation : IsolationLevel?, read_only : Bool, deferrable : Bool, synchronous_commit : Bool?) : Nil
      modes = [] of String
      modes << "ISOLATION LEVEL #{isolation.to_sql}" if isolation
      modes << "READ ONLY" if read_only
      modes << "DEFERRABLE" if deferrable
      connection.unprepared.exec("SET TRANSACTION #{modes.join(", ")}") unless modes.empty?
      connection.unprepared.exec("SET LOCAL synchronous_commit TO #{synchronous_commit ? "on" : "off"}") unless synchronous_commit.nil?
    end

    private def pipelined_statement(pinned, connection : Connection, batch : LazyBatch, sql : String, params : Array(::DB::Any), index : Int32) : PipelineResult | ServerError
      outcome = CQL::Execution.run(pinned, sql, params, CQL::OperationKind.of(sql), track: false) do |_|
        batch.outcome(index).tap { |result| raise result if result.is_a?(ServerError) }
      end
      PipelineResult.new(outcome.as(Result), Statement.new(connection, sql, prepared: true))
    rescue error : ServerError
      error
    end

    # Sends the whole pipeline when the first statement's outcome is asked for,
    # so that statement's telemetry event covers the round trip.
    private class LazyBatch
      def initialize(@connection : Connection, @statements : Array({String, Array(::DB::Any)}))
        @outcomes = nil.as(Array(Result | ServerError)?)
      end

      def outcome(index : Int32) : Result | ServerError
        (@outcomes ||= send_all)[index]
      end

      private def send_all : Array(Result | ServerError)
        @connection.pipeline(@statements.map { |(sql, params)| {sql, params.map { |value| @connection.session.encode(value) }} })
      end
    end
  end
end
