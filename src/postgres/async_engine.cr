require "../executor"
require "./pool"
require "./pipeline_result"

module CQL::Postgres
  # Runs CQL statements over the native wire driver, with a connection pool.
  # It is an `Executor`, so any statement can be pointed at it:
  #
  # ```
  # engine = CQL::Postgres::AsyncEngine.connect("postgres://app:secret@db/app?pool_size=10")
  # User.query.where(active: true).using(engine).to_a
  # AppDB.query.from(:users).select(:name).using(engine).all(as: String)
  # engine.transaction { |tx| AppDB.insert.into(:users).values(name: "ada").using(tx).commit }
  # ```
  #
  # Statements run through `CQL::Execution`, so telemetry and performance
  # tracking see them like any other.
  class AsyncEngine
    include CQL::Executor

    getter adapter : CQL::Adapter
    getter pool : Pool

    def self.connect(url : String, adapter : CQL::Adapter = CQL::Adapter::Postgres) : AsyncEngine
      new(Pool.new(Config.parse(url)), adapter)
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
    # which makes this return nil). The yielded executor pins statements to
    # that connection: `query.using(tx)`.
    def transaction(& : CQL::ConnectionExecutor -> T) : T? forall T
      with_connection do |connection|
        connection.transaction { |_| yield CQL::ConnectionExecutor.new(@adapter, connection) }
      end
    end

    # Sends several queries in one network round trip (see `Session#pipeline`).
    # Each query is observed by telemetry like any other (the first one's
    # duration covers the whole round trip); one failing leaves the others
    # unaffected and appears as its `ServerError` in the returned array.
    #
    # ```
    # users, orders = engine.pipeline([User.query_sql, Order.query_sql])
    # users.as(CQL::Postgres::PipelineResult).all(as: User)
    # ```
    def pipeline(queries : Array(Q)) : Array(PipelineResult | ServerError) forall Q
      pipeline(queries.map { |query| sql, params = query.to_sql; {sql, params} })
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
      CQL::Execution.run(self, sql, args, :ddl, track: false) do |connection|
        args.empty? ? connection.unprepared.exec(sql) : connection.exec(sql, args: args)
      end
    end

    def close : Nil
      @pool.close
    end

    private def operation_of(sql : String) : Symbol
      case sql.lstrip[0, 6].downcase
      when "insert" then :insert
      when "update" then :update
      when "delete" then :delete
      else               :select
      end
    end

    private def pipelined_statement(pinned, connection : Connection, batch : LazyBatch, sql : String, params : Array(::DB::Any), index : Int32) : PipelineResult | ServerError
      outcome = CQL::Execution.run(pinned, sql, params, operation_of(sql), track: false) do |_|
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
        @connection.pipeline(@statements.map { |(sql, params)| {sql, params.map { |value| Types::ParamEncoder.encode(value) }} })
      end
    end
  end
end
