require "json"
require "uuid"
require "./oid"
require "./decimal_text"

module CQL::Postgres::Types
  # PostgreSQL's binary wire format for values going to the server: bind
  # parameters (chosen per parameter once the server has reported its types) and
  # binary COPY. `encode` returns nil when the pair of Crystal value and server
  # type has no binary form here; the caller then sends text, which the server
  # parses as it always did.
  #
  # Binary is only produced where it means the same thing as the text form: an
  # integer must fit the server's width, a `Float32` is widened through its
  # printed form, a `Float64` is never narrowed, and a `Time` is cut to
  # microseconds like its text form. Nothing here puts a value into an error.
  module Binary
    EPOCH_UNIX = Time.utc(2000, 1, 1).to_unix

    ARRAY_ELEMENT = {
      OID::BOOL_ARRAY => OID::BOOL, OID::INT2_ARRAY => OID::INT2, OID::INT4_ARRAY => OID::INT4, OID::INT8_ARRAY => OID::INT8,
      OID::FLOAT4_ARRAY => OID::FLOAT4, OID::FLOAT8_ARRAY => OID::FLOAT8, OID::TEXT_ARRAY => OID::TEXT,
      OID::VARCHAR_ARRAY => OID::VARCHAR, OID::BPCHAR_ARRAY => OID::BPCHAR, OID::UUID_ARRAY => OID::UUID,
      OID::DATE_ARRAY => OID::DATE, OID::TIMESTAMP_ARRAY => OID::TIMESTAMP, OID::TIMESTAMPTZ_ARRAY => OID::TIMESTAMPTZ,
      OID::NUMERIC_ARRAY => OID::NUMERIC, OID::JSONB_ARRAY => OID::JSONB,
    }

    # Types whose binary form is their text, so a String goes in as it is.
    TEXTUAL = [OID::TEXT, OID::VARCHAR, OID::BPCHAR, OID::NAME, OID::JSON]

    # What CockroachDB 24.3 reads differently from the text of the same value
    # (checked against a live node): a float4 comes back widened to a float8
    # (0.1 as 0.10000000149011612), and a numeric loses its trailing zeros
    # ("100000000" as 1E+8, "-0.00" as 0). They stay text there.
    COCKROACHDB_TEXT_ONLY = [OID::FLOAT4, OID::NUMERIC, OID::FLOAT4_ARRAY, OID::NUMERIC_ARRAY]

    # The values that may wait for the server's parameter types.
    def self.supported?(value : Bool | Int | Float | UUID | DecimalText | Time | JSON::Any | Array) : Bool
      true
    end

    def self.supported?(value) : Bool
      false
    end

    # A rough size of the value on the wire (the elements of an array added up).
    def self.size_hint(value : Array) : Int32
      value.sum(16) { |element| size_hint(element) }
    end

    def self.size_hint(value : String | Bytes) : Int32
      value.bytesize + 4
    end

    def self.size_hint(value : DecimalText) : Int32
      value.text.bytesize + 4
    end

    def self.size_hint(value : JSON::Any) : Int32
      value.to_json.bytesize + 4
    end

    # Numbers, times and uuids: a bound that covers their text form (a time is 29
    # characters, a uuid 36, an Int128 up to 40), since that is what goes out when
    # no binary form applies. Deliberately generous: an array of them splits a
    # pipeline batch earlier than strictly needed, which costs a round trip, never a stall.
    def self.size_hint(value) : Int32
      40
    end

    def self.encode(value : Bool, oid : UInt32) : Bytes?
      oid == OID::BOOL ? Bytes[value ? 1_u8 : 0_u8] : nil
    end

    def self.encode(value : Int, oid : UInt32) : Bytes?
      case oid
      when OID::INT2    then value >= Int16::MIN && value <= Int16::MAX ? integer(value.to_i16!) : nil
      when OID::INT4    then value >= Int32::MIN && value <= Int32::MAX ? integer(value.to_i32!) : nil
      when OID::INT8    then value >= Int64::MIN && value <= Int64::MAX ? integer(value.to_i64!) : nil
      when OID::NUMERIC then numeric(value.to_s)
      end
    end

    def self.encode(value : Float32, oid : UInt32) : Bytes?
      case oid
      when OID::FLOAT4 then integer(value.unsafe_as(UInt32))
      when OID::FLOAT8 then value.to_s.to_f64?.try { |widened| integer(widened.unsafe_as(UInt64)) }
      end
    end

    def self.encode(value : Float64, oid : UInt32) : Bytes?
      oid == OID::FLOAT8 ? integer(value.unsafe_as(UInt64)) : nil
    end

    def self.encode(value : UUID, oid : UInt32) : Bytes?
      oid == OID::UUID ? value.bytes.to_slice.dup : nil
    end

    def self.encode(value : Time, oid : UInt32) : Bytes?
      utc = value.to_utc
      case oid
      when OID::TIMESTAMP, OID::TIMESTAMPTZ then integer((utc.to_unix - EPOCH_UNIX) * 1_000_000_i64 + utc.nanosecond // 1000)
      when OID::DATE                        then integer(((utc.to_unix - EPOCH_UNIX) // 86_400).to_i32)
      end
    end

    def self.encode(value : DecimalText, oid : UInt32) : Bytes?
      oid == OID::NUMERIC ? numeric(value.text) : nil
    end

    def self.encode(value : JSON::Any, oid : UInt32) : Bytes?
      json = value.to_json
      case oid
      when OID::JSON  then json.to_slice
      when OID::JSONB then Bytes.new(json.bytesize + 1).tap { |bytes| bytes[0] = 1_u8; json.to_slice.copy_to(bytes + 1) }
      end
    end

    def self.encode(value : String, oid : UInt32) : Bytes?
      TEXTUAL.includes?(oid) && !value.includes?('\0') ? value.to_slice : nil
    end

    def self.encode(value : Bytes, oid : UInt32) : Bytes?
      oid == OID::BYTEA ? value : nil
    end

    def self.encode(value : Array, oid : UInt32) : Bytes?
      element_oid = ARRAY_ELEMENT[oid]? || return
      return array_header(0, false, element_oid, [] of Int32) if value.empty?
      shape = ArrayShape.new
      return unless shape.add(value, 0, element_oid)
      body = array_header(shape.dimensions.size, shape.nulls?, element_oid, shape.dimensions)
      io = IO::Memory.new(body.size + shape.cells.sum { |cell| 4 + (cell.try(&.size) || 0) })
      io.write(body)
      shape.cells.each do |cell|
        cell ? (write_int(io, cell.size); io.write(cell)) : write_int(io, -1)
      end
      io.to_slice
    end

    def self.encode(value, oid : UInt32) : Bytes?
      nil
    end

    # The cells of a (possibly nested) Crystal array, flattened in row-major
    # order, and the length of each dimension. Ragged arrays are refused.
    private class ArrayShape
      getter dimensions = [] of Int32
      getter cells = [] of Bytes?
      @leaf_depth : Int32? = nil

      def nulls? : Bool
        cells.any?(Nil)
      end

      def add(array : Array, depth : Int32, element_oid : UInt32) : Bool
        return false if array.empty?
        if dimensions.size <= depth
          dimensions << array.size
        elsif dimensions[depth] != array.size
          return false
        end
        array.all? { |element| add_element(element, depth, element_oid) }
      end

      private def add_cell(cell : Bytes?) : Bool
        cells << cell
        true
      end

      private def add_element(element, depth : Int32, element_oid : UInt32) : Bool
        if element.is_a?(Array)
          return false if @leaf_depth == depth
          add(element, depth + 1, element_oid)
        else
          return false if @leaf_depth && @leaf_depth != depth
          @leaf_depth = depth
          return add_cell(nil) if element.nil?
          cell = Binary.encode(element, element_oid)
          cell ? add_cell(cell) : false
        end
      end
    end

    private def self.array_header(ndim : Int32, nulls : Bool, element_oid : UInt32, dimensions : Array(Int32)) : Bytes
      io = IO::Memory.new
      write_int(io, ndim)
      write_int(io, nulls ? 1 : 0)
      write_int(io, element_oid.to_i32!)
      dimensions.each { |length| write_int(io, length); write_int(io, 1) }
      io.to_slice
    end

    private def self.write_int(io : IO, value : Int32) : Nil
      io.write_bytes(value, IO::ByteFormat::BigEndian)
    end

    private def self.integer(value : Int) : Bytes
      Bytes.new(sizeof(typeof(value))).tap { |bytes| IO::ByteFormat::BigEndian.encode(value, bytes) }
    end

    NUMERIC_POSITIVE  = 0x0000_u16
    NUMERIC_NEGATIVE  = 0x4000_u16
    NUMERIC_MAX_SCALE =      16383

    # numeric: base-10000 digits, the weight of the first digit group, a sign
    # and the number of decimal digits after the point. Only plain decimals
    # ("-12.50") are converted; NaN, infinities and exponent forms go as text.
    def self.numeric(text : String) : Bytes?
      match = /\A([+-]?)([0-9]*)(?:\.([0-9]*))?\z/.match(text) || return
      whole, fraction = match[2], match[3]? || ""
      return if whole.empty? && fraction.empty? || fraction.size > NUMERIC_MAX_SCALE
      groups = digit_groups(whole.lstrip('0'), fraction)
      weight = (whole.lstrip('0').size + 3) // 4 - 1
      while (first = groups.first?) && first == 0
        groups.shift
        weight -= 1
      end
      while groups.last? == 0
        groups.pop
      end
      return if groups.size > Int16::MAX || weight > Int16::MAX || weight < Int16::MIN
      negative = match[1] == "-" && !groups.empty?
      io = IO::Memory.new(8 + groups.size * 2)
      io.write_bytes(groups.size.to_i16, IO::ByteFormat::BigEndian)
      io.write_bytes((groups.empty? ? 0 : weight).to_i16, IO::ByteFormat::BigEndian)
      io.write_bytes(negative ? NUMERIC_NEGATIVE : NUMERIC_POSITIVE, IO::ByteFormat::BigEndian)
      io.write_bytes(fraction.size.to_u16, IO::ByteFormat::BigEndian)
      groups.each { |group| io.write_bytes(group.to_i16, IO::ByteFormat::BigEndian) }
      io.to_slice
    end

    # The integer part padded on the left and the fraction on the right to whole
    # groups of four digits, each group read as a number.
    private def self.digit_groups(whole : String, fraction : String) : Array(Int32)
      padded = whole.rjust((whole.size + 3) // 4 * 4, '0') + fraction.ljust((fraction.size + 3) // 4 * 4, '0')
      Array.new(padded.size // 4) { |index| padded[index * 4, 4].to_i }
    end
  end
end
