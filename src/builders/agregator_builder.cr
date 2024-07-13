module Sql
  class AggregatorBuilder(T)
    def initialize(@column : String, @aggregator : String = "COUNT")
    end

    def ==(value : T)
      ConditionBuilder.new(ComparisonCondition.new("#{@aggregator}(#{@column})", "=", value))
    end

    def !=(value : T)
      ConditionBuilder.new(ComparisonCondition.new("#{@aggregator}(#{@column})", "<>", value))
    end

    def <(value : Number)
      ConditionBuilder.new(ComparisonCondition.new("#{@aggregator}(#{@column})", "<", value))
    end

    def <=(value : Number)
      ConditionBuilder.new(ComparisonCondition.new("#{@aggregator}(#{@column})", "<=", value))
    end

    def >(value : Number)
      ConditionBuilder.new(ComparisonCondition.new("#{@aggregator}(#{@column})", ">", value))
    end

    def >=(value : Number)
      ConditionBuilder.new(ComparisonCondition.new("#{@aggregator}(#{@column})", ">=", value))
    end
  end
end
