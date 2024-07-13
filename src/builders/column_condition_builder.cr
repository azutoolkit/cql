module Sql
  class ColumnConditionBuilder(T)
    getter column : Column

    def initialize(@column : Column)
    end

    def ==(value : T)
      ConditionBuilder.new(ComparisonCondition.new(column.name, "=", value))
    end

    def !=(value : T)
      ConditionBuilder.new(ComparisonCondition.new(column.name, "<>", value))
    end

    def <(value : Number)
      ConditionBuilder.new(ComparisonCondition.new(column.name, "<", value))
    end

    def <=(value : Number)
      ConditionBuilder.new(ComparisonCondition.new(column.name, "<=", value))
    end

    def >(value : Number)
      ConditionBuilder.new(ComparisonCondition.new(column.name, ">", value))
    end

    def >=(value : Number)
      ConditionBuilder.new(ComparisonCondition.new(column.name, ">=", value))
    end

    def null
      ConditionBuilder.new(IsNullCondition.new(column.name))
    end

    def not_null
      ConditionBuilder.new(IsNotNullCondition.new(colum.name))
    end

    def in(values : Array(T))
      ConditionBuilder.new(InCondition.new(column.name, values))
    end

    def not_in(values : Array(T))
      ConditionBuilder.new(NotCondition.new(InCondition.new(column.name, values)))
    end

    def in(sub_query : SelectBuilder)
      ConditionBuilder.new(InSelectCondition.new(@column.name, sub_query.build))
    end

    def not_in(sub_query : SelectBuilder)
      ConditionBuilder.new(NotInSelectCondition.new(InCondition.new(@column.name, sub_query.select_build)))
    end

    def like(pattern : T)
      ConditionBuilder.new(LikeCondition.new(@column.name, pattern))
    end

    def not_like(pattern : T)
      ConditionBuilder.new(NotLikeCondition.new(@column.name, pattern))
    end

    def in(values : Array(T))
      ConditionBuilder.new(InCondition.new(@column.name, values))
    end

    def not_in(values : Array(T))
      ConditionBuilder.new(NotCondition.new(InCondition.new(@column.name, values)))
    end

    def null
      ConditionBuilder.new(IsNullCondition.new(@column.name))
    end

    def not_null
      ConditionBuilder.new(IsNotNullCondition.new(@column.name))
    end

    def count
      AggregatorBuilder(T).new(@column.name)
    end

    def sum
      AggregatorBuilder(T).new(@column.name, "SUM")
    end

    def min
      AggregatorBuilder(T).new(@column.name, "MIN")
    end

    def max
      AggregatorBuilder(T).new(@column.name, "MAX")
    end

    def avg
      AggregatorBuilder(T).new(@column.name, "AVG")
    end

    def between(low : T, high : T)
      ConditionBuilder.new(BetweenCondition.new(@column.name, low, high))
    end
  end
end
