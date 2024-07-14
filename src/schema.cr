module Sql
  class Schema
    getter database : Symbol
    getter version : String

    def initialize(@database : Symbol, @version : String = "1.0")
      @tables = [] of Table
    end

    def table(name : Symbol, as as_name = nil, &)
      table = Table.new(name, as_name)
      with table yield
      @tables << table
      table
    end

    def tables
      @tables
    end
  end
end
