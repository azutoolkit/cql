require "./base_expression"

module Expression
  # A selectable value that is not a plain column (aggregate, window function),
  # optionally aliased: `<expression> AS alias`.
  abstract class SelectExpression < Condition
    getter as_name : Symbol?

    def initialize(@as_name : Symbol? = nil)
    end
  end
end
