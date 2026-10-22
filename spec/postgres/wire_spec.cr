require "../spec_helper"
require "../../src/postgres"

private alias Wire = CQL::Postgres::Wire
private alias Types = CQL::Postgres::Types

private def frame_bytes(&)
  io = IO::Memory.new
  yield io
  io.to_slice.hexstring
end

private def backend(type : Char, payload_hex : String = "")
  payload = payload_hex.hexbytes
  io = IO::Memory.new
  io.write_byte(type.ord.to_u8)
  io.write_bytes(payload.size + 4, IO::ByteFormat::NetworkEndian)
  io.write(payload)
  io.rewind
  Wire::Backend.read(io)
end

private struct Shout
  include CQL::Postgres::Types::Custom
  getter text : String

  def initialize(text : String)
    @text = text.upcase
  end
end

private def encoded(value)
  param = CQL::Postgres::Types::ParamEncoder.encode(value)
  {param.value.try { |bytes| String.new(bytes) }, param.format}
end

private def error_for(code : String, extra = {} of Char => String)
  CQL::Postgres::ServerError.from({'S' => "ERROR", 'C' => code, 'M' => "boom"}.merge(extra))
end

describe CQL::Postgres::Wire::Frontend do
  it "encodes the v3.0 startup packet" do
    frame_bytes { |io| Wire::Frontend.startup(io, {"user" => "u", "database" => "d"}) }
      .should eq "0000001b0003000075736572007500646174616261736500640000"
  end

  it "encodes SSLRequest and CancelRequest" do
    frame_bytes { |io| Wire::Frontend.ssl_request(io) }.should eq "0000000804d2162f"
    frame_bytes { |io| Wire::Frontend.cancel_request(io, 1, 2) }.should eq "0000001004d2162e0000000100000002"
  end

  it "encodes simple queries and terminate" do
    frame_bytes { |io| Wire::Frontend.query(io, "SELECT 1") }.should eq "510000000d53454c4543542031" + "00"
    frame_bytes { |io| Wire::Frontend.terminate(io) }.should eq "5800000004"
    frame_bytes { |io| Wire::Frontend.sync(io) }.should eq "5300000004"
  end

  it "encodes Parse with no declared parameter types" do
    frame_bytes { |io| Wire::Frontend.parse(io, "s1", "SELECT $1") }
      .should eq "50000000" + "13" + "7331" + "00" + "53454c4543542024" + "31" + "00" + "0000"
  end

  it "encodes Bind with text, binary and NULL parameters and result formats" do
    params = [Types::Param.text("42"), Types::Param.binary(Bytes[1, 2]), Types::Param.null]
    frame_bytes { |io| Wire::Frontend.bind(io, "s1", params, [1_i16, 0_i16]) }.should eq(
      "42" + "00000028" + "00" + "7331" + "00" + "0003" + "000000010000" + "0003" +
      "00000002" + "3432" + "00000002" + "0102" + "ffffffff" + "0002" + "00010000"
    )
  end

  it "encodes Describe, Execute, Close" do
    frame_bytes { |io| Wire::Frontend.describe_statement(io, "s1") }.should eq "44000000085373" + "3100"
    frame_bytes { |io| Wire::Frontend.execute(io) }.should eq "450000000900" + "00000000"
    frame_bytes { |io| Wire::Frontend.close_statement(io, "s1") }.should eq "43000000085373" + "3100"
  end

  it "encodes SASL and copy messages" do
    frame_bytes { |io| Wire::Frontend.sasl_initial_response(io, "SCRAM-SHA-256", "n,,".to_slice) }
      .should eq "70" + "00000019" + "534352414d2d5348412d323536" + "00" + "00000003" + "6e2c2c"
    frame_bytes { |io| Wire::Frontend.copy_data(io, Bytes[7]) }.should eq "6400000005" + "07"
    frame_bytes { |io| Wire::Frontend.copy_done(io) }.should eq "6300000004"
  end

  it "encodes password, SASL response, copy failure and flush" do
    frame_bytes { |io| Wire::Frontend.password(io, "pw") }.should eq "70" + "00000007" + "707700"
    frame_bytes { |io| Wire::Frontend.sasl_response(io, Bytes[1]) }.should eq "70" + "00000005" + "01"
    frame_bytes { |io| Wire::Frontend.copy_fail(io, "no") }.should eq "66" + "00000007" + "6e6f00"
    frame_bytes { |io| Wire::Frontend.flush(io) }.should eq "4800000004"
  end

  it "rejects NUL bytes that would split a protocol string" do
    expect_raises(ArgumentError, /NUL/) { Wire::Frontend.query(IO::Memory.new, "SELECT 1\0; DROP TABLE x") }
    expect_raises(ArgumentError, /NUL/) { Wire::Frontend.password(IO::Memory.new, "pw\0") }
    expect_raises(ArgumentError, /NUL/) { Wire::Frontend.startup(IO::Memory.new, {"user" => "u\0x"}) }
    io = IO::Memory.new
    expect_raises(ArgumentError) { Wire::Frontend.query(io, "x\0") }
    io.size.should eq 0
  end

  it "counts parameters as unsigned 16-bit and refuses more than the protocol allows" do
    params = Array.new(40_000) { Types::Param.null }
    io = IO::Memory.new
    Wire::Frontend.bind(io, "", params, [] of Int16)
    io.to_slice[7, 2].should eq Bytes[0x9c, 0x40] # 40000 as an unsigned 16-bit count
    expect_raises(ArgumentError, /at most 65535/) { Wire::Frontend.bind(IO::Memory.new, "", Array.new(65_536) { Types::Param.null }, [] of Int16) }
  end
end

describe CQL::Postgres::Wire::Backend do
  it "decodes authentication requests" do
    backend('R', "00000000").should be_a Wire::Backend::AuthenticationOk
    backend('R', "00000003").should be_a Wire::Backend::AuthenticationCleartext
    backend('R', "00000005" + "01020304").as(Wire::Backend::AuthenticationMD5).salt.should eq Bytes[1, 2, 3, 4]
    sasl = backend('R', "0000000a" + "SCRAM-SHA-256".to_slice.hexstring + "00" + "00")
    sasl.as(Wire::Backend::AuthenticationSASL).mechanisms.should eq ["SCRAM-SHA-256"]
    backend('R', "0000000b" + "r=abc".to_slice.hexstring).as(Wire::Backend::AuthenticationSASLContinue).data.should eq "r=abc".to_slice
    backend('R', "0000000c" + "v=xyz".to_slice.hexstring).as(Wire::Backend::AuthenticationSASLFinal).data.should eq "v=xyz".to_slice
  end

  it "tells authentication methods it does not implement apart from nonsense" do
    {2, 6, 7, 8, 9}.each do |code|
      expect_raises(CQL::Postgres::AuthenticationError, /method #{code}/) { backend('R', "%08x" % code) }
    end
    expect_raises(CQL::Postgres::ProtocolError, /unknown authentication method 99/) { backend('R', "%08x" % 99) }
  end

  it "hands an ErrorResponse to ServerError" do
    fields = "C".to_slice.hexstring + "23505".to_slice.hexstring + "00" + "00"
    CQL::Postgres::ServerError.from(backend('E', fields).as(Wire::Backend::ErrorResponse).fields).should be_a CQL::Postgres::UniqueViolation
  end

  it "decodes ParameterStatus, BackendKeyData and ReadyForQuery" do
    backend('S', "ab".to_slice.hexstring + "00" + "cd".to_slice.hexstring + "00").as(Wire::Backend::ParameterStatus).value.should eq "cd"
    key = backend('K', "00000007" + "00000009").as(Wire::Backend::BackendKeyData)
    {key.process_id, key.secret_key}.should eq({7, 9})
    backend('Z', "49").as(Wire::Backend::ReadyForQuery).status.should eq 'I'
  end

  it "decodes RowDescription and DataRow with NULLs" do
    column = "id".to_slice.hexstring + "00" + "00000000" + "0000" + "00000017" + "0004" + "ffffffff" + "0001"
    field = backend('T', "0001" + column).as(Wire::Backend::RowDescription).fields.first
    {field.name, field.type_oid}.should eq({"id", 23_u32})
    row = backend('D', "0002" + "00000002" + "3432" + "ffffffff").as(Wire::Backend::DataRow)
    row.values.should eq [Bytes[0x34, 0x32], nil]
  end

  it "decodes CommandComplete row counts" do
    backend('C', "INSERT 0 5".to_slice.hexstring + "00").as(Wire::Backend::CommandComplete).rows_affected.should eq 5
    backend('C', "BEGIN".to_slice.hexstring + "00").as(Wire::Backend::CommandComplete).rows_affected.should eq 0
  end

  it "decodes ErrorResponse and NoticeResponse fields" do
    body = "S".to_slice.hexstring + "ERROR".to_slice.hexstring + "00" + "C".to_slice.hexstring + "23505".to_slice.hexstring + "00" + "M".to_slice.hexstring + "dupl".to_slice.hexstring + "00" + "00"
    error = backend('E', body).as(Wire::Backend::ErrorResponse)
    error.fields['C'].should eq "23505"
    error.fields['M'].should eq "dupl"
    backend('N', body).should be_a Wire::Backend::NoticeResponse
  end

  it "decodes notifications, parameter descriptions and empty-body messages" do
    note = backend('A', "00000005" + "chan".to_slice.hexstring + "00" + "hi".to_slice.hexstring + "00").as(Wire::Backend::NotificationResponse)
    {note.process_id, note.channel, note.payload}.should eq({5, "chan", "hi"})
    backend('t', "0002" + "00000017" + "00000019").as(Wire::Backend::ParameterDescription).type_oids.should eq [23_u32, 25_u32]
    backend('1').should be_a Wire::Backend::ParseComplete
    backend('n').should be_a Wire::Backend::NoData
    backend('I').should be_a Wire::Backend::EmptyQueryResponse
  end

  it "rejects hostile lengths before allocating for them" do
    too_big = "5a" + (CQL::Postgres::Wire::Backend::MAX_MESSAGE_SIZE + 5).to_s(16).rjust(8, '0')
    expect_raises(CQL::Postgres::ProtocolError, /invalid message length/) { Wire::Backend.read(IO::Memory.new(too_big.hexbytes)) }
    expect_raises(CQL::Postgres::ProtocolError, /invalid message length/) { Wire::Backend.read(IO::Memory.new("5a80000000".hexbytes)) }
    expect_raises(CQL::Postgres::ProtocolError, /invalid message length/) { Wire::Backend.read(IO::Memory.new("5a00001000".hexbytes), max_size: 16) }
  end

  it "accepts a message exactly at the size limit and refuses one byte over" do
    exact = "5a" + "%08x" % (16 + 4) + "00" * 16
    expect_raises(CQL::Postgres::ProtocolError, /transaction status/) { Wire::Backend.read(IO::Memory.new(exact.hexbytes), max_size: 16) }
    over = "5a" + "%08x" % (17 + 4) + "00" * 17
    expect_raises(CQL::Postgres::ProtocolError, /invalid message length/) { Wire::Backend.read(IO::Memory.new(over.hexbytes), max_size: 16) }
  end

  it "reads big payloads in chunks and reports a short stream as EOF" do
    claimed = "5a" + (CQL::Postgres::Wire::Backend::EAGER_READ_SIZE * 4).to_s(16).rjust(8, '0')
    expect_raises(IO::EOFError) { Wire::Backend.read(IO::Memory.new(claimed.hexbytes)) }
    big = backend('d', "ab" * (CQL::Postgres::Wire::Backend::EAGER_READ_SIZE * 2))
    big.as(Wire::Backend::CopyData).data.size.should eq CQL::Postgres::Wire::Backend::EAGER_READ_SIZE * 2
  end

  it "bounds the NegotiateProtocolVersion option count by the payload" do
    expect_raises(CQL::Postgres::ProtocolError, /option count/) { backend('v', "00000000" + "7fffffff") }
    expect_raises(CQL::Postgres::ProtocolError, /option count/) { backend('v', "00000000" + "ffffffff") }
  end

  it "reads every 16-bit count as unsigned" do
    expect_raises(CQL::Postgres::ProtocolError, /truncated/) { backend('t', "8000" + "00000017") }
    expect_raises(CQL::Postgres::ProtocolError) { backend('T', "ffff") }
    expect_raises(CQL::Postgres::ProtocolError, /truncated/) { backend('D', "8000") }
    backend('G', "00" + "ffff").as(Wire::Backend::CopyResponse).column_count.should eq 65535
  end

  it "reads field counts as unsigned and only -1 as NULL" do
    expect_raises(CQL::Postgres::ProtocolError, /invalid field length -2/) { backend('D', "0001" + "fffffffe") }
    backend('t', "0000").as(Wire::Backend::ParameterDescription).type_oids.should be_empty
  end

  it "accepts only I, T and E as transaction status" do
    expect_raises(CQL::Postgres::ProtocolError, /transaction status/) { backend('Z', "58") }
  end

  it "decodes NegotiateProtocolVersion" do
    negotiation = backend('v', "00000000" + "00000001" + "_pq_.x".to_slice.hexstring + "00").as(Wire::Backend::NegotiateProtocolVersion)
    negotiation.unrecognized.should eq ["_pq_.x"]
  end

  it "decodes copy responses" do
    backend('G', "00" + "0001" + "0000").as(Wire::Backend::CopyResponse).direction.should eq 'G'
    backend('H', "00" + "0002" + "00000000").as(Wire::Backend::CopyResponse).column_count.should eq 2
  end

  it "rejects unknown types, bad lengths and truncated payloads" do
    expect_raises(CQL::Postgres::ProtocolError, /unexpected message type/) { backend('~') }
    expect_raises(CQL::Postgres::ProtocolError, /invalid message length/) { Wire::Backend.read(IO::Memory.new("5a00000002".hexbytes)) }
    expect_raises(CQL::Postgres::ProtocolError, /truncated/) { backend('K', "00000007") }
    expect_raises(CQL::Postgres::ProtocolError, /unterminated/) { backend('C', "BEGIN".to_slice.hexstring) }
    expect_raises(IO::EOFError) { Wire::Backend.read(IO::Memory.new) }
  end
end

describe CQL::Postgres::Types do
  it "decodes binary integers, floats and booleans" do
    Types.codec_for(Types::OID::INT4).decode.call(Bytes[0, 0, 1, 0]).should eq 256
    Types.codec_for(Types::OID::INT2).decode.call(Bytes[0xff, 0xfe]).should eq -2_i16
    Types.codec_for(Types::OID::INT8).decode.call(Bytes[0, 0, 0, 0, 0, 0, 1, 0]).should eq 256_i64
    Types.codec_for(Types::OID::FLOAT8).decode.call(Bytes[0x3f, 0xf8, 0, 0, 0, 0, 0, 0]).should eq 1.5
    Types.codec_for(Types::OID::FLOAT4).decode.call(Bytes[0x3f, 0xc0, 0, 0]).should eq 1.5_f32
    Types.codec_for(Types::OID::BOOL).decode.call(Bytes[1]).should eq true
    Types.codec_for(Types::OID::BOOL).decode.call(Bytes[0]).should eq false
  end

  it "rejects values whose size does not match the type instead of reading garbage" do
    expect_raises(CQL::Postgres::ProtocolError, /expected 4 bytes/) { Types.codec_for(Types::OID::INT4).decode.call(Bytes[1, 2]) }
    expect_raises(CQL::Postgres::ProtocolError, /expected 8 bytes/) { Types.codec_for(Types::OID::FLOAT8).decode.call(Bytes[1]) }
    expect_raises(CQL::Postgres::ProtocolError, /expected 16 bytes/) { Types.codec_for(Types::OID::UUID).decode.call(Bytes[1]) }
    expect_raises(CQL::Postgres::ProtocolError, /expected 1 bytes/) { Types.codec_for(Types::OID::BOOL).decode.call(Bytes.empty) }
  end

  it "decodes dates, timestamps (including before 2000) and times" do
    Types.codec_for(Types::OID::DATE).decode.call(Bytes[0, 0, 0, 1]).should eq Time.utc(2000, 1, 2)
    Types.codec_for(Types::OID::TIMESTAMPTZ).decode.call(Bytes[0, 0, 0, 0, 0, 0x0f, 0x42, 0x40]).should eq Time.utc(2000, 1, 1, 0, 0, 1)
    micros = ->(value : Int64) { Bytes.new(8).tap { |buffer| IO::ByteFormat::NetworkEndian.encode(value, buffer) } }
    timestamp = Types.codec_for(Types::OID::TIMESTAMP)
    timestamp.decode.call(micros.call(-1_000_001_i64)).should eq Time.utc(1999, 12, 31, 23, 59, 58, nanosecond: 999_999_000)
    timestamp.decode.call(micros.call(-1_500_000_i64)).should eq Time.utc(1999, 12, 31, 23, 59, 58, nanosecond: 500_000_000)
    Types.codec_for(Types::OID::DATE).decode.call(Bytes[0xff, 0xff, 0xff, 0xff]).should eq Time.utc(1999, 12, 31)
    Types.codec_for(Types::OID::TIME).decode.call(micros.call(86_399_999_999_i64)).should eq Time::Span.new(hours: 23, minutes: 59, seconds: 59, nanoseconds: 999_999_000)
    Types.codec_for(Types::OID::TIME).decode.call(Bytes[0, 0, 0, 0, 0, 0x0f, 0x42, 0x40]).should eq 1.second
  end

  it "rejects infinite and out-of-range dates and timestamps instead of returning a wrong Time" do
    infinity = Bytes[0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    expect_raises(CQL::Postgres::UnsupportedValue, /infinite/) { Types.codec_for(Types::OID::TIMESTAMPTZ).decode.call(infinity) }
    expect_raises(CQL::Postgres::UnsupportedValue, /infinite/) { Types.codec_for(Types::OID::DATE).decode.call(Bytes[0x7f, 0xff, 0xff, 0xff]) }
    expect_raises(CQL::Postgres::UnsupportedValue, /infinite/) { Types.codec_for(Types::OID::DATE).decode.call(Bytes[0x80, 0, 0, 0]) }
    far_future = Bytes.new(8).tap { |buffer| IO::ByteFormat::NetworkEndian.encode(9_000_000_000_000_000_000_i64, buffer) }
    expect_raises(CQL::Postgres::UnsupportedValue, /range/) { Types.codec_for(Types::OID::TIMESTAMPTZ).decode.call(far_future) }
    expect_raises(CQL::Postgres::UnsupportedValue, /range/) { Types.codec_for(Types::OID::DATE).decode.call(Bytes[0x7f, 0xff, 0xff, 0xfe]) }
    expect_raises(CQL::Postgres::UnsupportedValue, /range/) { Types.codec_for(Types::OID::DATE).decode.call(Bytes[0x80, 0, 0, 1]) }
  end

  it "decodes uuid, numeric, json and falls back to text" do
    uuid = UUID.random
    Types.codec_for(Types::OID::UUID).decode.call(uuid.bytes.to_slice).should eq uuid
    Types.codec_for(Types::OID::NUMERIC).decode.call("12.50".to_slice).to_s.should eq "12.50"
    Types.codec_for(Types::OID::JSONB).decode.call(%({"a":1}).to_slice).as(JSON::Any)["a"].as_i.should eq 1
    Types.codec_for(999_999_u32).decode.call("whatever".to_slice).should eq "whatever"
    Types.codec_for(999_999_u32).binary.should be_false
  end

  it "reports malformed JSON from the server as a protocol error" do
    expect_raises(CQL::Postgres::ProtocolError, /malformed JSON/) { Types.codec_for(Types::OID::JSONB).decode.call("{oops".to_slice) }
  end

  it "lets applications register a codec for their own type" do
    Types.register(777_001_u32, binary: false) { |bytes| Shout.new(String.new(bytes)) }
    Types.codec_for(777_001_u32).decode.call("abc".to_slice).as(Shout).text.should eq "ABC"
  end

  it "does not let a decoded bytea pin the message buffer" do
    payload = Bytes[1, 2, 3, 4]
    Types.codec_for(Types::OID::BYTEA).decode.call(payload[1, 2]).as(Bytes).to_unsafe.should_not eq(payload.to_unsafe + 1)
  end
end

describe CQL::Postgres::Types::ParamEncoder do
  it "encodes scalars as text and bytea as binary" do
    encoded(nil).should eq({nil, 0_i16})
    encoded(42).should eq({"42", 0_i16})
    encoded(true).should eq({"t", 0_i16})
    encoded(1.5).should eq({"1.5", 0_i16})
    encoded("o'brien").should eq({"o'brien", 0_i16})
    Types::ParamEncoder.encode(Bytes[1, 2]).format.should eq 1_i16
  end

  it "encodes uuid, decimals and json as text" do
    uuid = UUID.random
    encoded(uuid).should eq({uuid.to_s, 0_i16})
    encoded(Types::DecimalText.new("12.50")).should eq({"12.50", 0_i16})
    json = "{\"a\":[1,2]}"
    encoded(JSON.parse(json)).should eq({json, 0_i16})
  end

  it "encodes times as UTC microsecond timestamps" do
    encoded(Time.utc(2024, 3, 5, 6, 7, 8, nanosecond: 123_456_000)).should eq({"2024-03-05 06:07:08.123456+00", 0_i16})
    encoded(Time.local(2024, 3, 5, 6, 0, 0, location: Time::Location.fixed(3600))).should eq({"2024-03-05 05:00:00.000000+00", 0_i16})
  end

  it "encodes arrays as PostgreSQL array literals with escaping" do
    encoded([1, 2, 3]).should eq({"{1,2,3}", 0_i16})
    encoded(["a", "b\"c", "d\\e"] of String?).should eq({"{a,\"b\\\"c\",\"d\\\\e\"}", 0_i16})
    encoded([1, nil] of Int32?).should eq({"{1,NULL}", 0_i16})
  end

  it "quotes array elements only when PostgreSQL needs it" do
    encoded([""] of String?).should eq({"{\"\"}", 0_i16})
    encoded(["NULL", "null", "Null"] of String?).should eq({"{\"NULL\",\"null\",\"Null\"}", 0_i16})
    encoded(["a b", "{x}", "y,z", "plain"] of String?).should eq({"{\"a b\",\"{x}\",\"y,z\",plain}", 0_i16})
    encoded([[1, 2], [3, 4]]).should eq({"{{1,2},{3,4}}", 0_i16})
    encoded([true, false]).should eq({"{t,f}", 0_i16})
    expect_raises(ArgumentError, /bytea/) { Types::ParamEncoder.encode([Bytes[1]]) }
    expect_raises(ArgumentError, /Regex/) { Types::ParamEncoder.encode([/x/]) }
    expect_raises(ArgumentError, /Hash/) { Types::ParamEncoder.encode([{"a" => 1}]) }
  end

  it "rejects NUL bytes and unsupported types" do
    expect_raises(ArgumentError, /NUL/) { Types::ParamEncoder.encode("a\0b") }
    expect_raises(ArgumentError, /Regex/) { Types::ParamEncoder.encode(/x/) }
  end
end

describe CQL::Postgres::ServerError do
  it "maps SQLSTATEs to typed errors and falls back to the SQLSTATE class" do
    error_for("23505").should be_a CQL::Postgres::UniqueViolation
    error_for("23503").should be_a CQL::Postgres::ForeignKeyViolation
    error_for("23999").should be_a CQL::Postgres::IntegrityViolation
    error_for("40P01").should be_a CQL::Postgres::DeadlockDetected
    error_for("42P01").should be_a CQL::Postgres::UndefinedTable
    error_for("28P01").should be_a CQL::Postgres::InvalidAuthorization
    error_for("99999").class.should eq CQL::Postgres::ServerError
  end

  it "is a CQL::Error whose message leaves out the detail that can echo row values" do
    error = error_for("23505", {'D' => "Key (email)=(ada@example.com) already exists.", 'n' => "users_email_key"})
    error.should be_a CQL::Error
    error.message.should eq "ERROR: boom (SQLSTATE 23505)"
    error.message.to_s.should_not contain "ada@example.com"
    error.detail.to_s.should contain "ada@example.com"
    error.constraint.should eq "users_email_key"
  end

  it "keeps server wording that can quote bound input out of the message" do
    cast = error_for("22P02", {'M' => %(invalid input syntax for type integer: "hunter2")})
    cast.message.should eq "ERROR: invalid text representation (SQLSTATE 22P02)"
    cast.server_message.should contain "hunter2"

    regclass = error_for("42P01", {'M' => %(relation "hunter2" does not exist)})
    regclass.message.to_s.should_not contain "hunter2"
    regclass.message.should eq "ERROR: undefined table (SQLSTATE 42P01)"

    error_for("P0001", {'M' => "raised hunter2"}).message.should eq "ERROR: PL/pgSQL error (SQLSTATE P0001)"
    error_for("99999", {'M' => "hunter2"}).message.should eq "ERROR: server error (SQLSTATE 99999)"
  end

  it "keeps the server's wording for classes known to be value-free" do
    error_for("23505", {'M' => %(duplicate key value violates unique constraint "users_email_key")}).message
      .should eq %(ERROR: duplicate key value violates unique constraint "users_email_key" (SQLSTATE 23505))
    error_for("28P01", {'M' => %(password authentication failed for user "ada")}).message.to_s.should contain %("ada")
    error_for("40001", {'M' => "restart transaction: key /Table/105/1/42/0"}).message.should eq "ERROR: serialization failure (SQLSTATE 40001)"
    error_for("XX000", {'M' => "internal error: 42"}).message.should eq "ERROR: server error (SQLSTATE XX000)"
  end

  it "recognises a stale cached plan by routine, not by the server's language" do
    stale = CQL::Postgres::ServerError.from({'C' => "0A000", 'M' => "el plan en caché no debe cambiar", 'R' => "RevalidateCachedQuery"})
    stale.stale_plan?.should be_true
    error_for("0A000").stale_plan?.should be_false
    error_for("0A000", {'R' => "other"}).stale_plan?.should be_false
  end
end
