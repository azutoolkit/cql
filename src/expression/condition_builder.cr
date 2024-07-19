module Expression
  class ConditionBuilder
    getter condition : Condition

    def initialize(@condition : Condition = EmptyNode.new)
    end

    def &(other : ConditionBuilder)
      combine(other, And)
    end

    def |(other : ConditionBuilder)
      combine(other, Or)
    end

    def and(other : ConditionBuilder)
      combine(other, And)
    end

    def or(other : ConditionBuilder)
      combine(other, Or)
    end

    private def combine(other : ConditionBuilder, combinator : Class)
      ConditionBuilder.new(combinator.new(@condition, other.condition))
    end

    macro method_missing(call)
      def {{call.name.id}}
        find_column({{call.name.id.stringify}})
      end
    end
  end
end
