module Expression
  class ColumnBuilder
    getter column : Expression::Column

    def initialize(@column : Expression::Column)
    end

    private def compare(operator : String, value : Expression::Column | ConditionBuilder)
      ConditionBuilder.new(Expression::CompareCondition.new(@column, operator, value))
    end

    private def compare(operator : String, value : DB::Any)
      @column.column.validate!(value)
      ConditionBuilder.new(Expression::Compare.new(@column, operator, value))
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
      ConditionBuilder.new(Expression::InCondition.new(@column, items))
    end

    def in(sub_query : CQL::Query) : ConditionBuilder
      ConditionBuilder.new(Expression::InSelect.new(@column, sub_query.build))
    end

    def not_in(values : Array(DB::Any)) : ConditionBuilder
      ConditionBuilder.new(Expression::Not.new(Expression::InCondition.new(@column, values)))
    end

    def not_in(sub_query : CQL::Query) : ConditionBuilder
      ConditionBuilder.new(Expression::Not.new(Expression::InSelect.new(@column, sub_query.build)))
    end

    def like(pattern : String) : ConditionBuilder
      ConditionBuilder.new(Expression::Like.new(@column, pattern))
    end

    def not_like(pattern : String) : ConditionBuilder
      ConditionBuilder.new(Expression::NotLike.new(@column, pattern))
    end

    def null : ConditionBuilder
      ConditionBuilder.new(Expression::IsNull.new(@column))
    end

    def not_null : ConditionBuilder
      ConditionBuilder.new(Expression::IsNotNull.new(@column))
    end

    def between(min : DB::Any, max : DB::Any) : ConditionBuilder
      ConditionBuilder.new(Expression::Between.new(@column, min, max))
    end
  end
end
