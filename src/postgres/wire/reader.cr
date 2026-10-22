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
      IO::ByteFormat::NetworkEndian.decode(UInt16, take(2))
    end

    def int16 : Int16
      IO::ByteFormat::NetworkEndian.decode(Int16, take(2))
    end

    def int32 : Int32
      IO::ByteFormat::NetworkEndian.decode(Int32, take(4))
    end

    def uint32 : UInt32
      IO::ByteFormat::NetworkEndian.decode(UInt32, take(4))
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
      @bytes[@pos, count].tap { @pos += count }
    end
  end
end
