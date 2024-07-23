module Sql
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
      case type
      when Int32.class        then value.is_a?(Int32) || raise "Expected Int32, but got #{value.class}"
      when Int64.class        then value.is_a?(Int64) || raise "Expected Int64, but got #{value.class}"
      when UInt32.class       then value.is_a?(UInt32) || raise "Expected UInt32, but got #{value.class}"
      when UInt64.class       then value.is_a?(UInt64) || raise "Expected UInt64, but got #{value.class}"
      when Float32.class      then value.is_a?(Float32) || raise "Expected Float32, but got #{value.class}"
      when Float64.class      then value.is_a?(Float64) || raise "Expected Float64, but got #{value.class}"
      when String.class       then value.is_a?(String) || raise "Expected String, but got #{value.class}"
      when Bool.class         then value.is_a?(Bool) || raise "Expected Bool, but got #{value.class}"
      when Time.class         then value.is_a?(Time) || raise "Expected Time, but got #{value.class}"
      when Date.class         then value.is_a?(Date) || raise "Expected Date, but got #{value.class}"
      when Slice(UInt8).class then value.is_a?(Slice(UInt8)) || raise "Expected Slice(UInt8), but got #{value.class}"
      when Nil.class          then value.nil? || raise "Expected Nil, but got #{value.class}"
      else                         raise "Unsupported type: #{type}"
      end
    end
  end
end
