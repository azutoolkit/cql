module Sql
  class Column
    @as_name : String? = nil

    getter name : Symbol
    getter type : ColumnType
    getter? null : Bool = false
    getter default : DB::Any = nil
    getter unique : Bool = false
    property table : Table? = nil
    property length : Int32? = nil
    property? index : Index? = nil

    def initialize(
      @name : Symbol,
      @type : ColumnType,
      @as_name : String? = nil,
      @null : Bool = false,
      @default : DB::Any = nil,
      @unique : Bool = false,
      @length : Int32? = nil,
      @index : Index? = nil
    )
    end
  end
end
