require "../executor"
require "./connection"

module CQL::Postgres
  # `stream` for an executor that lends one `Connection` per call (`AsyncEngine`)
  # or owns one (`TransactionScope`): the rows of a query, or of SQL with
  # arguments, as a `DB::ResultSet` that fetches *fetch_size* rows at a time.
  # Telemetry sees one statement whose duration is the whole stream. See
  # `Session#stream` for early stops, errors, cancel and timeouts.
  #
  # ```
  # engine.stream(User.query.where(active: true), fetch_size: 500) do |rows|
  #   rows.each { puts rows.read(Int64) }
  # end
  # ```
  module QueryStreaming
    def stream(query : String, args : Array(::DB::Any) = [] of ::DB::Any, fetch_size : Int32 = 1000, timeout : Time::Span? = nil, & : ::DB::ResultSet -> T) : T forall T
      CQL::Execution.run(self, query, args, :select) do |connection|
        connection.as(Connection).stream(query, args, fetch_size, timeout) { |rows| yield rows }
      end
    end

    def stream(query : Q, fetch_size : Int32 = 1000, timeout : Time::Span? = nil, & : ::DB::ResultSet -> T) : T forall Q, T
      {% unless Q.union_types.all?(&.has_method?(:to_sql)) %}
        {% raise "stream takes SQL text or a CQL query (something with #to_sql), not #{Q}" %}
      {% end %}
      sql, params = query.to_sql
      stream(sql, params, fetch_size, timeout) { |rows| yield rows }
    end
  end
end
