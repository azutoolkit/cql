require "db"
require "../cql"

module Expression
  # Core abstract classes
  abstract class Node
    abstract def accept(visitor : Visitor)
  end

  abstract class Condition < Node
  end

  # Mixin for common comparison operations
  module Comparable
    # Generate comparison methods at compile time
    {% for operator, sql_operator in COMPARISON_OPERATORS %}
      def {{operator.id}}(value : DB::Any) : ConditionBuilder
        compare({{sql_operator}}, value)
      end

      def {{operator.id}}(value : BaseColumn) : ConditionBuilder
        compare({{sql_operator}}, value)
      end
    {% end %}

    # Method aliases for comparison operators
    {% for operator, method_name in {
                                      "==" => :eq,
                                      "!=" => :neq,
                                      "<=" => :lte,
                                      "<"  => :lt,
                                      ">"  => :gt,
                                      ">=" => :gte,
                                    } %}
      def {{method_name.id}}(value : DB::Any) : ConditionBuilder
        self.{{operator.id}}(value)
      end

      def {{method_name.id}}(value : BaseColumn) : ConditionBuilder
        self.{{operator.id}}(value)
      end
    {% end %}

    # Common query methods
    def in(items : Array(DB::Any)) : ConditionBuilder
      ConditionBuilder.new(InCondition.new(self, items))
    end

    def in(sub_query : CQL::Query) : ConditionBuilder
      ConditionBuilder.new(InSelect.new(self, sub_query.build))
    end

    def not_in(values : Array(DB::Any)) : ConditionBuilder
      ConditionBuilder.new(Not.new(InCondition.new(self, values)))
    end

    def not_in(sub_query : CQL::Query) : ConditionBuilder
      ConditionBuilder.new(Not.new(InSelect.new(self, sub_query.build)))
    end

    def like(pattern : String) : ConditionBuilder
      ConditionBuilder.new(Like.new(self, pattern))
    end

    def not_like(pattern : String) : ConditionBuilder
      ConditionBuilder.new(NotLike.new(self, pattern))
    end

    def null : ConditionBuilder
      ConditionBuilder.new(IsNull.new(self))
    end

    def is_null : ConditionBuilder
      null
    end

    def not_null : ConditionBuilder
      ConditionBuilder.new(IsNotNull.new(self))
    end

    def is_not_null : ConditionBuilder
      not_null
    end

    def between(min : DB::Any, max : DB::Any) : ConditionBuilder
      ConditionBuilder.new(Between.new(self, min, max))
    end

    def not_between(min : DB::Any, max : DB::Any) : ConditionBuilder
      ConditionBuilder.new(Not.new(Between.new(self, min, max)))
    end

    def exists? : ConditionBuilder
      ConditionBuilder.new(Exists.new(self))
    end

    def not_exists? : ConditionBuilder
      ConditionBuilder.new(Not.new(Exists.new(self)))
    end

    protected abstract def compare(operator : String, value : DB::Any) : ConditionBuilder
    protected abstract def compare(operator : String, value : BaseColumn) : ConditionBuilder
  end
end
