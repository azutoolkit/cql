module Expression
  # Anything that renders as a complete query: a SELECT or a set operation.
  abstract class Statement < Node
    # The columns this statement produces, which is what a CTE or derived
    # table built from it exposes to the outer query.
    abstract def output_columns : Array(CQL::BaseColumn)

    # Whether this statement must be grouped when used as a set operation
    # operand, to keep its own ORDER BY / LIMIT / nested operators local.
    abstract def needs_grouping_as_operand? : Bool
  end

  # `name AS (statement)` inside a WITH clause.
  class Cte < Node
    getter name : String
    getter statement : Statement

    def initialize(@name : String, @statement : Statement)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end
end
