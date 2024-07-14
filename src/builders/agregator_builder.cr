module Sql
  class AggregatorBuilder
    def initialize(@column : String, @aggregator : String = "COUNT")
    end

    def ==(value : DB::Any)
      ConditionBuilder.new(ComparisonCondition.new("#{@aggregator}(#{@column})", "=", value))
    end

    def !=(value : DB::Any)
      ConditionBuilder.new(ComparisonCondition.new("#{@aggregator}(#{@column})", "<>", value))
    end

    def <(value : DB::Any)
      ConditionBuilder.new(ComparisonCondition.new("#{@aggregator}(#{@column})", "<", value))
    end

    def <=(value : DB::Any)
      ConditionBuilder.new(ComparisonCondition.new("#{@aggregator}(#{@column})", "<=", value))
    end

    def >(value : DB::Any)
      ConditionBuilder.new(ComparisonCondition.new("#{@aggregator}(#{@column})", ">", value))
    end

    def >=(value : DB::Any)
      ConditionBuilder.new(ComparisonCondition.new("#{@aggregator}(#{@column})", ">=", value))
    end
  end
end
