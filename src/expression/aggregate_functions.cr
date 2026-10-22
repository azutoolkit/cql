require "./select_expression"

module Expression
  # Base of the aggregate functions. Each wraps a single column; the alias is
  # only rendered in the SELECT list, never inside HAVING.
  abstract class AggregateFunction < SelectExpression
    getter column : BaseColumn

    def initialize(@column : BaseColumn, as_name : Symbol? = nil)
      super(as_name)
    end
  end

  alias Aggregate = AggregateFunction

  # COUNT can count distinct values: `COUNT(DISTINCT column)`.
  class Count < AggregateFunction
    getter? distinct : Bool

    def initialize(column : BaseColumn, as_name : Symbol? = nil, @distinct : Bool = false)
      super(column, as_name)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  {% for name in %w[Max Min Avg Sum] %}
    class {{ name.id }} < AggregateFunction
      def accept(visitor : Visitor)
        visitor.visit(self)
      end
    end
  {% end %}
end
