module Sql
  class SelectBuilder
    @columns : Array(Column)
    @table : String = ""
    @is_distinct : Bool
    @orders : Array(Tuple(String, String))
    @group_by_columns : Array(String)
    @where_clause : WhereClause?
    @having_clause : HavingClause?
    @table_alias : String = ""
    @join_builder : JoinBuilder = JoinBuilder.new

    def initialize(@columns : Array(Column))
      @is_distinct = false
      @orders = [] of Tuple(String, String)
      @group_by_columns = [] of String
    end

    def top(count : Int32)
      @top_count = count
      self
    end

    def from(table : String, as alias_name = nil)
      @table = table
      @table_alias = alias_name if alias_name
      @columns.each { |col| col.table = alias_name || table }
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

    def having(&)
      builder = with HavingBuilder.new(@table, @table_alias, @columns) yield
      @having_clause = HavingClause.new(builder.condition)
      self
    end

    def count(column_name = "*", distinct = false)
      @columns << Column.new(column_name, is_count: true, is_distinct: distinct)
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

    def inner_join(table : String, &block : -> ConditionBuilder) : SelectBuilder
      @join_builder.inner_join(table, &block)
      self
    end

    def left_join(table : String, &block : -> ConditionBuilder) : SelectBuilder
      @join_builder.left_join(table, &block)
      self
    end

    def right_join(table : String, &block : -> ConditionBuilder) : SelectBuilder
      @join_builder.right_join(table, &block)
      self
    end

    def full_join(table : String, &block : -> ConditionBuilder) : SelectBuilder
      @join_builder.full_join(table, &block)
      self
    end

    def cross_join(table : String) : SelectBuilder
      @join_builder.cross_join(table)
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
        @having_clause,
        OrderByClause.new(@table, @table_alias, @orders),
        JoinClause.new(@join_builder.joins)
      )
    end
  end
end
