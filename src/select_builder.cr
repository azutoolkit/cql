module Sql
  class SelectBuilder
    getter? is_distinct : Bool
    @group_by_columns : Array(String) = [] of String
    @table : String = ""
    @table_alias : String = ""

    def initialize(@columns : Array(Column))
      @is_distinct = false
      @orders = [] of Tuple(String, String)
    end

    def top(count : Int32)
      @top_count = count
      self
    end


    def from(table : String, as alias_name = nil)
      @table = table
      @table_alias = alias_name if alias_name
      self
    end

    def where(&)
      builder = with WhereBuilder.new(@table, @table_alias, @columns) yield
      @where_clause = WhereClause.new(builder.condition)
      self
    end

    def group_by(*columns)
      @group_by_columns.concat(columns)
      self
    end

    def order_by(column : String, direction : String = "ASC")
      @orders << {column, direction}
      self
    end

    def distinct
      @is_distinct = true
      self
    end

    def count(column_name = "*", distinct = false)
      @columns = [Column.new(column_name, is_count: true, is_distinct: distinct)]
      self
    end

    def build
      SelectStatement.new(
        @columns,
        @table,
        @table_alias,
        @is_distinct,
        @top_count,
        @where_clause,
        GroupByClause.new(@table, @table_alias, @group_by_columns),
        OrderByClause.new(@table, @table_alias, @orders))
    end
  end
end
