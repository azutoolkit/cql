module Sql
  class Error < Exception
    def initialize(@message : String)
    end
  end

  class Column
    @as_name : String? = nil

    alias Date = Time

    property name : Symbol
    property type : Sql::Any
    getter? null : Bool = false
    getter default : DB::Any = nil
    getter unique : Bool = false
    property table : Table? = nil
    property length : Int32? = nil
    property? index : Index? = nil

    def initialize(
      @name : Symbol,
      @type : Any,
      @as_name : String? = nil,
      @null : Bool = false,
      @default : DB::Any = nil,
      @unique : Bool = false,
      @size : Int32? = nil,
      @index : Index? = nil
    )
    end

    BASE_TYPE_MAPPING = {
      Sql::Adapter::Sqlite => {
        Int32        => "INTEGER",
        Int64        => "BIGINT",
        UInt32       => "INTEGER UNSIGNED",
        UInt64       => "BIGINT UNSIGNED",
        Float32      => "FLOAT",
        Float64      => "DOUBLE",
        String       => "TEXT",
        Bool         => "BOOLEAN",
        Time         => "TIMESTAMP",
        Date         => "DATE",
        Time::Span   => "INTERVAL",
        Slice(UInt8) => "BLOB",
      },
      Sql::Adapter::MySql => {
        Int32        => "INT",
        Int64        => "BIGINT",
        UInt32       => "INT UNSIGNED",
        UInt64       => "BIGINT UNSIGNED",
        Float32      => "FLOAT",
        Float64      => "DOUBLE",
        String       => "VARCHAR(255)",
        Bool         => "TINYINT(1)",
        Time         => "DATETIME",
        Date         => "DATE",
        Time::Span   => "TIME",
        Slice(UInt8) => "BLOB",
      },
      Sql::Adapter::Postgres => {
        Int32        => "INTEGER",
        Int64        => "BIGINT",
        UInt32       => "INTEGER",
        UInt64       => "BIGINT",
        Float32      => "REAL",
        Float64      => "DOUBLE PRECISION",
        String       => "VARCHAR",
        Bool         => "BOOLEAN",
        Time         => "TIMESTAMP",
        Date         => "DATE",
        Time::Span   => "INTERVAL",
        Slice(UInt8) => "BYTEA",
      },
    }

    def sql_type(adapter : Adapter) : String
      BASE_TYPE_MAPPING[adapter][type]
    end

    def validate!(value)
      return if value.class == type
      raise Error.new "Expected column `#{name}` to be #{type}, but got #{value.class}"
    end
  end
end
