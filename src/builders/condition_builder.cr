module Sql
  class ConditionBuilder
    def initialize(@condition : Condition)
    end

    def &(other : ConditionBuilder)
      ConditionBuilder.new(AndCondition.new(@condition, other.condition))
    end

    def |(other : ConditionBuilder)
      ConditionBuilder.new(OrCondition.new(@condition, other.condition))
    end

    def and(other : ConditionBuilder)
      ConditionBuilder.new(AndCondition.new(@condition, other.condition))
    end

    def or(other : ConditionBuilder)
      ConditionBuilder.new(OrCondition.new(@condition, other.condition))
    end

    def condition : Condition
      @condition
    end
  end
end
