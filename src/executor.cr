require "./telemetry"

module CQL
  # Where statements run: a `Schema` (a pooled connection, or the current
  # fiber's transaction) or one pinned connection.
  module Executor
    abstract def adapter : Adapter
    abstract def exec_query(& : DB::Connection -> _)
  end

  # Runs everything on one specific connection, e.g. inside a transaction that
  # was started on it.
  class ConnectionExecutor
    include Executor

    getter adapter : Adapter

    def initialize(@adapter : Adapter, @connection : DB::Connection)
    end

    def exec_query(& : DB::Connection -> _)
      yield @connection
    end
  end

  # Lets a statement run on an explicit connection or executor:
  # `query.using(connection)`, `query.using(engine)`.
  module Pinnable
    @executor : Executor? = nil

    abstract def schema : Schema

    def using(connection : DB::Connection) : self
      using(ConnectionExecutor.new(schema.adapter, connection))
    end

    def using(executor : Executor) : self
      @executor = executor
      self
    end

    def executor : Executor
      @executor || schema
    end

    protected def executor=(value : Executor?)
      @executor = value
    end
  end

  # The one place a statement is actually executed: performance tracking and
  # telemetry (events, tracing) happen here for every kind of statement.
  module Execution
    def self.run(executor : Executor, sql : String, params : Array(DB::Any), operation : Symbol, track : Bool = true, &)
      Telemetry.observe(executor.adapter, operation, sql, params) do
        if track
          CQL::Performance.track(sql, params) { executor.exec_query { |connection| yield connection } }
        else
          executor.exec_query { |connection| yield connection }
        end
      end
    end
  end
end
