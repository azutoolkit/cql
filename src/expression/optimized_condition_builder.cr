require "./base_expression"
require "./logical_operators"

module Expression
  class ConditionBuilder
    getter condition : Condition

    # Use a more efficient initialization pattern
    def initialize(@condition : Condition = EmptyNode.new)
    end

    # Optimized logical operations with method chaining
    def &(other : ConditionBuilder) : ConditionBuilder
      return other if @condition.is_a?(EmptyNode)
      return self if other.condition.is_a?(EmptyNode)
      ConditionBuilder.new(And.new(@condition, other.condition))
    end

    def |(other : ConditionBuilder) : ConditionBuilder
      return other if @condition.is_a?(EmptyNode)
      return self if other.condition.is_a?(EmptyNode)
      ConditionBuilder.new(Or.new(@condition, other.condition))
    end

    # Alias methods for better readability
    def and(other : ConditionBuilder) : ConditionBuilder
      self & other
    end

    def or(other : ConditionBuilder) : ConditionBuilder
      self | other
    end

    # Negation operator
    def not : ConditionBuilder
      return ConditionBuilder.new if @condition.is_a?(EmptyNode)
      ConditionBuilder.new(Not.new(@condition))
    end
  end
end
