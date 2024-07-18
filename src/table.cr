module Sql
  class Table
    getter table_name : Symbol
    getter columns : Hash(Symbol, Column) = {} of Symbol => Column
    getter primary_key : PrimaryKey?
    getter as_name : String?

    def initialize(@table_name : Symbol, @as_name : String? = nil)
    end

    def timestamps
      column :created_at, Time, null: false, default: Time.now
      column :updated_at, Time, null: false, default: Time.now
    end

    def create_index(columns : Array(Symbol), unique : Bool = false, table : Table = self)
      Index.new(table, columns, unique)
    end

    def primary_key(name : Symbol, type : PrimaryKeyType, auto_increment : Bool, as as_name = nil)
      PrimaryKeyType
      primary_key = PrimaryKey.new(name, type, as_name, auto_increment)
      primary_key.table = self
      @primary_key = primary_key
      @columns[name] = @primary_key.not_nil!
      @primary_key.not_nil!
    end

    def column(
      name : Symbol,
      type : ColumnType,
      as as_name : String? = nil,
      null : Bool = false,
      default : DB::Any = nil,
      unique : Bool = false,
      size : Int32? = nil,
      index : Bool = false
    )
      col = Column.new(name, type, as_name, null, default, unique, size)
      col.table = self
      @columns[name] = col
      col.index = index ? create_index(columns: [name], unique: unique) : nil
      col
    end

    macro method_missing(call)
      def {{call.id}}
        columns[:{{call.id}}]
      end
    end
  end
end
