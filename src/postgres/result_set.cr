require "db"
require "./result"

module CQL::Postgres
  # Reads a fully received `Result` through crystal-db's `ResultSet` interface,
  # so `read(Int32)`, `read(String?)` and `DB::Serializable` models work.
  class ResultSet < ::DB::ResultSet
    getter result : Result

    # A *detached* set reads a result that outlived its statement's connection
    # checkout, so closing it must not release that connection.
    def initialize(statement : ::DB::Statement, @result : Result, @detached : Bool = false)
      super(statement)
      @row = -1
      @column = 0
    end

    protected def do_close
      super unless @detached
    end

    def move_next : Bool
      @row += 1
      @column = 0
      @row < @result.rows.size
    end

    def column_count : Int32
      @result.columns.size
    end

    def column_name(index : Int32) : String
      @result.columns[index].name
    end

    def next_column_index : Int32
      @column
    end

    def read
      value = @result.rows[@row][@column]
      @column += 1
      value
    end

    def rows_affected : Int64
      @result.rows_affected
    end
  end
end
