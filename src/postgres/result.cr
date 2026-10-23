require "./types/codecs"

module CQL::Postgres
  record Column, name : String, type_oid : UInt32, codec : Types::Codec

  # A statement the server has parsed: how many parameters it takes and the
  # shape of its rows.
  record PreparedStatement, name : String, param_count : Int32, columns : Array(Column), param_oids : Array(UInt32) = [] of UInt32 do
    def result_formats : Array(Int16)
      columns.map(&.codec.format)
    end
  end

  # The complete outcome of one statement.
  class Result
    getter columns : Array(Column)
    getter rows : Array(Array(Types::Value))
    getter tag : String

    def initialize(@columns, @rows, @tag)
    end

    def rows_affected : Int64
      tag.split(' ').last.to_i64? || 0_i64
    end
  end

  record Notification, process_id : Int32, channel : String, payload : String
end
