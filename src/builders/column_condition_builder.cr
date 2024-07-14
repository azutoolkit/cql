module Sql
  class ColumnConditionBuilder
    getter column : Column

    def initialize(@column : Column)
    end

    def name
      @column.name
    end

    def ==(value : DB::Any)
      ConditionBuilder.new(ComparisonCondition.new(name, "=", value))
    end

    def !=(value : DB::Any)
      ConditionBuilder.new(ComparisonCondition.new(name, "<>", value))
    end

    def <(value : DB::Any)
      ConditionBuilder.new(ComparisonCondition.new(name, "<", value))
    end

    def <=(value : DB::Any)
      ConditionBuilder.new(ComparisonCondition.new(name, "<=", value))
    end

    def >(value : DB::Any)
      ConditionBuilder.new(ComparisonCondition.new(name, ">", value))
    end

    def >=(value : DB::Any)
      ConditionBuilder.new(ComparisonCondition.new(name, ">=", value))
    end

    def null
      ConditionBuilder.new(IsNullCondition.new(name))
    end

    def not_null
      ConditionBuilder.new(IsNotNullCondition.new(name))
    end

    def in(values : Array(DB::Any))
      ConditionBuilder.new(InCondition.new(name, values))
    end

    def not_in(values : Array(DB::Any))
      ConditionBuilder.new(NotCondition.new(InCondition.new(name, values)))
    end

    def in(sub_query : SelectBuilder)
      ConditionBuilder.new(InSelectCondition.new(name, sub_query.build))
    end

    def not_in(sub_query : SelectBuilder)
      ConditionBuilder.new(NotInSelectCondition.new(InCondition.new(name, sub_query.select_build)))
    end

    def like(pattern : DB::Any)
      ConditionBuilder.new(LikeCondition.new(name, pattern))
    end

    def not_like(pattern : String)
      ConditionBuilder.new(NotLikeCondition.new(name, pattern))
    end

    def in(values : Array(DB::Any))
      ConditionBuilder.new(InCondition.new(name, values))
    end

    def not_in(values : Array(DB::Any))
      ConditionBuilder.new(NotCondition.new(InCondition.new(name, values)))
    end

    def null
      ConditionBuilder.new(IsNullCondition.new(name))
    end

    def not_null
      ConditionBuilder.new(IsNotNullCondition.new(name))
    end

    def count
      AggregatorBuilder.new(name)
    end

    def sum
      AggregatorBuilder.new(name, "SUM")
    end

    def min
      AggregatorBuilder.new(name, "MIN")
    end

    def max
      AggregatorBuilder.new(name, "MAX")
    end

    def avg
      AggregatorBuilder.new(name, "AVG")
    end

    def between(low : DB::Any, high : DB::Any)
      ConditionBuilder.new(BetweenCondition.new(name, low, high))
    end
  end
end
