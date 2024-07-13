module Sql
  class JoinBuilder
    getter joins : Array(Node)

    def initialize(@joins : Array(Node) = [] of Node)
    end

    def inner_join(table : String, &block : -> ConditionBuilder) : JoinBuilder
      join_condition =  with self yield
      @joins << InnerJoin.new(table, join_condition.condition)
      self
    end

    def left_join(table : String, &block : -> ConditionBuilder) : JoinBuilder
      join_condition = with self yield
      @joins << LeftJoin.new(table, join_condition.condition)
      self
    end

    def right_join(table : String, &block : -> ConditionBuilder) : JoinBuilder
      join_condition = with self yield
      @joins << RightJoin.new(table, join_condition.condition)
      self
    end

    def full_join(table : String, &block : -> ConditionBuilder) : JoinBuilder
      join_condition = with self yield
      @joins << FullJoin.new(table, join_condition.condition)
      self
    end

    def cross_join(table : String) : JoinBuilder
      @joins << CrossJoin.new(table)
      self
    end

    macro method_missing(call)
      def {{call.name.id}}
        @columns.each do |column|
          if column.name == {{call.name.id.stringify}}
            return ColumnConditionBuilder(String).new(column)
          end
        end
        ColumnConditionBuilder(String).new(Column.new({{call.name.id.stringify}}))
      end
    end
  end
end
