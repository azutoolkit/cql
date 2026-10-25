require "./executable"

module CQL
  # A SELECT whose SQL text was rendered once and is run again with new bound values. It goes
  # through the same execution path as any query (telemetry, monitor, request cache, transactions).
  struct PreparedSelect
    include Executable

    getter schema : Schema

    def initialize(@schema : Schema, @sql : String, @params : Array(DB::Any))
    end

    def to_sql(gen : Expression::Generator? = nil)
      {@sql, @params}
    end

    def build : Expression::Statement
      raise NotImplementedError.new("A prepared select has no AST; it only runs its SQL")
    end
  end

  # A rendered SELECT whose value at *value_index* changes per run (for example the id of `find`).
  # Immutable, so one instance can be shared between fibers and threads.
  class StatementTemplate
    getter schema : Schema

    @columns_revision : Int32

    def initialize(@schema : Schema, @table : Symbol, @sql : String, @params : Array(DB::Any), @value_index : Int32)
      raise ArgumentError.new("value_index #{value_index} is outside the #{params.size} parameters") unless 0 <= value_index < params.size
      @columns_revision = columns_revision_of(schema, table)
    end

    # Whether this template was rendered for *schema* and *table* as their columns are now.
    def renders?(schema : Schema, table : Symbol) : Bool
      @schema.same?(schema) && @table == table && @columns_revision == columns_revision_of(schema, table)
    end

    private def columns_revision_of(schema : Schema, table : Symbol) : Int32
      schema.tables[table]?.try(&.columns_revision) || 0
    end

    def bind(value : DB::Any) : PreparedSelect
      params = @params.dup
      params[@value_index] = value
      PreparedSelect.new(@schema, @sql, params)
    end
  end
end
