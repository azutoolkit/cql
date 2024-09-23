require "log"
require "uuid"
require "ulid"
require "db"
require "./base_column"
require "./index"
require "./foreign_key"
require "./column"
require "./primary_key"
require "./alter_table"
require "./table"
require "./expression"
require "./query"
require "./insert"
require "./update"
require "./delete"
require "./schema"
require "./repository"
require "./record"
require "./relations"
require "./migrations"

module CQL
  # :nodoc:
  alias Date = Time

  # Represents a database primary key column type.
  alias PrimaryKeyType = Int32.class | Int64.class | UUID.class | ULID.class

  # :nodoc:
  alias Any = Bool.class |
              Float32.class |
              Float64.class |
              Int32.class |
              Int64.class |
              Slice(UInt8) |
              String.class |
              Time.class |
              UUID.class |
              Nil.class |
              JSON::Any.class

  # :nodoc:
  DB_TYPE_MAPPING = {
    CQL::Adapter::SQLite => {
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
      JSON::Any    => "TEXT",
    },
    CQL::Adapter::MySql => {
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
      JSON::Any    => "JSON",
    },
    CQL::Adapter::Postgres => {
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
      JSON::Any    => "JSONB",
    },
  }

  # Represents a database adapter module.
  enum Adapter
    SQLite
    MySql
    Postgres

    # Returns the SQL type for the given type.
    # @param type [Type] the type
    # @return [String] the SQL type
    # **Example** Getting the SQL type
    # ```
    # CQL::Adapter::SQLite.sql_type(Int32) # => "INTEGER"
    # ```
    def sql_type(type) : String
      DB_TYPE_MAPPING[self][type]
    end
  end
end
