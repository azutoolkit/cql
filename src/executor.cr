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

  # The one place a statement is actually executed: it is timed once, and that
  # measurement feeds telemetry (events, tracing) and the performance monitor.
  module Execution
    def self.run(executor : Executor, sql : String, params : Array(DB::Any), operation : Symbol, track : Bool = true, &)
      monitor = CQL::Performance.monitor if track
      monitor = nil unless monitor.try &.enabled?
      unless Telemetry.observing? || monitor
        return Telemetry.in_span(operation, sql) { executor.exec_query { |connection| yield connection } }
      end

      started = Time.instant
      connected = nil
      begin
        result = Telemetry.in_span(operation, sql) do
          executor.exec_query do |connection|
            connected = Time.instant
            yield connection
          end
        end
      rescue ex
        report(executor.adapter, operation, sql, params, started, connected, ex, nil, monitor)
        raise ex
      end
      report(executor.adapter, operation, sql, params, started, connected, nil, result, monitor)
      result
    end

    # A statement whose connection never arrived waited for it until it failed.
    private def self.report(adapter, operation, sql, params, started, connected, error, result, monitor) : Nil
      finished = Time.instant
      event = Telemetry.query_event(adapter, operation, sql, params, finished - started, error, result, (connected || finished) - started)
      Telemetry.publish(event)
      monitor.try &.record(event, params)
    end
  end
end
