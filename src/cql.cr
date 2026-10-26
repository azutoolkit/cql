# Crystal Standard Library

require "db"
require "json"
require "log"
require "ulid"
require "uuid"
require "./ulid_compat"
require "colorize"
require "./compat"
require "./identifier"

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
require "./cache"
require "./merge_query"
require "./query"
require "./repository"
require "./schema_dump"
require "./active_record/model"
require "./active_record/soft_deletable"
require "./active_record/dirty_tracking"
require "./performance"
require "./configure"

module CQL
  # :nodoc:
  # The same type as `Time`, so the type maps below have no entry of their own for it; `Table#date`
  # declares its column `DATE` through `DateColumn`.
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
  POSTGRES_TYPES = {
    Int32        => "INTEGER",
    Int64        => "BIGINT",
    UInt32       => "INTEGER",
    UInt64       => "BIGINT",
    Float32      => "REAL",
    Float64      => "DOUBLE PRECISION",
    String       => "VARCHAR",
    Bool         => "BOOLEAN",
    Time         => "TIMESTAMP",
    Time::Span   => "INTERVAL",
    Slice(UInt8) => "BYTEA",
    JSON::Any    => "JSONB",
  }

  # CockroachDB's INTEGER is 64-bit, so 32-bit columns are declared INT4 to read back as Int32.
  # :nodoc:
  COCKROACH_TYPES = POSTGRES_TYPES.merge({Int32 => "INT4", UInt32 => "BIGINT"})

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
      Time         => "DATETIME(3)",
      Time::Span   => "TIME",
      Slice(UInt8) => "BLOB",
      JSON::Any    => "JSON",
    },
    CQL::Adapter::Postgres    => POSTGRES_TYPES,
    CQL::Adapter::CockroachDB => COCKROACH_TYPES,
  }

  # Represents a database adapter module.
  enum Adapter
    SQLite
    MySql
    Postgres
    CockroachDB

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

    # PostgreSQL and CockroachDB share a wire protocol, `$n` placeholders and RETURNING.
    def postgres_compatible? : Bool
      postgres? || cockroach_db?
    end

    # The scheme crystal-db's driver registry knows for this adapter's URIs.
    def driver_uri(uri : String) : String
      cockroach_db? ? uri.sub(/\Acockroachdb:/, "postgres:") : uri
    end

    def dialect : Expression::BaseDialect
      case self
      in SQLite      then Dialects::SQLITE
      in MySql       then Dialects::MYSQL
      in Postgres    then Dialects::POSTGRES
      in CockroachDB then Dialects::COCKROACH
      end
    end
  end

  # One stateless dialect per adapter, shared by every query.
  module Dialects
    SQLITE    = Expression::SqliteDialect.new
    MYSQL     = Expression::MySqlDialect.new
    POSTGRES  = Expression::PostgresDialect.new
    COCKROACH = Expression::CockroachDialect.new
  end
end

# The native PostgreSQL/CockroachDB driver is the default for those URLs unless
# the `pg` shard registers its drivers first.
require "./postgres"
