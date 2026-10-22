require "./base_expression"

module Expression
  # Base of the aggregate functions. Each one wraps a single column and may
  # carry a select-list alias (`COUNT(id) AS total`). The alias is only
  # rendered in the SELECT list; inside HAVING the aggregate is emitted
  # without it.
  abstract class AggregateFunction < Condition
    getter column : BaseColumn
    getter as_name : String?

    def initialize(@column : BaseColumn, @as_name : String? = nil)
    end
  end

  alias Aggregate = AggregateFunction

  {% for name in %w[Count Max Min Avg Sum] %}
    class {{ name.id }} < AggregateFunction
      def accept(visitor : Visitor)
        visitor.visit(self)
      end
    end
  {% end %}
end
