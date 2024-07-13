module Sql
  class ColumnConditionBuilder(T)
    getter column : String

    def initialize(@column : String)
    end

    def ==(value : T)
      ConditionBuilder.new(ComparisonCondition.new(column, "=", value))
    end

    def !=(value : T)
      ConditionBuilder.new(ComparisonCondition.new(column, "<>", value))
    end

    def <(value : T)
      ConditionBuilder.new(ComparisonCondition.new(column, "<", value))
    end

    def <=(value : T)
      ConditionBuilder.new(ComparisonCondition.new(column, "<=", value))
    end

    def >(value : T)
      ConditionBuilder.new(ComparisonCondition.new(column, ">", value))
    end

    def >=(value : T)
      ConditionBuilder.new(ComparisonCondition.new(column, ">=", value))
    end

    def null
      ConditionBuilder.new(IsNullCondition.new(column))
    end

    def not_null
      ConditionBuilder.new(IsNotNullCondition.new(column))
    end

    def in(values : Array(T))
      ConditionBuilder.new(InCondition.new(column, values))
    end

    def not_in(values : Array(T))
      ConditionBuilder.new(NotCondition.new(InCondition.new(column, values)))
    end

    def in(sub_query : SelectBuilder)
      ConditionBuilder.new(InSelectCondition.new(@column, sub_query.build))
    end

    def not_in(sub_query : SelectBuilder)
      ConditionBuilder.new(NotInSelectCondition.new(InCondition.new(@column, sub_query.select_build)))
    end

    def like(pattern : T)
      ConditionBuilder.new(LikeCondition.new(@column, pattern))
    end

    def not_like(pattern : T)
      ConditionBuilder.new(NotLikeCondition.new(@column, pattern))
    end

    def in(values : Array(T))
      ConditionBuilder.new(InCondition.new(@column, values))
    end

    def not_in(values : Array(T))
      ConditionBuilder.new(NotCondition.new(InCondition.new(@column, values)))
    end

    def null
      ConditionBuilder.new(IsNullCondition.new(@column))
    end

    def not_null
      ConditionBuilder.new(IsNotNullCondition.new(@column))
    end

    def between(low : T)
      BetweenBuilder(T).new(@column, low)
    end

    class BetweenBuilder(T)
      def initialize(@column : String, @low : T)
      end

      def and(high : T)
        ConditionBuilder.new(BetweenCondition.new(@column, @low, high))
      end
    end
  end
end
