require "db"
require "json"
require "uuid"
require "./oid"
require "./param"
require "./decimal_text"
require "../../compat"
require "../errors"

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

  # Adds or replaces the decoding of a type, e.g. an extension type. The table
  # is replaced as a whole, so readers on other fibers or threads never see it
  # half-edited.
  #
  # ```
  # CQL::Postgres::Types.register(oid, binary: false) { |bytes| MyType.parse(String.new(bytes)) } # MyType includes Types::Custom
  # ```
  def self.register(oid : UInt32, binary : Bool = true, &decode : Bytes -> Value) : Nil
    @@registration.synchronize { @@codecs = @@codecs.merge({oid => Codec.new(binary, decode)}) }
  end

  # Types without a codec arrive as text and decode to String.
  def self.codec_for(oid : UInt32) : Codec
    @@codecs[oid]? || TEXT_CODEC
  end

  def self.read_int(type : T.class, bytes : Bytes) : T forall T
    raise ProtocolError.new("expected #{sizeof(T)} bytes for #{T}, got #{bytes.size}") unless bytes.size == sizeof(T)
    IO::ByteFormat::NetworkEndian.decode(type, bytes)
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

  register(OID::BOOL) { |bytes| read_int(UInt8, bytes) != 0 }
  register(OID::BYTEA, &.dup)
  register(OID::INT2) { |bytes| read_int(Int16, bytes) }
  register(OID::INT4) { |bytes| read_int(Int32, bytes) }
  register(OID::INT8) { |bytes| read_int(Int64, bytes) }
  register(OID::OID) { |bytes| read_int(UInt32, bytes) }
  register(OID::FLOAT4) { |bytes| read_int(Float32, bytes) }
  register(OID::FLOAT8) { |bytes| read_int(Float64, bytes) }
  register(OID::UUID) { |bytes| bytes.size == 16 ? UUID.new(bytes) : raise(ProtocolError.new("expected 16 bytes for uuid, got #{bytes.size}")) }
  register(OID::DATE) { |bytes| date(bytes) }
  register(OID::TIMESTAMP) { |bytes| microseconds_since_epoch(bytes) }
  register(OID::TIMESTAMPTZ) { |bytes| microseconds_since_epoch(bytes) }
  register(OID::TIME) { |bytes| span_from_microseconds(read_int(Int64, bytes)) }
  register(OID::NUMERIC, binary: false) { |bytes| DecimalText.new(String.new(bytes)) }
  register(OID::JSON, binary: false) { |bytes| parse_json(bytes) }
  register(OID::JSONB, binary: false) { |bytes| parse_json(bytes) }
end
