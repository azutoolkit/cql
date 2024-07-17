module Sql
  class Insert
    @table : Table? = nil
    @columns : Set(Expression::Column) = Set(Expression::Column).new
    @values : Array(Set(DB::Any)) = Array(Set(DB::Any)).new
    @back : Set(Expression::Column) = Set(Expression::Column).new
    @query : Query? = nil

    def initialize(schema : Schema)
      @schema = schema
    end

    def into(table : Symbol)
      @table = find_table(table)
      self
    end

    def values(**fields)
      keys = fields.keys.map { |column| Expression::Column.new(find_column(column)) }
      @columns = keys.to_set if @columns.empty?

      vals = fields.values.map { |v| v.as(DB::Any) }
      @values << vals.to_set

      self
    end

    def query(query : Query)
      @query = query
      self
    end

    def back(*columns : Symbol)
      @back = columns.to_a.map { |column| Expression::Column.new(find_column(column)) }.to_set
      self
    end

    def build
      Expression::Insert.new(
        Expression::Table.new(@table.not_nil!),
        @columns,
        @values,
        @back,
        @query.try(&.build)
      )
    end

    def to_sql
      build
    end

    private def find_table(table : Symbol) : Table
      @schema.tables[table] || raise "Table #{table} not found"
    end

    private def find_column(column : Symbol) : Column
      @table.not_nil!.columns[column] || raise "Column #{column} not found"
    end
  end
end
