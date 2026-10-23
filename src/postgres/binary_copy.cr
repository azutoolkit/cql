require "./copy_stream"
require "./types/binary_decoder"

module CQL::Postgres
  # The framing of PostgreSQL's binary COPY format: an 11-byte signature, a
  # flags field and header extension, then one tuple per row (a field count and,
  # for each field, a length and the bytes, or -1 for NULL), closed by a field
  # count of -1.
  module BinaryCopy
    SIGNATURE = Bytes[0x50, 0x47, 0x43, 0x4f, 0x50, 0x59, 0x0a, 0xff, 0x0d, 0x0a, 0x00] # "PGCOPY\n\377\r\n\0"
    HEADER    = SIGNATURE + Bytes[0, 0, 0, 0, 0, 0, 0, 0]
    TRAILER   = Bytes[0xff, 0xff]

    # Writes rows of a `COPY ... FROM STDIN (FORMAT binary)`. *types* are the
    # OIDs of the columns in order; each value is encoded in the binary form of
    # its column's type, so an Int goes into int2/int4/int8 only if it fits and
    # nothing is converted between kinds. Only valid inside the block it was yielded to.
    class Writer
      def initialize(@copy : CopyIn, @types : Array(UInt32))
        @copy.write(HEADER)
      end

      def row(*values) : Nil
        write_row(values.to_a)
      end

      # A row held in an array (a single array-typed column goes through `row`).
      def write_row(values : Array) : Nil
        raise ArgumentError.new("the COPY has #{@types.size} columns, the row has #{values.size} values") unless values.size == @types.size
        io = IO::Memory.new
        io.write_bytes(values.size.to_i16, IO::ByteFormat::BigEndian)
        values.each_with_index { |value, index| write_field(io, value, @types[index], index) }
        @copy.write(io.to_slice)
      end

      # :nodoc:
      def finish : Nil
        @copy.write(TRAILER)
      end

      private def nul?(value) : Bool
        value.is_a?(String) && value.includes?('\0')
      end

      private def write_field(io : IO, value, oid : UInt32, index : Int32) : Nil
        if value.nil?
          io.write_bytes(-1_i32, IO::ByteFormat::BigEndian)
          return
        end
        bytes = Types::Binary.encode(value, oid) || raise ArgumentError.new("column #{index + 1} (type #{oid}) cannot take a #{value.class} in binary#{nul?(value) ? " (it holds a NUL byte)" : ""}")
        io.write_bytes(bytes.size.to_i32, IO::ByteFormat::BigEndian)
        io.write(bytes)
      end
    end

    # Cuts the chunks of a `COPY ... TO STDOUT (FORMAT binary)` back into rows,
    # whatever the chunk boundaries are, and decodes each field by its column
    # type. A row is decoded once, when all of it has arrived; until then only
    # its field lengths are walked, and the bytes are not copied again.
    class Reader
      # Consumed bytes are dropped from the buffer once this many have piled up.
      COMPACT_AFTER = 1 << 20

      def initialize(@types : Array(UInt32), &@on_row : Array(Types::Value) ->)
        @buffer = IO::Memory.new
        @header_read = false
        @done = false
      end

      def feed(chunk : Bytes) : Nil
        raise ProtocolError.new("data after the end of the binary COPY") if @done
        append(chunk)
        read_header unless @header_read
        while @header_read && !@done && (tuple = next_tuple)
          @on_row.call(tuple)
        end
        raise ProtocolError.new("data after the end of the binary COPY") if @done && available > 0
        reclaim
      end

      # Raises unless the stream ended with the trailer.
      def finish : Nil
        raise ProtocolError.new("the binary COPY ended before its trailer") unless @done
      end

      private def append(chunk : Bytes) : Nil
        position = @buffer.pos
        @buffer.seek(0, IO::Seek::End)
        @buffer.write(chunk)
        @buffer.pos = position
      end

      private def available : Int32
        @buffer.size.to_i - @buffer.pos.to_i
      end

      private def read_header : Nil
        return if available < HEADER.size
        head = Bytes.new(HEADER.size)
        @buffer.read_fully(head)
        raise ProtocolError.new("the COPY data does not start with the binary COPY signature") unless head[0, SIGNATURE.size] == SIGNATURE
        flags = Types.read_int(UInt32, head[11, 4])
        raise ProtocolError.new("binary COPY flags #{flags} are not supported") unless flags == 0
        extension = Types.read_int(UInt32, head[15, 4])
        raise ProtocolError.new("binary COPY header extensions are not supported") unless extension == 0
        @header_read = true
      end

      # The next row, or nil when it has not fully arrived (or the trailer came).
      private def next_tuple : Array(Types::Value)?
        return if available < 2
        count = peek_int16(0)
        if count == -1
          @buffer.pos += 2
          @done = true
          return
        end
        raise ProtocolError.new("a binary COPY row has #{count} fields for #{@types.size} columns") unless count == @types.size
        return unless row_complete?
        @buffer.pos += 2
        @types.map { |oid| read_field(oid) }
      end

      # Walks the field lengths of the row at the read position.
      private def row_complete? : Bool
        offset = 2
        @types.size.times do
          return false if available < offset + 4
          size = peek_int32(offset)
          raise ProtocolError.new("a binary COPY field has length #{size}") if size < -1
          offset += 4 + Math.max(size, 0)
          return false if available < offset
        end
        true
      end

      private def read_field(oid : UInt32) : Types::Value
        size = @buffer.read_bytes(Int32, IO::ByteFormat::BigEndian)
        return if size == -1
        field = @buffer.to_slice[@buffer.pos, size]
        @buffer.pos += size
        Types::Binary.decode(oid, field)
      end

      private def peek_int16(offset : Int32) : Int16
        Types.read_int(Int16, @buffer.to_slice[@buffer.pos + offset, 2])
      end

      private def peek_int32(offset : Int32) : Int32
        Types.read_int(Int32, @buffer.to_slice[@buffer.pos + offset, 4])
      end

      # Starts over with the unread tail once enough has been consumed.
      private def reclaim : Nil
        if available == 0
          @buffer = IO::Memory.new
        elsif @buffer.pos >= COMPACT_AFTER
          rest = @buffer.to_slice[@buffer.pos, available].dup
          @buffer = IO::Memory.new
          @buffer.write(rest)
          @buffer.rewind
        end
      end
    end
  end
end
