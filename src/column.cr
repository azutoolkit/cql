module Sql
  class Column
    @as_name : String? = nil

    DB_TYPE_MAPPING = {
      Int32        => "INTEGER",
      Int64        => "BIGINT",
      UInt32       => "INTEGER UNSIGNED",
      UInt64       => "BIGINT UNSIGNED",
      Float32      => "FLOAT",
      Float64      => "DOUBLE",
      String       => "VARCHAR(255)",
      Bool         => "BOOLEAN",
      Time         => "TIMESTAMP",
      Time::Span   => "INTERVAL",
      Slice(UInt8) => "BLOB",
    }

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
      @size : Int32? = nil,
      @index : Index? = nil
    )
    end

    def sql_type : String
      DB_TYPE_MAPPING[type]
    end
  end
end
