module Expression
  class ColumnBuilder
    getter column : Column

    def initialize(@column : Column)
    end

    private def compare(operator : String, value : Column | ConditionBuilder)
      ConditionBuilder.new(CompareCondition.new(@column, operator, value))
    end

    private def compare(operator : String, value : DB::Any)
      @column.column.validate!(value)
      ConditionBuilder.new(Compare.new(@column, operator, value))
    end

    # Redefine comparison operators using method aliases
    {% for operator, method_name in {
                                      "==" => :eq,
                                      "!=" => :neq,
                                      "<=" => :lte,
                                      "<"  => :lt,
                                      ">"  => :gt,
                                      ">=" => :gte,
                                    } %}
        {% optr = (operator == "==") ? "=" : operator %}

      def {{operator.id}}(value : DB::Any) : ConditionBuilder
        compare("{{optr.id}}", value)
      end

      def {{method_name.id}}(value : DB::Any) : ConditionBuilder
        compare("{{optr.id}}", value)
      end

      def {{operator.id}}(value : ColumnBuilder | Column) : ConditionBuilder
        compare("{{optr.id}}", value.column)
      end

      def {{method_name.id}}(value : ColumnBuilder | Column) : ConditionBuilder
        compare("{{optr.id}}", value.column)
      end
    {% end %}

    def in(items : Array(DB::Any)) : ConditionBuilder
      ConditionBuilder.new(InCondition.new(@column, items))
    end

    def in(sub_query : CQL::Query) : ConditionBuilder
      ConditionBuilder.new(InSelect.new(@column, sub_query.build))
    end

    def not_in(values : Array(DB::Any)) : ConditionBuilder
      ConditionBuilder.new(Not.new(InCondition.new(@column, values)))
    end

    def not_in(sub_query : CQL::Query) : ConditionBuilder
      ConditionBuilder.new(Not.new(InSelect.new(@column, sub_query.build)))
    end

    def like(pattern : String) : ConditionBuilder
      ConditionBuilder.new(Like.new(@column, pattern))
    end

    def not_like(pattern : String) : ConditionBuilder
      ConditionBuilder.new(NotLike.new(@column, pattern))
    end

    def null : ConditionBuilder
      ConditionBuilder.new(IsNull.new(@column))
    end

    def not_null : ConditionBuilder
      ConditionBuilder.new(IsNotNull.new(@column))
    end

    def between(min : DB::Any, max : DB::Any) : ConditionBuilder
      ConditionBuilder.new(Between.new(@column, min, max))
    end
  end
end
