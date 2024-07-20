module Sql
  class Schema
    Log = ::Log.for(self)
    getter database : Symbol
    getter version : String
    getter tables : Hash(Symbol, Table) = {} of Symbol => Table
    getter db : DB::Connection
    getter gen : Expression::Generator

    def initialize(@database : Symbol, @db : DB::Connection, @adapter : Adapter, @version : String = "1.0")
      @tables = {} of Symbol => Table
      @gen = Expression::Generator.new(@adapter)
    end

    def exec(sql : String)
      Log.info { sql }
      db.exec("#{sql};\n")
    end

    def query(sql : String)
      db.query("#{sql};\n")
    end

    def query_one(sql : String, as as_kind)
      db.query_one("#{sql};\n", as: as_kind)
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
      db.transaction do |tx|
        cnn = tx.connection
        puts alter_table.to_sql(@gen)
        Log.info { alter_table.to_sql(@gen) }
        cnn.exec(alter_table.to_sql(@gen))
      end
    rescue ex
      Log.error { ex.message }
    end

    macro method_missing(call)
      def {{call.id}}
        tables[:{{call.id}}]
      end
    end
  end
end
