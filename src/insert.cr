module Sql
  class Insert
    Log = ::Log.for(self)

    @table : Table? = nil
    @columns : Set(Expression::Column) = Set(Expression::Column).new
    @values : Array(Array(DB::Any)) = Array(Array(DB::Any)).new
    @back : Array(Expression::Column) = Array(Expression::Column).new
    @query : Query? = nil

    def initialize(@schema : Schema)
    end

    def commit
      @schema.db.exec to_sql
    end

    def into(table : Symbol)
      @table = find_table(table)
      self
    end

    def values(values : Array(Hash(Symbol, DB::Any)))
      values.map { |hash| build_values(hash) }
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
      @back = columns.to_a.map { |column| Expression::Column.new(find_column(column)) }
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
      fields.each do |key, value|
        column = find_column(key)
        @columns << Expression::Column.new(column)
        puts typeof(column.type)
        @values << column.type.new(value)
      end
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
