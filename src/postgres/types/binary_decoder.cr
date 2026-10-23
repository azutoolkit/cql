require "./codecs"
require "./binary"

module CQL::Postgres::Types
  module Binary
    # One field of a binary COPY row. Types without a decoder here come back as
    # the raw bytes the server sent.
    def self.decode(oid : UInt32, bytes : Bytes) : Value
      case oid
      when OID::TEXT, OID::VARCHAR, OID::BPCHAR, OID::NAME then String.new(bytes)
      when OID::NUMERIC                                    then DecimalText.new(numeric_text(bytes))
      when OID::JSON                                       then Types.parse_json(bytes)
      when OID::JSONB                                      then jsonb(bytes)
      else
        codec = Types.codec_for(oid)
        codec.binary ? codec.decode.call(bytes) : bytes.dup
      end
    end

    private def self.jsonb(bytes : Bytes) : Value
      raise ProtocolError.new("unsupported jsonb version #{bytes[0]?}") unless bytes[0]? == 1
      Types.parse_json(bytes + 1)
    end

    # The decimal text of a binary numeric (see `numeric`).
    def self.numeric_text(bytes : Bytes) : String
      raise ProtocolError.new("numeric needs at least 8 bytes, got #{bytes.size}") if bytes.size < 8
      count = Types.read_int(Int16, bytes[0, 2])
      weight = Types.read_int(Int16, bytes[2, 2]).to_i
      sign = Types.read_int(UInt16, bytes[4, 2])
      scale = Types.read_int(UInt16, bytes[6, 2]).to_i
      raise ProtocolError.new("numeric digits do not match their count") unless count >= 0 && bytes.size == 8 + count * 2
      return special_numeric(sign) if sign != NUMERIC_POSITIVE && sign != NUMERIC_NEGATIVE
      groups = Array.new(count.to_i) { |index| Types.read_int(Int16, bytes[8 + index * 2, 2]).to_i }
      "#{sign == NUMERIC_NEGATIVE ? "-" : ""}#{integer_digits(groups, weight)}#{fraction_digits(groups, weight, scale)}"
    end

    private def self.special_numeric(sign : UInt16) : String
      case sign
      when 0xC000_u16 then "NaN"
      when 0xD000_u16 then "Infinity"
      when 0xF000_u16 then "-Infinity"
      else                 raise ProtocolError.new("unknown numeric sign #{sign}")
      end
    end

    private def self.integer_digits(groups : Array(Int32), weight : Int32) : String
      return "0" if weight < 0
      String.build do |io|
        (0..weight).each do |index|
          group = groups[index]? || 0
          index == 0 ? io << group : io << group.to_s.rjust(4, '0')
        end
      end
    end

    private def self.fraction_digits(groups : Array(Int32), weight : Int32, scale : Int32) : String
      return "" if scale == 0
      digits = String.build do |io|
        (1..(scale + 3) // 4).each do |step|
          index = weight + step
          io << (index >= 0 ? groups[index]? || 0 : 0).to_s.rjust(4, '0')
        end
      end
      ".#{digits[0, scale]}"
    end
  end
end
