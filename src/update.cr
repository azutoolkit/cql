module Sql
  class Update
    @table : Expression::Table? = nil
    @setters : Array(Expression::Setter) = [] of Expression::Setter
    @where : Expression::Where? = nil
    @back : Set(Expression::Column) = Set(Expression::Column).new

    def initialize(@schema : Schema)
    end

    def commit
      @schema.db.exec to_sql
    end

    def to_sql(gen = @schema.gen)
      build.accept(gen)
    end

    def update(table : Symbol)
      @table = Expression::Table.new(find_table(table))
      self
    end

    def set(setters : Hash(Symbol, DB::Any))
      build_setters(setters)

      self
    end

    def set(**fields)
      build_setters(fields)

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

    private def build_setters(setters)
      setters.each do |k, v|
        column = find_column(k)
        column.validate!(v)
        @setters << Expression::Setter.new(Expression::Column.new(column), v)
      end
    end

    private def get_expression(field, value)
      column = find_column(field)
      column.validate!(value)
      Expression::Compare.new(Expression::Column.new(column), "=", value)
    end

    private def find_table(name : Symbol) : Table
      @schema.tables[name] || raise "Table #{name} not found"
    end

    private def find_column(name : Symbol) : Column
      @table.not_nil!.table.columns[name] || raise "Column #{name} not found"
    end
  end
end
