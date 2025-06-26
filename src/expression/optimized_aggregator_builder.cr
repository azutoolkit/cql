require "./base_expression"
require "./optimized_condition_builder"
require "./aggregate_functions"
require "./comparison_operators"

module Expression
  class AggregateBuilder
    getter aggregate_function : Condition

    def initialize(@aggregate_function : Condition)
    end

    # Optimized comparison methods with compile-time generation
    {% for operator, sql_operator in COMPARISON_OPERATORS %}
      def {{operator.id}}(other : Column | DB::Any) : ConditionBuilder
        ConditionBuilder.new(CompareCondition.new(@aggregate_function, {{sql_operator}}, other))
      end
    {% end %}

    # Method aliases for better readability
    {% for operator, method_name in {
                                      "==" => :eq,
                                      "!=" => :neq,
                                      "<=" => :lte,
                                      "<"  => :lt,
                                      ">"  => :gt,
                                      ">=" => :gte,
                                    } %}
      def {{method_name.id}}(other : Column | DB::Any) : ConditionBuilder
        self.{{operator.id}}(other)
      end
    {% end %}

    # Range and collection operations
    def between(min : DB::Any, max : DB::Any) : ConditionBuilder
      # For aggregates, we need to use HAVING clauses
      ConditionBuilder.new(CompareCondition.new(@aggregate_function, "BETWEEN", "#{min} AND #{max}"))
    end

    def in(values : Array(DB::Any)) : ConditionBuilder
      ConditionBuilder.new(CompareCondition.new(@aggregate_function, "IN", values))
    end

    def not_in(values : Array(DB::Any)) : ConditionBuilder
      ConditionBuilder.new(CompareCondition.new(@aggregate_function, "NOT IN", values))
    end
  end
end
