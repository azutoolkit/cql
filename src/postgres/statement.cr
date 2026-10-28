require "db"
require "./result_set"

module CQL::Postgres
  # A statement on a `Connection`. Prepared ones are parsed once per
  # connection and reused; unprepared ones use the unnamed statement, or the
  # simple protocol when there are no parameters and no rows are wanted.
  class Statement < ::DB::Statement
    def initialize(connection : ::DB::Connection, command : String, @prepared : Bool)
      super(connection, command)
    end

    protected def perform_query(args : Enumerable) : ::DB::ResultSet
      ResultSet.new(self, run(args))
    end

    protected def perform_exec(args : Enumerable) : ::DB::ExecResult
      rows_affected = simple?(args) ? simple_rows_affected : run(args).rows_affected
      ::DB::ExecResult.new(rows_affected: rows_affected, last_insert_id: 0_i64)
    end

    # crystal-db logs every bound value at Debug; values are personal data, so only the count unless opted in.
    protected def emit_log(args : Enumerable)
      return super if CQL::Telemetry.capture_params
      ::DB::Log.debug &.emit("Executing query", query: command, args_count: args.size)
    end

    # Only a request refused before anything was sent becomes `DB::ConnectionLost`, which crystal-db's pool runs
    # again on another connection; any other lost connection may have run the statement, so it is not retried.
    private def run(args : Enumerable) : Result
      session = connection.as(Connection).session
      params = [] of Types::Param
      args.each { |arg| params << session.encode(arg) }
      session.query(command, params, cache: @prepared)
    rescue ex : ConnectionClosed
      raise ::DB::ConnectionLost.new(connection, cause: ex)
    end

    private def simple?(args : Enumerable) : Bool
      !@prepared && args.none?
    end

    private def simple_rows_affected : Int64
      connection.as(Connection).session.simple_query(command).last?.try(&.rows_affected) || 0_i64
    rescue ex : ConnectionClosed
      raise ::DB::ConnectionLost.new(connection, cause: ex)
    end
  end
end
