require "./base_expression"

module Expression
  enum SetOperator
    Union
    UnionAll
    Intersect
    Except

    def to_sql : String
      case self
      in Union     then "UNION"
      in UnionAll  then "UNION ALL"
      in Intersect then "INTERSECT"
      in Except    then "EXCEPT"
      end
    end
  end

  # `left <operator> right`, where each side is a SELECT or another set operation.
  class SetOperation < Statement
    getter left : Statement
    getter operator : SetOperator
    getter right : Statement

    def initialize(@left : Statement, @operator : SetOperator, @right : Statement)
    end

    def needs_grouping_as_operand? : Bool
      true
    end

    # Column names come from the first operand, as in SQL.
    def output_columns : Array(CQL::BaseColumn)
      left.output_columns
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end
end
