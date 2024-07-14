module Sql
  class Table
    getter name : Symbol
    getter columns : Array(Column) = [] of Column
    getter primary_key : PrimaryKey?
    @as_name : String?

    def initialize(@name : Symbol, @as_name : String? = nil)
      @as_name = as_name
    end

    def primary_key(name : Symbol, type : PrimaryKeyType, auto_increment : Bool, as as_name = nil) forall PrimaryKeyType
      @primary_key = PrimaryKey.new(name, type, as_name, auto_increment)
      @columns << @primary_key.not_nil!
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
      col = Column.new(
        name,
        type,
        as_name,
        null,
        default,
        unique
      )
      @columns << col
      col
    end

    def as_name
      @as_name || "tbl_#{name.to_s[0..2]}_#{self.object_id}"
    end
  end
end
