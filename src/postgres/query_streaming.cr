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
  # engine = CQL::Postgres::AsyncEngine.connect(ENV["DATABASE_URL"])
  # engine.stream(User.query.where(active: true), fetch_size: 500) do |rows|
  #   rows.each { puts rows.read(Int64) } # the model's columns, id first
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
      sql, params = sql_and_params(query)
      stream(sql, params, fetch_size, timeout) { |rows| yield rows }
    end

    # A query's SQL and bound values: a model's `QueryBuilder#to_sql` is the SQL text alone, so it
    # gives them through `to_sql_with_params`; a `CQL::Query#to_sql` gives both.
    private def sql_and_params(query) : {String, Array(::DB::Any)}
      query.responds_to?(:to_sql_with_params) ? query.to_sql_with_params : query.to_sql
    end
  end
end
