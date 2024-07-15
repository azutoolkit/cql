module Sql
  class Table
    getter name : Symbol
    getter columns : Hash(Symbol, Column) = {} of Symbol => Column
    getter primary_key : PrimaryKey?
    getter as_name : String?

    def initialize(@name : Symbol, @as_name : String? = nil)
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
      unique : Bool = false
    )
      col = Column.new(name, type, as_name, null, default, unique)
      col.table = self
      @columns[name] = col
      col
    end
  end
end
