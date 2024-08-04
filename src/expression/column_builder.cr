module Expression
  class ColumnBuilder
    getter column : Column

    def initialize(@column : Column)
    end

    def ==(value : DB::Any) : ConditionBuilder
      compare("=", value)
    end

    def eq(value : DB::Any) : ConditionBuilder
      compare("=", value)
    end

    def <=(value : DB::Any) : ConditionBuilder
      compare("<=", value)
    end

    def !=(value : DB::Any) : ConditionBuilder
      compare("!=", value)
    end

    def neq(value : DB::Any) : ConditionBuilder
      compare("!=", value)
    end

    def <(value : DB::Any) : ConditionBuilder
      compare("<", value)
    end

    def >(value : DB::Any) : ConditionBuilder
      compare(">", value)
    end

    def >=(value : DB::Any) : ConditionBuilder
      compare(">=", value)
    end

    def ==(value : ColumnBuilder | Column) : ConditionBuilder
      compare("=", value.column)
    end

    def eq(value : ColumnBuilder | Column) : ConditionBuilder
      compare("=", value.column)
    end

    def <=(value : ColumnBuilder | Column) : ConditionBuilder
      compare("<=", value.column)
    end

    def !=(value : ColumnBuilder | Column) : ConditionBuilder
      compare("!=", value.column)
    end

    def neq(value : ColumnBuilder | Column) : ConditionBuilder
      compare("!=", value.column)
    end

    def <(value : ColumnBuilder | Column) : ConditionBuilder
      compare("<", value.column)
    end

    def >(value : ColumnBuilder | Column) : ConditionBuilder
      compare(">", value.column)
    end

    def >=(value : ColumnBuilder | Column) : ConditionBuilder
      compare(">=", value.column)
    end

    def in(items : Array)
      ConditionBuilder.new(InCondition.new(@column, items))
    end

    def in(sub_query : Query)
      ConditionBuilder.new(InSelect.new(@column, sub_query.build))
    end

    def not_in(values : Array(DB::Anyy))
      ConditionBuilder.new(Not.new(InCondition.new(@column, values)))
    end

    def not_in(sub_query : Query)
      ConditionBuilder.new(InSelect.new(Not.new(@column, sub_query.build)))
    end

    def like(pattern : String)
      ConditionBuilder.new(Like.new(@column, pattern))
    end

    def not_like(pattern : String)
      ConditionBuilder.new(NotLike.new(@column, pattern))
    end

    def null
      ConditionBuilder.new(IsNull.new(@column))
    end

    def not_null
      ConditionBuilder.new(IsNotNull.new(@column))
    end

    private def compare(operator : String, value : Column | CompareCondition) : ConditionBuilder
      ConditionBuilder.new(CompareCondition.new(@column, operator, value))
    end

    private def compare(operator : String, value : DB::Any) : ConditionBuilder
      @column.column.validate!(value)
      ConditionBuilder.new(Compare.new(@column, operator, value))
    end
  end
end
