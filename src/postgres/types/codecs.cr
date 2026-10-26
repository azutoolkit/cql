require "db"
require "json"
require "uuid"
require "./oid"
require "./param"
require "./decimal_text"
require "../../compat"
require "../errors"
require "../wire/reader"

module CQL::Postgres::Types
  # Include in a class or struct that a registered codec returns.
  module Custom
  end

  # A decoded column. Built-in codecs produce `DB::Any`, `Int16`, `UInt32`,
  # `DecimalText`, `UUID`, `JSON::Any` and `Time::Span`; registered codecs return
  # `Custom` types.
  alias Value = DB::Any | Int16 | UInt32 | DecimalText | UUID | JSON::Any | Time::Span | Custom

  # How one column type travels and is turned into a Crystal value. `binary`
  # must match the result format requested in Bind: a binary codec fed text
  # (or the reverse) decodes garbage without failing.
  record Codec, binary : Bool, decode : Proc(Bytes, Value) do
    def format : Int16
      binary ? Param::BINARY : Param::TEXT
    end
  end

  EPOCH      = Time.utc(2000, 1, 1)
  TEXT_CODEC = Codec.new(false, ->(bytes : Bytes) { String.new(bytes).as(Value) })
  @@codecs = {} of UInt32 => Codec
  @@registration = CQL::Compat::Mutex.new

  # Adds or replaces the decoding of a type, e.g. an extension type. The bytes a
  # decoder receives are a private copy unless the codec is registered with
  # `borrowed: true` (the built-in ones are), which hands out a view of the
  # connection's receive buffer that is only valid during the call. The table
  # is replaced as a whole, so readers on other fibers or threads never see it
  # half-edited.
  #
  # ```
  # struct Shout
  #   include CQL::Postgres::Types::Custom
  #   getter text : String
  #
  #   def initialize(@text : String)
  #   end
  # end
  #
  # oid = 777_001_u32 # the type's OID, e.g. from pg_type
  # CQL::Postgres::Types.register(oid, binary: false) { |bytes| Shout.new(String.new(bytes)) }
  # ```
  def self.register(oid : UInt32, binary : Bool = true, borrowed : Bool = false, &decode : Bytes -> Value) : Nil
    decoder = borrowed ? decode : ->(bytes : Bytes) { decode.call(bytes.dup).as(Value) }
    @@registration.synchronize { @@codecs = @@codecs.merge({oid => Codec.new(binary, decoder)}) }
  end

  # Types without a codec arrive as text and decode to String.
  def self.codec_for(oid : UInt32) : Codec
    @@codecs[oid]? || TEXT_CODEC
  end

  def self.read_int(type : T.class, bytes : Bytes) : T forall T
    raise ProtocolError.new("expected #{sizeof(T)} bytes for #{T}, got #{bytes.size}") unless bytes.size == sizeof(T)
    bits = Wire::Reader.big_endian(bytes)
    {% if T == Float32 %}
      bits.to_u32!.unsafe_as(Float32)
    {% elsif T == Float64 %}
      bits.unsafe_as(Float64)
    {% else %}
      T.new!(bits)
    {% end %}
  end

  def self.microseconds_since_epoch(bytes : Bytes) : Time
    micros = read_int(Int64, bytes)
    raise UnsupportedValue.new("infinite timestamps are not supported") if micros == Int64::MAX || micros == Int64::MIN
    EPOCH + span_from_microseconds(micros)
  rescue ArgumentError
    raise UnsupportedValue.new("timestamp outside the range Crystal's Time supports")
  end

  def self.date(bytes : Bytes) : Time
    days = read_int(Int32, bytes)
    raise UnsupportedValue.new("infinite dates are not supported") if days == Int32::MAX || days == Int32::MIN
    EPOCH + days.days
  rescue ArgumentError
    raise UnsupportedValue.new("date outside the range Crystal's Time supports")
  end

  def self.parse_json(bytes : Bytes) : JSON::Any
    JSON.parse(String.new(bytes))
  rescue JSON::ParseException
    raise ProtocolError.new("the server sent malformed JSON")
  end

  def self.span_from_microseconds(micros : Int64) : Time::Span
    Time::Span.new(seconds: micros // 1_000_000, nanoseconds: (micros % 1_000_000) * 1000)
  end

  register(OID::BOOL, borrowed: true) { |bytes| read_int(UInt8, bytes) != 0 }
  register(OID::BYTEA, &.dup)
  register(OID::INT2, borrowed: true) { |bytes| read_int(Int16, bytes) }
  register(OID::INT4, borrowed: true) { |bytes| read_int(Int32, bytes) }
  register(OID::INT8, borrowed: true) { |bytes| read_int(Int64, bytes) }
  register(OID::OID, borrowed: true) { |bytes| read_int(UInt32, bytes) }
  register(OID::FLOAT4, borrowed: true) { |bytes| read_int(Float32, bytes) }
  register(OID::FLOAT8, borrowed: true) { |bytes| read_int(Float64, bytes) }
  register(OID::UUID, borrowed: true) { |bytes| bytes.size == 16 ? UUID.new(bytes) : raise(ProtocolError.new("expected 16 bytes for uuid, got #{bytes.size}")) }
  register(OID::DATE, borrowed: true) { |bytes| date(bytes) }
  register(OID::TIMESTAMP, borrowed: true) { |bytes| microseconds_since_epoch(bytes) }
  register(OID::TIMESTAMPTZ, borrowed: true) { |bytes| microseconds_since_epoch(bytes) }
  register(OID::TIME, borrowed: true) { |bytes| span_from_microseconds(read_int(Int64, bytes)) }
  register(OID::NUMERIC, binary: false, borrowed: true) { |bytes| DecimalText.new(String.new(bytes)) }
  register(OID::JSON, binary: false, borrowed: true) { |bytes| parse_json(bytes) }
  register(OID::JSONB, binary: false, borrowed: true) { |bytes| parse_json(bytes) }
end
