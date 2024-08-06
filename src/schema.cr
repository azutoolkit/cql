module Cql
  class Schema
    Log = ::Log.for(self)
    getter name : Symbol
    getter db : DB::Connection
    getter version : String
    getter adapter : Adapter = Adapter::Sqlite
    getter tables : Hash(Symbol, Table) = {} of Symbol => Table
    getter gen : Expression::Generator

    def initialize(@name : Symbol, @db : DB::Connection, @adapter : Adapter = Adapter::Sqlite, @version : String = "1.0")
      @gen = Expression::Generator.new(@adapter)
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

    def alter(table_name : Symbol, &)
      alter_table = AlterTable.new(tables[table_name], self)
      with alter_table yield
      sql_statements = alter_table.to_sql(@gen)
      Log.info { sql_statements }

      db.transaction do |tx|
        cnn = tx.connection
        cnn.exec(sql_statements)
      end
    end

    macro method_missing(call)
      def {{call.id}}
        tables[:{{call.id}}]
      end
    end
  end
end
