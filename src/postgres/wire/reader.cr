require "../errors"

module CQL::Postgres::Wire
  # Big-endian cursor over one backend message payload.
  class Reader
    def initialize(@bytes : Bytes)
      @pos = 0
    end

    def remaining : Int32
      @bytes.size - @pos
    end

    def int8 : Int8
      take(1)[0].to_i8!
    end

    def uint8 : UInt8
      take(1)[0]
    end

    def uint16 : UInt16
      Reader.big_endian(take(2)).to_u16!
    end

    def int16 : Int16
      Reader.big_endian(take(2)).to_i16!
    end

    def int32 : Int32
      Reader.big_endian(take(4)).to_i32!
    end

    def uint32 : UInt32
      Reader.big_endian(take(4)).to_u32!
    end

    # Up to 8 bytes as one big-endian unsigned number. Shifting is several times
    # cheaper than IO::ByteFormat, which copies through a StaticArray.
    def self.big_endian(bytes : Bytes) : UInt64
      value = 0_u64
      index = 0
      while index < bytes.size
        value = value &* 256_u64 &+ bytes.unsafe_fetch(index)
        index += 1
      end
      value
    end

    def char : Char
      uint8.chr
    end

    # Null-terminated string.
    def cstring : String
      terminator = @bytes[@pos..].index(0_u8) || raise ProtocolError.new("unterminated string in message")
      String.new(take(terminator)).tap { @pos += 1 }
    end

    def bytes(count : Int32) : Bytes
      take(count)
    end

    def rest : Bytes
      take(remaining)
    end

    # The returned slices alias the message payload; nothing copies them.
    private def take(count : Int32) : Bytes
      raise ProtocolError.new("message truncated") if count < 0 || count > remaining
      Bytes.new(@bytes.to_unsafe + @pos, count, read_only: @bytes.read_only?).tap { @pos += count }
    end
  end
end
