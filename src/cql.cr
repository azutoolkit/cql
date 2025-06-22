# Crystal Standard Library

require "db"
require "json"
require "log"
require "ulid"
require "uuid"
require "colorize"
require "tallboy"

require "./expression"
require "./exceptions"
require "./converters/*"
require "./alter_table"
require "./insert"
require "./update"
require "./delete"
require "./base_column"
require "./column"
require "./primary_key"
require "./index"
require "./foreign_key"
require "./table"
require "./migrations"
require "./schema"
require "./merge_query"
require "./query"
require "./repository"
require "./active_record/model"

module CQL
  # :nodoc:
  alias Date = Time

  # Represents a database primary key column type.
  alias PrimaryKeyType = Int32.class | Int64.class | UUID.class | ULID.class

  # :nodoc:
  alias Any = Int32.class |
              Int64.class |
              UInt32.class |
              UInt64.class |
              Float32.class |
              Float64.class |
              String.class |
              Bool.class |
              Time.class |
              Date.class |
              Time::Span.class |
              Slice(UInt8).class |
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

    def dialect
      case self
      when SQLite
        Expression::SqliteDialect.new
      when MySql
        Expression::MySqlDialect.new
      when Postgres
        Expression::PostgresDialect.new
      else
        raise "Unsupported adapter: #{self}"
      end
    end
  end
end
