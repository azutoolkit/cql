module Sql
  class Error < Exception
    def initialize(@message : String)
    end
  end

  class Column(T) < BaseColumn
    @as_name : String? = nil

    property name : Symbol
    property type : Any
    getter? null : Bool = false
    getter default : DB::Any = nil
    getter? unique : Bool = false
    property table : Table? = nil
    property length : Int32? = nil
    property? index : Index? = nil

    def initialize(
      @name : Symbol,
      @type : T.class,
      @as_name : String? = nil,
      @null : Bool = false,
      @default : DB::Any = nil,
      @unique : Bool = false,
      @size : Int32? = nil,
      @index : Index? = nil
    )
    end

    def expression
      Expression::ColumnBuilder.new(Expression::Column.new(self))
    end

    def validate!(value)
      return if value.class == type
      raise Error.new "Expected column `#{name}` to be #{type}, but got #{value.class}"
    end
  end
end
