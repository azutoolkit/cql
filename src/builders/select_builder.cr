module Sql
  class SelectBuilder
    @columns : Array(Column)
    @table : String = ""
    @is_distinct : Bool
    @orders : Array(Tuple(String, String))
    @group_by_columns : Array(String)
    @where_clause : WhereClause?
    @having_clause : HavingClause?
    @table_alias : String? = nil
    @joins : Array(InnerJoin)

    def initialize(@columns : Array(Column))
      @is_distinct = false
      @orders = [] of Tuple(String, String)
      @group_by_columns = [] of String
      @joins = [] of InnerJoin
    end

    def top(count : Int32)
      @top_count = count
      self
    end

    def from(table : String, as alias_name = nil)
      @table = table
      @table_alias = alias_name
      @columns.each { |col| col.table = @table_alias || @table }
      self
    end

    def inner_join(join_table : String, as join_table_alias : String? = nil, &)
      builder = with WhereBuilder.new(join_table, join_table_alias, @columns) yield
      @joins << InnerJoin.new(join_table, join_table_alias, builder.condition)
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

    def build
      Query.new(
        @columns,
        @table,
        @table_alias,
        @is_distinct,
        @top_count,
        @where_clause,
        GroupByClause.new(@table, @table_alias, @group_by_columns),
        @having_clause,
        OrderByClause.new(@table, @table_alias, @orders),
        @joins
      )
    end
  end
end
