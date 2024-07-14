module Sql
  class WhereBuilder
    getter tables : Array(Table)
    getter condition : Condition

    def initialize(@tables : Array(Table))
    end

    def column(name : String) : ColumnConditionBuilder
      ColumnConditionBuilder.new(Column.new(name, @tables.first))
    end
  end
