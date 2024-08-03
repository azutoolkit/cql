module Expression
  class ColumnBuilder
    getter column : Column

    def initialize(@column : Column)
    end

    def ==(other : DB::Any)
      compare("=", other)
    end

    def <=(other : DB::Any)
      compare("<=", other)
    end

    def eq(other : DB::Any)
      compare("=", other)
    end

    def !=(other : DB::Any)
      compare("!=", other)
    end

    def neq(other : DB::Any)
      compare("!=", other)
    end

    def <(other : DB::Any)
      compare("<", other)
    end

    def >(other : DB::Any)
      compare(">", other)
    end

    def >=(other : DB::Any)
      compare(">=", other)
    end

    def ==(other : DB::Any)
      compare("=", other)
    end

    def <=(other : DB::Any)
      compare("<=", other)
    end

    def eq(other : DB::Any)
      compare("=", other)
    end

    def !=(other : DB::Any)
      compare("!=", other)
    end

    def neq(other : DB::Any)
      compare("!=", other)
    end

    def <(other : DB::Any)
      compare("<", other)
    end

    def >(other : DB::Any)
      compare(">", other)
    end

    def >=(other : DB::Any)
      compare(">=", other)
    end

    def ==(other : ColumnBuilder)
      compare("=", other.column)
    end

    def <=(other : ColumnBuilder)
      compare("<=", other.column)
    end

    def eq(other : ColumnBuildery)
      compare("=", other.column)
    end

    def !=(other : ColumnBuilder)
      compare("!=", other.column)
    end

    def neq(other : ColumnBuilder)
      compare("!=", other.column)
    end

    def <(other : ColumnBuilder)
      compare("<", other.column)
    end

    def >(other : ColumnBuilder)
      compare(">", other.column)
    end

    def >=(other : ColumnBuilder)
      compare(">=", other.column)
    end

    def ==(other : ColumnBuilder)
      compare("=", other.column)
    end

    def <=(other : ColumnBuilder)
      compare("<=", other.column)
    end

    def eq(other : ColumnBuilder)
      compare("=", other.column)
    end

    def !=(other : ColumnBuilder)
      compare("!=", other.column)
    end

    def neq(other : ColumnBuilder)
      compare("!=", other.column)
    end

    def <(other : ColumnBuilder)
      compare("<", other.column)
    end

    def >(other : ColumnBuilder)
      compare(">", other.column)
    end

    def >=(other : ColumnBuilder)
      compare(">=", other.column)
    end

    def in(others : Array(DB::Any))
      ConditionBuilder.new(InCondition.new(@column, others))
    end

    def not_in(others : Array(DB::Any))
      ConditionBuilder.new(Not.new(InCondition.new(@column, others)))
    end

    def in(sub_query : Query)
      ConditionBuilder.new(InSelect.new(@column, sub_query.build))
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

    private def compare(operator : String, other : Column | CompareCondition)
      ConditionBuilder.new(CompareCondition.new(@column, operator, other))
    end

    private def compare(operator : String, other : DB::Any)
      @column.column.validate!(other)
      ConditionBuilder.new(Compare.new(@column, operator, other))
    end
  end
end
