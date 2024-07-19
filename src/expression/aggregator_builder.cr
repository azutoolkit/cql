module Expression
  class AggregateBuilder
    getter aggregate_function : Condition

    def initialize(@aggregate_function : Condition)
    end

    def >(value : Column | DB::Any)
      ConditionBuilder.new(CompareCondition.new(@aggregate_function, ">", value))
    end

    def <(value : Column | DB::Any)
      ConditionBuilder.new(CompareCondition.new(@aggregate_function, "<", value))
    end

    def >=(value : Column | DB::Any)
      ConditionBuilder.new(CompareCondition.new(@aggregate_function, ">=", value))
    end

    def <=(value : Column | DB::Any)
      ConditionBuilder.new(CompareCondition.new(@aggregate_function, "<=", value))
    end

    def ==(value : Column | DB::Any)
      ConditionBuilder.new(CompareCondition.new(@aggregate_function, "=", value))
    end

    def !=(value : Column | DB::Any)
      ConditionBuilder.new(CompareCondition.new(@aggregate_function, "!=", value))
    end
  end
end
