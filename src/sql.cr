require "log"
require "uuid"
require "ulid"
require "db"
require "./schema"
require "./column"
require "./primary_key"
require "./table"
require "./expression"
require "./query"
require "./insert"
require "./update"

module Sql
  VERSION = "0.1.0"
  alias PrimaryKeyType = Int64.class | UUID.class | ULID.class
  alias ColumnType = Bool.class | Float32.class | Float64.class | Int32.class | Int64.class | Slice(UInt8) | String.class | Time.class | UUID.class | Nil.class
end
