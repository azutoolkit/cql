require "./reader"

module CQL::Postgres::Wire
  # Messages a server sends, decoded from their payloads.
  module Backend
    module Message
    end

    record AuthenticationOk do
      include Message
    end

    record AuthenticationCleartext do
      include Message
    end

    record AuthenticationMD5, salt : Bytes do
      include Message
    end

    record AuthenticationSASL, mechanisms : Array(String) do
      include Message
    end

    record AuthenticationSASLContinue, data : Bytes do
      include Message
    end

    record AuthenticationSASLFinal, data : Bytes do
      include Message
    end

    record ParameterStatus, name : String, value : String do
      include Message
    end

    record BackendKeyData, process_id : Int32, secret_key : Int32 do
      include Message
    end

    record ReadyForQuery, status : Char do
      include Message
    end

    record NegotiateProtocolVersion, newest_minor : Int32, unrecognized : Array(String) do
      include Message
    end

    record Field, name : String, type_oid : UInt32 do
    end

    record RowDescription, fields : Array(Field) do
      include Message
    end

    # One row, left as the message payload and read field by field so a large
    # result does not allocate an intermediate array per row.
    record DataRow, payload : Bytes do
      include Message

      def size : Int32
        Reader.new(payload).uint16.to_i
      end

      # Yields each field's bytes, nil for NULL.
      def each_field(& : Bytes? ->) : Nil
        reader = Reader.new(payload)
        reader.uint16.times do
          length = reader.int32
          raise ProtocolError.new("invalid field length #{length}") if length < -1
          yield(length == -1 ? nil : reader.bytes(length))
        end
      end

      def values : Array(Bytes?)
        fields = Array(Bytes?).new(size)
        each_field { |field| fields << field }
        fields
      end
    end

    record CommandComplete, tag : String do
      include Message

      # Rows touched, from tags like "INSERT 0 5", "UPDATE 3" or "SELECT 1".
      def rows_affected : Int64
        tag.split(' ').last.to_i64? || 0_i64
      end
    end

    record ErrorResponse, fields : Hash(Char, String) do
      include Message
    end

    record NoticeResponse, fields : Hash(Char, String) do
      include Message
    end

    record NotificationResponse, process_id : Int32, channel : String, payload : String do
      include Message
    end

    record ParameterDescription, type_oids : Array(UInt32) do
      include Message
    end

    record CopyResponse, direction : Char, column_count : UInt16 do
      include Message
    end

    record CopyData, data : Bytes do
      include Message
    end

    {% for name in %w(EmptyQueryResponse ParseComplete BindComplete CloseComplete NoData PortalSuspended CopyDone) %}
      record {{name.id}} do
        include Message
      end
    {% end %}

    MAX_MESSAGE_SIZE = 1 << 30
    EAGER_READ_SIZE  = 64 * 1024

    # Reads and decodes the next message from *io*. Messages over *max_size*
    # are refused, and big payloads are buffered only as they arrive so a
    # hostile length cannot reserve memory the peer never sends.
    def self.read(io : IO, max_size : Int32 = MAX_MESSAGE_SIZE) : Message
      read_buffered_data_row(io, max_size) || read_message(io, max_size)
    end

    # A DataRow that already sits whole in the stream's buffer is read in place,
    # as asyncpg does for result rows: no payload allocation and no copy. Its
    # payload is borrowed from that buffer and valid only until the next read,
    # which is fine because the session decodes every row immediately.
    private def self.read_buffered_data_row(io : IO, max_size : Int32) : DataRow?
      buffered = io.peek
      return unless buffered && buffered.size >= 5 && buffered.unsafe_fetch(0) == 'D'.ord
      length = Reader.big_endian(Bytes.new(buffered.to_unsafe + 1, 4)).to_i32!
      return unless 4 <= length && length - 4 <= max_size && buffered.size - 1 >= length
      payload = Bytes.new(buffered.to_unsafe + 5, length - 4)
      io.skip(1 + length)
      DataRow.new(payload)
    end

    private def self.read_message(io : IO, max_size : Int32) : Message
      header = uninitialized UInt8[5]
      io.read_fully(header.to_slice)
      type = header[0]
      length = Reader.big_endian(header.to_slice[1, 4]).to_i32!
      raise ProtocolError.new("invalid message length #{length}") unless 4 <= length && length - 4 <= max_size
      decode(type.chr, Reader.new(read_payload(io, length - 4)))
    end

    private def self.read_payload(io : IO, size : Int32) : Bytes
      return Bytes.new(size).tap { |payload| io.read_fully(payload) } if size <= EAGER_READ_SIZE
      buffer = IO::Memory.new(EAGER_READ_SIZE)
      raise IO::EOFError.new("server closed the connection") if IO.copy(io, buffer, size) < size
      buffer.to_slice
    end

    def self.decode(type : Char, reader : Reader) : Message
      case type
      when 'R'      then authentication(reader)
      when 'S'      then ParameterStatus.new(reader.cstring, reader.cstring)
      when 'K'      then BackendKeyData.new(reader.int32, reader.int32)
      when 'Z'      then ready_for_query(reader)
      when 'v'      then negotiate_protocol_version(reader)
      when 'T'      then row_description(reader)
      when 'D'      then DataRow.new(reader.rest)
      when 'C'      then CommandComplete.new(reader.cstring)
      when 'E'      then ErrorResponse.new(error_fields(reader))
      when 'N'      then NoticeResponse.new(error_fields(reader))
      when 'A'      then NotificationResponse.new(reader.int32, reader.cstring, reader.cstring)
      when 't'      then ParameterDescription.new(Array.new(reader.uint16.to_i) { reader.uint32 })
      when 'G', 'H' then CopyResponse.new(type, copy_column_count(reader))
      when 'd'      then CopyData.new(reader.rest)
      when 'c'      then CopyDone.new
      when 'I'      then EmptyQueryResponse.new
      when '1'      then ParseComplete.new
      when '2'      then BindComplete.new
      when '3'      then CloseComplete.new
      when 'n'      then NoData.new
      when 's'      then PortalSuspended.new
      else               raise ProtocolError.new("unexpected message type #{type.inspect}")
      end
    end

    private def self.authentication(reader : Reader) : Message
      case code = reader.int32
      when 0  then AuthenticationOk.new
      when 3  then AuthenticationCleartext.new
      when 5  then AuthenticationMD5.new(reader.bytes(4))
      when 10 then AuthenticationSASL.new(sasl_mechanisms(reader))
      when 11 then AuthenticationSASLContinue.new(reader.rest)
      when 12 then AuthenticationSASLFinal.new(reader.rest)
      when 2, 6, 7, 8, 9
        raise AuthenticationError.new("the server asked for authentication method #{code} (Kerberos, SCM, GSS or SSPI), which this driver does not implement")
      else raise ProtocolError.new("unknown authentication method #{code}")
      end
    end

    private def self.sasl_mechanisms(reader : Reader) : Array(String)
      mechanisms = [] of String
      while (name = reader.cstring) && !name.empty?
        mechanisms << name
      end
      mechanisms
    end

    private def self.row_description(reader : Reader) : RowDescription
      fields = Array.new(reader.uint16.to_i) do
        name = reader.cstring
        reader.bytes(6) # table oid, attribute number
        type_oid = reader.uint32
        reader.bytes(8) # type size, type modifier, format code
        Field.new(name, type_oid)
      end
      RowDescription.new(fields)
    end

    private def self.ready_for_query(reader : Reader) : ReadyForQuery
      status = reader.char
      raise ProtocolError.new("invalid transaction status #{status.inspect}") unless status.in?('I', 'T', 'E')
      ReadyForQuery.new(status)
    end

    private def self.error_fields(reader : Reader) : Hash(Char, String)
      fields = {} of Char => String
      while (code = reader.uint8) != 0
        fields[code.chr] = reader.cstring
      end
      fields
    end

    private def self.copy_column_count(reader : Reader) : UInt16
      reader.int8 # overall format; per-column formats follow and are not needed
      reader.uint16
    end

    private def self.negotiate_protocol_version(reader : Reader) : NegotiateProtocolVersion
      newest_minor = reader.int32
      count = reader.uint32
      raise ProtocolError.new("invalid option count #{count}") if count > reader.remaining
      NegotiateProtocolVersion.new(newest_minor, Array.new(count.to_i) { reader.cstring })
    end
  end
end
