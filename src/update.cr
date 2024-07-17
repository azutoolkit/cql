module Sql
  class Update
    @table : Expression::Table? = nil
    @setters : Array(Expression::Setter) = [] of Expression::Setter
    @where : Expression::Where? = nil
    @back : Set(Expression::Column) = Set(Expression::Column).new

    def initialize(schema : Schema)
      @schema = schema
    end

    def update(table : Symbol)
      @table = Expression::Table.new(find_table(table))
      self
    end

    def set(**fields)
      fields.each do |k, v|
        column = @table.not_nil!.table.columns[k]
        @setters << Expression::Setter.new(Expression::Column.new(column), v)
      end

      self
    end

    def where(&)
      tbl = @table.not_nil!.table
      where_hash = {tbl.table_name => tbl}
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
      Expression::Update.new(@table.not_nil!, @setters, @where, @back)
    end

    private def find_table(name : Symbol) : Table
      @schema.tables[name]
    end
  end
end
