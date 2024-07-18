module Sql
  class Delete
    @table : Expression::Table? = nil
    @where : Expression::Where? = nil
    @back : Set(Expression::Column) = Set(Expression::Column).new
    @using : Expression::Table? = nil

    def initialize(@schema : Schema)
    end

    def exec
      @schema.exec("#{to_sql};")
    end

    def to_sql(gen = @schema.gen)
      build.accept(gen)
    end

    def from(table : Symbol)
      @table = Expression::Table.new(find_table(table))
      self
    end

    def using(table : Symbol)
      @using = Expression::Table.new(find_table(table))
      self
    end

    def where(&)
      builder = with Expression::FilterBuilder.new(where_hash) yield
      @where = Expression::Where.new(builder.condition)
      self
    end

    def where(**fields)
      condition = nil
      fields.to_h.each_with_index do |(k, v), index|
        expr = get_expression(k, v)
        condition = index == 0 ? expr : Expression::And.new(condition.not_nil!, expr)
      end

      @where = Expression::Where.new(condition.not_nil!)

      self
    end

    def back(*columns : Symbol)
      @back = columns.to_a.map { |column| Expression::Column.new(find_column(column)) }.to_set
      self
    end

    def build
      Expression::Delete.new(@table.not_nil!, @where, @back, @using)
    end

    private def where_hash
      where_hash = Hash(Symbol, Table).new
      tbl = @table.not_nil!.table
      where_hash[tbl.table_name] = tbl

      if using = @using
        using_tbl = using.table
        where_hash[using_tbl.table_name] = using_tbl
      end

      where_hash
    end

    private def find_table(name : Symbol) : Table
      @schema.tables[name] || raise "Table #{name} not found"
    end

    private def find_column(name : Symbol) : Column
      @table.not_nil!.table.columns[name] || raise "Column #{name} not found"
    end
  end
end
