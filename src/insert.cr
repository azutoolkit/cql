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
      query, params = to_sql
      @schema.db.exec query, args: params
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
      gen.reset
      build.accept(gen)
      {gen.query, gen.params}
    end

    private def build_query
      if query = @query
        query.build
      end
    end

    private def build_values(fields)
      keys = Set(Expression::Column).new

      fields.each do |field, value|
        column = find_column(field)
        column.validate!(value)
        keys << Expression::Column.new(column)
      end

      @columns = keys if @columns.empty?

      vals = fields.values.map { |v| v.as(DB::Any) }
      @values << vals.to_a
    end

    private def find_table(table : Symbol) : Table
      @schema.tables[table] || raise "Table #{table} not found"
    end

    private def find_column(column : Symbol) : BaseColumn
      @table.not_nil!.columns[column] || raise "Column #{column} not found"
    end
  end
end
