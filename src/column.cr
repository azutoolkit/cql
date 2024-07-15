module Sql
  class Column
    getter name : Symbol
    getter type : ColumnType
    getter? null : Bool = false
    getter default : DB::Any = nil
    getter unique : Bool = false
    @as_name : String? = nil
    property table : Table? = nil

    def initialize(
      @name : Symbol,
      @type : ColumnType,
      @as_name : String? = nil,
      @null : Bool = false,
      @default : DB::Any = nil,
      @unique : Bool = false
    )
    end
  end
end