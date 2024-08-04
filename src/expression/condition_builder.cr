module Expression
  class ConditionBuilder
    getter condition : Condition

    def initialize(@condition : Condition = EmptyNode.new)
    end

    def &(other : ConditionBuilder) : ConditionBuilder
      combine(other, And)
    end

    def |(other : ConditionBuilder) : ConditionBuilder
      combine(other, Or)
    end

    def and(other : ConditionBuilder) : ConditionBuilder
      combine(other, And)
    end

    def or(other : ConditionBuilder) : ConditionBuilder
      combine(other, Or)
    end

    private def combine(other : ConditionBuilder, combinator : Class) : ConditionBuilder
      ConditionBuilder.new(combinator.new(@condition, other.condition))
    end
  end
end
