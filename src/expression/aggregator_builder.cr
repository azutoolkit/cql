module Expression
  class AggregateBuilder
    getter aggregate_function : Condition

    def initialize(@aggregate_function : Condition)
    end

    def >(other : Column | DB::Any)
      ConditionBuilder.new(CompareCondition.new(@aggregate_function, ">", other))
    end

    def <(other : Column | DB::Any)
      ConditionBuilder.new(CompareCondition.new(@aggregate_function, "<", other))
    end

    def >=(other : Column | DB::Any)
      ConditionBuilder.new(CompareCondition.new(@aggregate_function, ">=", other))
    end

    def <=(other : Column | DB::Any)
      ConditionBuilder.new(CompareCondition.new(@aggregate_function, "<=", other))
    end

    def ==(other : Column | DB::Any)
      ConditionBuilder.new(CompareCondition.new(@aggregate_function, "=", other))
    end

    def !=(other : Column | DB::Any)
      ConditionBuilder.new(CompareCondition.new(@aggregate_function, "!=", other))
    end
  end
end
