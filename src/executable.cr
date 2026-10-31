require "./executor"

module CQL
  # Runs a statement that renders to `{sql, params}`. Result caching,
  # performance tracking and connection handling live here once, for every
  # query type that can be executed.
  module Executable
    include Pinnable

    abstract def build : Expression::Statement

    # The SQL text and its bound parameters, rendered for the schema's dialect
    # (or by the given generator).
    def to_sql(gen : Expression::Generator? = nil)
      render(build, gen)
    end

    # Renders an already built statement to SQL and bound values.
    protected def render(statement : Expression::Statement, gen : Expression::Generator? = nil)
      generator = gen || schema.new_generator
      generator.reset
      statement.accept(generator)
      {generator.query, generator.params}
    end

    # Renders for another dialect without needing a connection to it.
    def to_sql(for adapter : Adapter)
      to_sql(Expression::Generator.new(adapter, schema.quote_identifiers))
    end

    # The database's execution plan for this statement, one line per plan row.
    # With `analyze: true` the statement is actually run and timed.
    def explain(analyze : Bool = false) : String
      sql, params = to_sql
      dialect = schema.dialect
      explain_sql = dialect.explain(sql, analyze)
      # Plans are diagnostics: not cached, and not counted as application queries.
      CQL::Execution.run(executor, explain_sql, params, :explain, track: false) do |connection|
        connection.query(explain_sql, args: params) do |rows|
          lines = [] of String
          rows.each { lines << dialect.format_plan_row(Array.new(rows.column_count) { rows.read.to_s }) }
          lines.join("\n")
        end
      end
    end

    # All rows, each mapped to *kind*.
    def all(as kind)
      execute { |conn, sql, params| conn.query_all(sql, args: params, as: kind).map! { |row| contextualize(row) } }
    end

    # UUIDs may arrive as native values or text, depending on the adapter.
    def all(as kind : UUID.class) : Array(UUID)
      all(as: UUID | String).map { |value| value.is_a?(UUID) ? value : UUID.new(value) }
    end

    def get(as kind : UUID.class) : UUID?
      value = get(as: UUID | String)
      value.is_a?(String) ? UUID.new(value) : value
    end

    def all!(as kind)
      all(kind).not_nil!
    end

    # The first row (or scalar) mapped to *kind*, nil when there is none.
    def get(as kind)
      execute { |conn, sql, params| contextualize(conn.query_one?(sql, args: params, as: kind)) }
    end

    # Like `get`, but raises `DB::NoResultsError` when there is no row.
    def get!(as kind)
      result = get(kind)
      raise DB::NoResultsError.new("The query returned no row") if result.nil?
      result
    end

    # Whether the statement returns at least *count* rows. Steps through at most
    # *count* rows without reading a column, so nothing is decoded.
    def returns_rows?(count : Int32) : Bool
      execute do |conn, sql, params|
        conn.query(sql, args: params) do |rows|
          seen = 0
          while seen < count && rows.move_next
            seen += 1
          end
          seen == count
        end
      end
    end

    # Yields each row mapped to *kind*. The rows are read first and the connection released
    # before the block runs, so the block may run other queries; use `find_each` for large results.
    def each(as kind : U.class, & : U ->) : Nil forall U
      all(kind).each { |record| yield record }
    end

    protected def contextualize(record : U) : U forall U
      if record.responds_to?(:with_binding)
        record.with_binding(schema.binding)
      else
        record
      end
    end

    private def execute(&)
      sql, params = to_sql
      CQL::Cache::RequestQueryCacheHelper.with_cache(sql, params) do
        CQL::Execution.run(executor, sql, params, :select) { |connection| yield connection, sql, params }
      end
    end
  end
end
