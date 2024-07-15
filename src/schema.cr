module Sql
  class Schema
    getter database : Symbol
    getter version : String
    getter tables : Hash(Symbol, Table) = {} of Symbol => Table

    def initialize(@database : Symbol, @version : String = "1.0")
      @tables = {} of Symbol => Table
    end

    def table(name : Symbol, as as_name = nil, &)
      table = Table.new(name, as_name)
      with table yield
      @tables[name] = table
      table
    end
  end
end
