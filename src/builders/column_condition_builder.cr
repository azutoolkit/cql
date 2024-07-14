module Sql
  class ColumnConditionBuilder
    getter column : Column

    def initialize(@column : Column)
    end

    def ==(value : DB::Any)
      ConditionBuilder.new(ComparisonCondition.new(column.name, "=", value))
    end

    def !=(value : DB::Any)
      ConditionBuilder.new(ComparisonCondition.new(column.name, "<>", value))
    end

    def <(value : DB::Any)
      ConditionBuilder.new(ComparisonCondition.new(column.name, "<", value))
    end

    def <=(value : DB::Any)
      ConditionBuilder.new(ComparisonCondition.new(column.name, "<=", value))
    end

    def >(value : DB::Any)
      ConditionBuilder.new(ComparisonCondition.new(column.name, ">", value))
    end

    def >=(value : DB::Any)
      ConditionBuilder.new(ComparisonCondition.new(column.name, ">=", value))
    end

    def null
      ConditionBuilder.new(IsNullCondition.new(column.name))
    end

    def not_null
      ConditionBuilder.new(IsNotNullCondition.new(colum.name))
    end

    def in(values : Array(DB::Any))
      ConditionBuilder.new(InCondition.new(column.name, values))
    end

    def not_in(values : Array(DB::Any))
      ConditionBuilder.new(NotCondition.new(InCondition.new(column.name, values)))
    end

    def in(sub_query : SelectBuilder)
      ConditionBuilder.new(InSelectCondition.new(@column.name, sub_query.build))
    end

    def not_in(sub_query : SelectBuilder)
      ConditionBuilder.new(NotInSelectCondition.new(InCondition.new(@column.name, sub_query.select_build)))
    end

    def like(pattern : DB::Any)
      ConditionBuilder.new(LikeCondition.new(@column.name, pattern))
    end

    def not_like(pattern : String)
      ConditionBuilder.new(NotLikeCondition.new(@column.name, pattern))
    end

    def in(values : Array(DB::Any))
      ConditionBuilder.new(InCondition.new(@column.name, values))
    end

    def not_in(values : Array(DB::Any))
      ConditionBuilder.new(NotCondition.new(InCondition.new(@column.name, values)))
    end

    def null
      ConditionBuilder.new(IsNullCondition.new(@column.name))
    end

    def not_null
      ConditionBuilder.new(IsNotNullCondition.new(@column.name))
    end

    def count
      AggregatorBuilder.new(@column.name)
    end

    def sum
      AggregatorBuilder.new(@column.name, "SUM")
    end

    def min
      AggregatorBuilder.new(@column.name, "MIN")
    end

    def max
      AggregatorBuilder.new(@column.name, "MAX")
    end

    def avg
      AggregatorBuilder.new(@column.name, "AVG")
    end

    def between(low : DB::Any, high : DB::Any)
      ConditionBuilder.new(BetweenCondition.new(@column.name, low, high))
    end
  end
end
