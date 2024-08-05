module Cql
  class Table
    property table_name : Symbol
    getter columns : Hash(Symbol, BaseColumn) = {} of Symbol => BaseColumn
    getter primary_key = PrimaryKey(Int64).new(:id, Int64, nil, true)
    getter as_name : String?
    private getter schema : Schema

    def initialize(@table_name : Symbol, @schema : Schema, @as_name : String? = nil)
    end

    def primary_key(
      name : Symbol = :id,
      type : T.class = Int64,
      auto_increment : Bool = true,
      as as_name = nil
    ) forall T
      primary_key = PrimaryKey(T).new(name, type, as_name, auto_increment)
      primary_key.table = self
      @primary_key = primary_key
      @columns[name] = @primary_key.not_nil!
      @primary_key.not_nil!
    end

    def column(
      name : Symbol,
      type : T.class,
      as as_name : String? = nil,
      null : Bool = false,
      default : DB::Any = nil,
      unique : Bool = false,
      size : Int32? = nil,
      index : Bool = false
    ) forall T
      col = Column(T).new(name, T, as_name, null, default, unique, size)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name], unique: unique) : nil
      col
    end

    def timestamps
      column :created_at, Time, null: false, default: Time.local
      column :updated_at, Time, null: false, default: Time.local
    end

    def add_index(columns : Array(Symbol), unique : Bool = false, table : Table = self)
      Index.new(table, columns, unique)
    end

    def create!
      create_query = Expression::CreateTable.new(self).accept(schema.gen).to_s
      schema.tables[table_name] = self if schema.tables[table_name].nil?
      schema.db.exec "#{create_query};"
    end

    def drop!
      drop_query = Expression::DropTable.new(self).accept(schema.gen).to_s
      schema.db.exec "#{drop_query};"
    end

    def truncate!
      truncate_query = Expression::TruncateTable.new(self).accept(schema.gen).to_s
      schema.db.exec "#{truncate_query};"
      schema.tables.delete[table_name]
    end

    macro method_missing(call)
      def {{call.id}}
        columns[:{{call.id}}]
      end
    end
  end
end
