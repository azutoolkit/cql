require "./base_expression"
require "./condition_builder"

module Expression
  # Base column class with common functionality
  abstract class BaseColumn < Node
    include Comparable

    getter column : CQL::BaseColumn
    getter alias_name : String?

    def initialize(@column : CQL::BaseColumn, @alias_name : String? = nil)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  # Untyped column for dynamic queries
  class Column < BaseColumn
    protected def compare(operator : String, value : DB::Any) : ConditionBuilder
      ConditionBuilder.new(Compare.new(self, operator, value))
    end

    protected def compare(operator : String, value : BaseColumn) : ConditionBuilder
      ConditionBuilder.new(CompareCondition.new(self, operator, value))
    end
  end

  # Type-safe column for compile-time type checking
  class TypedColumn(T) < BaseColumn
    def type
      @column.type
    end

    # Type-safe comparison methods
    {% for operator, sql_operator in COMPARISON_OPERATORS %}
      def {{operator.id}}(value : T) : ConditionBuilder
        compare({{sql_operator}}, value)
      end

      def {{operator.id}}(value : TypedColumn(T)) : ConditionBuilder
        compare({{sql_operator}}, value)
      end
    {% end %}

    # Type-safe collection methods
    def in(items : Array(T)) : ConditionBuilder
      ConditionBuilder.new(InCondition.new(self, items.map(&.as(DB::Any))))
    end

    def not_in(values : Array(T)) : ConditionBuilder
      ConditionBuilder.new(Not.new(InCondition.new(self, values.map(&.as(DB::Any)))))
    end

    def between(min : T, max : T) : ConditionBuilder
      ConditionBuilder.new(Between.new(self, min.as(DB::Any), max.as(DB::Any)))
    end

    def not_between(min : T, max : T) : ConditionBuilder
      ConditionBuilder.new(Not.new(Between.new(self, min.as(DB::Any), max.as(DB::Any))))
    end

    protected def compare(operator : String, value : T) : ConditionBuilder
      ConditionBuilder.new(Compare.new(self, operator, value.as(DB::Any)))
    end

    protected def compare(operator : String, value : TypedColumn(T)) : ConditionBuilder
      ConditionBuilder.new(CompareCondition.new(self, operator, value))
    end

    # Override base methods to use typed versions
    protected def compare(operator : String, value : DB::Any) : ConditionBuilder
      ConditionBuilder.new(Compare.new(self, operator, value))
    end

    protected def compare(operator : String, value : BaseColumn) : ConditionBuilder
      ConditionBuilder.new(CompareCondition.new(self, operator, value))
    end
  end
end
