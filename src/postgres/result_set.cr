require "db"
require "./result"

module CQL::Postgres
  # Reads rows through crystal-db's `ResultSet` interface, so `read(Int32)`,
  # `read(String?)` and `DB::Serializable` models work. The rows come from a
  # complete `Result`, or lazily from a `RowStream`.
  class ResultSet < ::DB::ResultSet
    # A *detached* set reads rows that outlived their statement's connection
    # checkout (or a stream), so closing it must not release that connection.
    def initialize(statement : ::DB::Statement, @columns : Array(Column), @rows : Iterator(Array(Types::Value)),
                   @rows_affected : -> Int64, @detached : Bool = false)
      super(statement)
      @row = [] of Types::Value
      @column = 0
    end

    def self.new(statement : ::DB::Statement, result : Result, detached : Bool = false) : ResultSet
      new(statement, result.columns, result.rows.each, -> { result.rows_affected }, detached)
    end

    def self.new(statement : ::DB::Statement, stream : RowStream) : ResultSet
      new(statement, stream.columns, stream, -> { stream.rows_affected }, detached: true)
    end

    protected def do_close
      super unless @detached
    end

    def move_next : Bool
      @column = 0
      row = @rows.next
      return false if row.is_a?(Iterator::Stop)
      @row = row
      true
    end

    def column_count : Int32
      @columns.size
    end

    def column_name(index : Int32) : String
      @columns[index].name
    end

    def next_column_index : Int32
      @column
    end

    def read
      value = @row[@column]
      @column += 1
      value
    end

    def rows_affected : Int64
      @rows_affected.call
    end
  end
end
