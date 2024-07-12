module Sql
  class InsertBuilder
    def initialize(@table : String)
      @columns = [] of String
      @values = [] of String
    end

    def columns(*columns)
      @columns = columns
      self
    end

    def values(*values)
      @values = values
      self
    end

    def build
      InsertStatement.new(@table, @columns, @values)
    end
  end
end
