module Expression
  class HavingBuilder
    @columns : Array(Column)

    def initialize(sql_cols : Array(CQL::BaseColumn))
      @columns = sql_cols.map { |col| Column.new(col) }
    end

    def count(column : Symbol)
      aggregate(Count, column)
    end

    def max(column : Symbol)
      aggregate(Max, column)
    end

    def min(column : Symbol)
      aggregate(Min, column)
    end

    def avg(column : Symbol)
      aggregate(Avg, column)
    end

    def sum(column : Symbol)
      aggregate(Sum, column)
    end

    private def aggregate(klass, column : Symbol)
      col = find_column(column.to_s)
      AggregateBuilder.new(klass.new(col))
    end

    private def find_column(name : String)
      @columns.each do |column|
        return column if column.column.name.to_s == name
      end

      raise "Column not found: #{name}"
    end
  end
end
