require "log"
require "uuid"
require "ulid"
require "db"
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

module Sql
  VERSION = "0.1.0"

  alias PrimaryKeyType = Int64.class | UUID.class | ULID.class
  alias Any = Bool.class | Float32.class | Float64.class | Int32.class | Int64.class | Slice(UInt8) | String.class | Time.class | UUID.class | Nil.class

  enum Adapter
    Sqlite
    MySql
    Postgres
  end
end
