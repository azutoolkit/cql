module Sql
  class WhereBuilder
    def initialize(@table : String, @table_alias : String, @columns : Array(Column))
    end

    def and(left : ConditionBuilder, right : ConditionBuilder) : ConditionBuilder
      ConditionBuilder.new(AndCondition.new(left.condition, right.condition))
    end

    def |(left : ConditionBuilder, right : ConditionBuilder) : ConditionBuilder
      ConditionBuilder.new(OrCondition.new(left.condition, right.condition))
    end

    def &(left : ConditionBuilder, right : ConditionBuilder) : ConditionBuilder
      ConditionBuilder.new(AndCondition.new(left.condition, right.condition))
    end

    def or(left : ConditionBuilder, right : ConditionBuilder) : ConditionBuilder
      ConditionBuilder.new(OrCondition.new(left.condition, right.condition))
    end

    def not(condition : ConditionBuilder) : ConditionBuilder
      ConditionBuilder.new(NotCondition.new(condition.condition))
    end

    def exists(subquery : SelectBuilder) : ConditionBuilder
      ConditionBuilder.new(ExistsCondition.new(subquery.build))
    end

    macro method_missing(call)
      def {{call.name.id}}
      ColumnConditionBuilder(String).new({{call.name.id.stringify}})
      end
    end
  end
end
