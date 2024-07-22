module Sql
  class Insert
    Log = ::Log.for(self)

    @table : Table? = nil
    @columns : Set(Expression::Column) = Set(Expression::Column).new
    @values : Array(Set(DB::Any)) = Array(Set(DB::Any)).new
    @back : Set(Expression::Column) = Set(Expression::Column).new
    @query : Query? = nil

    def initialize(@schema : Schema)
    end

    def exec
      @schema.exec("#{to_sql};")
    end

    def into(table : Symbol)
      @table = find_table(table)
      self
    end

    def values(values : Array(Hash(Symbol, DB::Any)))
      values.each { |hash|
        build_values(hash)
      }
      self
    end

    def values(hash : Hash(Symbol, DB::Any))
      build_values(hash)
      self
    end

    def values(**fields)
      build_values(fields)
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
        @columns, @values, @back, build_query
      )
    end

    def to_sql(gen = @schema.gen)
      build.accept(gen)
    end

    private def build_query
      if query = @query
        query.build
      end
    end

    private def build_values(fields)
      keys = fields.keys.map do |column|
        column = find_column(column)
        Expression::Column.new(column)
      end

      @columns = keys.to_set if @columns.empty?

      vals = fields.values.map { |v| v.as(DB::Any) }
      @values << vals.to_set
    end

    private def find_table(table : Symbol) : Table
      @schema.tables[table] || raise "Table #{table} not found"
    end

    private def find_column(column : Symbol) : Column
      @table
        .not_nil!
        .columns[column] || raise "Column #{column} not found"
    end
  end
end
