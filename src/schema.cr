module Sql
  class Schema
    Log = ::Log.for(self)
    getter database : Symbol
    getter version : String
    getter tables : Hash(Symbol, Table) = {} of Symbol => Table
    getter db : DB::Connection
    getter gen : Expression::Generator = Expression::Generator.new

    def initialize(@database : Symbol, @db : DB::Connection, @version : String = "1.0")
      @tables = {} of Symbol => Table
    end

    def query
      Query.new(self)
    end

    def insert
      Insert.new(self)
    end

    def update
      Update.new(self)
    end

    def delete
      Delete.new(self)
    end

    def table(name : Symbol, as as_name = nil, &)
      table = Table.new(name, self, as_name)
      with table yield
      @tables[name] = table
      table
    end

    macro method_missing(call)
      def {{call.id}}
        tables[:{{call.id}}]
      end
    end
  end
end
