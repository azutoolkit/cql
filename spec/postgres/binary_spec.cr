require "../spec_helper"
require "../support/fake_pg_server"
require "../../src/postgres"

private alias PG = CQL::Postgres
private alias OID = CQL::Postgres::Types::OID
private alias Binary = CQL::Postgres::Types::Binary

private def hex(bytes : Bytes?) : String
  bytes ? bytes.hexstring : "nil"
end

private def connect(server : FakePG, query = "sslmode=disable&binary_params=true")
  PG::Session.connect(PG::Config.parse(server.url(query: query)))
end

private def raw_bind(payload : Bytes)
  reader = PG::Wire::Reader.new(payload)
  reader.cstring
  reader.cstring
  formats = Array.new(reader.uint16.to_i) { reader.int16 }
  values = Array.new(reader.uint16.to_i) do
    length = reader.int32
    length < 0 ? nil : reader.bytes(length).hexstring
  end
  {formats: formats, values: values}
end

describe CQL::Postgres::Types::Binary do
  describe "scalars" do
    it "encodes integers at the width of the server's type, and refuses values that do not fit" do
      hex(Binary.encode(258, OID::INT4)).should eq "00000102"
      hex(Binary.encode(-2_i64, OID::INT8)).should eq "fffffffffffffffe"
      hex(Binary.encode(7_i8, OID::INT2)).should eq "0007"
      Binary.encode(70_000, OID::INT2).should be_nil
      Binary.encode(Int64::MAX, OID::INT4).should be_nil
      Binary.encode(UInt64::MAX, OID::INT8).should be_nil
      hex(Binary.encode(UInt64.new(Int64::MAX), OID::INT8)).should eq "7fffffffffffffff"
    end

    it "encodes floats without changing their value, and never narrows a Float64" do
      hex(Binary.encode(1.5, OID::FLOAT8)).should eq "3ff8000000000000"
      hex(Binary.encode(1.5_f32, OID::FLOAT4)).should eq "3fc00000"
      hex(Binary.encode(0.1_f32, OID::FLOAT8)).should eq hex(Binary.encode(0.1, OID::FLOAT8)) # the printed form, as text would be
      Binary.encode(1.5, OID::FLOAT4).should be_nil
      Binary.encode(1.5, OID::INT4).should be_nil
    end

    it "encodes booleans, uuids and bytea" do
      hex(Binary.encode(true, OID::BOOL)).should eq "01"
      hex(Binary.encode(false, OID::BOOL)).should eq "00"
      id = UUID.new("123e4567-e89b-12d3-a456-426614174000")
      hex(Binary.encode(id, OID::UUID)).should eq "123e4567e89b12d3a456426614174000"
      hex(Binary.encode(Bytes[1, 2], OID::BYTEA)).should eq "0102"
      Binary.encode(true, OID::INT4).should be_nil
    end

    it "encodes times as microseconds since 2000-01-01 UTC, truncating like the text form, and dates as days" do
      hex(Binary.encode(Time.utc(2000, 1, 1, 0, 0, 1), OID::TIMESTAMPTZ)).should eq "00000000000f4240"
      hex(Binary.encode(Time.utc(2000, 1, 1, 0, 0, 0, nanosecond: 1999), OID::TIMESTAMP)).should eq "0000000000000001"
      hex(Binary.encode(Time.utc(1999, 12, 31, 23, 59, 59, nanosecond: 500_000_000), OID::TIMESTAMPTZ)).should eq "fffffffffff85ee0"
      hex(Binary.encode(Time.utc(2000, 1, 2, 23, 0, 0), OID::DATE)).should eq "00000001"
      hex(Binary.encode(Time.utc(1999, 12, 31, 12, 0, 0), OID::DATE)).should eq "ffffffff"
      hex(Binary.encode(Time.local(2000, 1, 1, 1, 0, 0, location: Time::Location.fixed(3600)), OID::TIMESTAMPTZ)).should eq "0000000000000000"
    end

    it "encodes jsonb with its version byte and json as its text" do
      hex(Binary.encode(JSON.parse(%({"a":1})), OID::JSONB)).should eq "017b2261223a317d"
      hex(Binary.encode(JSON.parse("1"), OID::JSON)).should eq "31"
    end

    it "keeps text types as they are and refuses NUL bytes" do
      hex(Binary.encode("hé", OID::TEXT)).should eq "68c3a9"
      Binary.encode("a\0b", OID::TEXT).should be_nil
      Binary.encode("1", OID::INT4).should be_nil
    end
  end

  describe "numeric" do
    it "writes base-10000 groups, weight, sign and scale" do
      hex(Binary.encode(PG::Types::DecimalText.new("12345.678"), OID::NUMERIC)).should eq "00030001000000030001" + "0929" + "1a7c"
      hex(Binary.numeric("0.0012")).should eq "0001ffff000000040" + "00c"
      hex(Binary.numeric("0.50")).should eq "0001ffff000000021388"
      hex(Binary.numeric("-100")).should eq "00010000400000000064"
      hex(Binary.numeric("10000")).should eq "0001000100000000" + "0001"
      hex(Binary.numeric("0")).should eq "0000000000000000"
      hex(Binary.numeric("-0.00")).should eq "0000000000000002"
      hex(Binary.encode(5, OID::NUMERIC)).should eq "0001000000000000" + "0005"
    end

    it "leaves NaN, infinities, exponents and junk to text" do
      ["NaN", "Infinity", "1e5", "", ".", "1.2.3", "abc", "--1"].each { |text| Binary.numeric(text).should be_nil }
    end

    it "reads back what it wrote" do
      ["0", "1", "-1", "12345.678", "0.0012", "100000000", "0.00000001", "-9999.9999", "123456789012345678901234567890.123456789", "1.5000", "0.00"].each do |text|
        Binary.numeric_text(Binary.numeric(text).not_nil!).should eq text
      end
      Binary.numeric_text(Binary.numeric("+7.0").not_nil!).should eq "7.0"
      Binary.numeric_text(Binary.numeric("007").not_nil!).should eq "7"
    end

    it "reads back 5000 random decimals exactly, whatever their length and zeros" do
      random = Random.new(20261023)
      5000.times do
        whole = Array.new(random.rand(0..30)) { random.rand(10) == 0 ? '0' : ('0' + random.rand(10)) }.join
        fraction = Array.new(random.rand(0..30)) { random.rand(3) == 0 ? '0' : ('0' + random.rand(10)) }.join
        next if whole.empty? && fraction.empty?
        sign = random.rand(4) == 0 ? "-" : ""
        text = "#{sign}#{whole}#{fraction.empty? ? "" : "." + fraction}"
        kept = whole.lstrip('0')
        nonzero = !(kept + fraction).delete('0').empty?
        expected = "#{nonzero ? sign : ""}#{kept.empty? ? "0" : kept}#{fraction.empty? ? "" : "." + fraction}"
        Binary.numeric_text(Binary.numeric(text).not_nil!).should eq expected
      end
    end

    it "reads NaN and infinities the server sends" do
      Binary.numeric_text(Bytes[0, 0, 0, 0, 0xc0, 0, 0, 0]).should eq "NaN"
      Binary.numeric_text(Bytes[0, 0, 0, 0, 0xd0, 0, 0, 0]).should eq "Infinity"
      Binary.numeric_text(Bytes[0, 0, 0, 0, 0xf0, 0, 0, 0]).should eq "-Infinity"
    end
  end

  describe "arrays" do
    it "encodes a one-dimensional array with a NULL" do
      hex(Binary.encode([1, nil, 3], OID::INT4_ARRAY)).should eq "00000001" + "00000001" + "00000017" + "00000003" + "00000001" + "0000000400000001" + "ffffffff" + "0000000400000003"
    end

    it "encodes nested arrays as dimensions and refuses ragged ones" do
      hex(Binary.encode([[1, 2], [3, 4]], OID::INT4_ARRAY)).should start_with "00000002" + "00000000" + "00000017" + "00000002" + "00000001" + "00000002" + "00000001"
      Binary.encode([[1], [2, 3]], OID::INT4_ARRAY).should be_nil
      Binary.encode([[1], 2], OID::INT4_ARRAY).should be_nil
      nested_empty = [[] of Int32]
      Binary.encode(nested_empty, OID::INT4_ARRAY).should be_nil
    end

    it "encodes an empty array as a header with no dimensions" do
      empty = [] of Int32
      hex(Binary.encode(empty, OID::INT4_ARRAY)).should eq "000000000000000000000017"
    end

    it "encodes text, uuid and timestamp arrays and refuses elements of the wrong kind" do
      hex(Binary.encode(["a", "bc"], OID::TEXT_ARRAY)).should end_with "000000016100000002" + "6263"
      Binary.encode([1, 2], OID::TEXT_ARRAY).should be_nil
      Binary.encode([70_000], OID::INT2_ARRAY).should be_nil
      Binary.encode(["a\0"], OID::TEXT_ARRAY).should be_nil
      Binary.encode([1], OID::INT4).should be_nil
      Binary.encode([Time.utc(2000, 1, 1)], OID::TIMESTAMPTZ_ARRAY).should_not be_nil
    end
  end

  it "leaves a numeric with more digits than the format can count to the server" do
    Binary.numeric("9" * 140_000).should be_nil
  end

  it "says which values may wait for the server's types" do
    [true, 1, 1.5, UUID.random, PG::Types::DecimalText.new("1"), Time.utc, JSON.parse("1"), [1]].each { |value| Binary.supported?(value).should be_true }
    ["text", Bytes[1], nil, :symbol].each { |value| Binary.supported?(value).should be_false }
  end
end

describe "binary parameters on a session" do
  it "sends each parameter in the format of the type the server described, and text where binary has no meaning" do
    bound = nil
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.serve_prepare([20_u32, 25_u32, 1184_u32, 1700_u32, 21_u32, 1007_u32, 16_u32], [] of {String, UInt32})
      bound = raw_bind(client.expect('B'))
      client.expect('E'); client.expect('S')
      client.send('2'); client.command_complete("INSERT 0 1"); client.ready
    end
    params = [9_i64, "text", Time.utc(2000, 1, 1, 0, 0, 1), PG::Types::DecimalText.new("1.5"), 70_000, [1, 2], true].map { |value| PG::Types::ParamEncoder.encode(value, true) }
    connect(server).query("INSERT INTO t VALUES ($1,$2,$3,$4,$5,$6,$7)", params)
    bound.not_nil![:formats].should eq [1_i16, 0_i16, 1_i16, 1_i16, 0_i16, 1_i16, 1_i16]
    values = bound.not_nil![:values]
    values[0].should eq "0000000000000009"
    values[1].should eq "text".to_slice.hexstring
    values[2].should eq "00000000000f4240"
    values[4].should eq "70000".to_slice.hexstring # does not fit int2: the server gets the text and says so itself
    values[6].should eq "01"
  end

  it "sends text for everything when binary_params is off, as before" do
    bound = nil
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.serve_prepare([23_u32], [] of {String, UInt32})
      bound = raw_bind(client.expect('B'))
      client.expect('E'); client.expect('S')
      client.send('2'); client.command_complete("INSERT 0 1"); client.ready
    end
    session = connect(server, "sslmode=disable")
    session.query("SELECT $1", [session.encode(5)])
    bound.not_nil![:formats].should eq [0_i16]
    bound.not_nil![:values].should eq ["5".to_slice.hexstring]
  end

  it "sends a parameter that was encoded for binary in binary, whatever the session setting says (the choice is made when the parameter is created)" do
    bound = nil
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.serve_prepare([23_u32], [] of {String, UInt32})
      bound = raw_bind(client.expect('B'))
      client.expect('E'); client.expect('S')
      client.send('2'); client.command_complete("SELECT 1"); client.ready
    end
    connect(server, "sslmode=disable").query("SELECT $1", [PG::Types::ParamEncoder.encode(5, true)])
    bound.not_nil![:formats].should eq [1_i16]
  end

  it "splits a pipeline of large binary parameters into batches, as it does for text ones" do
    waited_for_reply = false
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('P'); client.expect('D'); client.expect('S')
      client.send('1'); client.parameter_description([1016_u32]); client.send('n'); client.ready
      client.expect('B'); client.expect('E'); client.expect('S')
      client.io.read_timeout = 200.milliseconds
      begin
        client.io.read_byte
      rescue IO::TimeoutError
        waited_for_reply = true
      end
      client.io.read_timeout = nil
      client.send('2'); client.command_complete("SELECT 1"); client.ready
      client.expect('B'); client.expect('E'); client.expect('S')
      client.send('2'); client.command_complete("SELECT 1"); client.ready
    end
    session = connect(server)
    big = session.encode(Array.new(3000, &.to_i64))
    big.deferred.not_nil!.size_hint.should be > 16_000
    session.pipeline([{"SELECT $1::int8[]", [big]}, {"SELECT $1::int8[]", [big]}]).size.should eq 2
    waited_for_reply.should be_true
  end

  it "reports a parameter it cannot bind before sending the Bind, and keeps the session (cached statement)" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.serve_prepare([1007_u32], [] of {String, UInt32})
      client.serve_execute([] of Array(Bytes?), "SELECT 0") # the next request must start with a whole Bind
    end
    session = connect(server)
    error = expect_raises(ArgumentError, /Symbol/) { session.query("SELECT $1::int4[]", [session.encode([:secret])]) }
    error.message.to_s.should_not contain "secret"
    session.query("SELECT $1::int4[]", [session.encode([1])]).tag.should eq "SELECT 0"
  end

  it "ends the open unnamed-statement request when a deferred parameter cannot be bound, and the session carries on" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('P'); client.expect('D'); client.expect('H')
      client.send('1'); client.parameter_description([1007_u32]); client.send('n')
      client.expect('S')
      client.ready
      client.expect('P'); client.expect('D'); client.expect('H')
      client.send('1'); client.parameter_description([1007_u32]); client.send('n')
      client.expect('B'); client.expect('E'); client.expect('S')
      client.send('2'); client.command_complete("SELECT 0"); client.ready
    end
    session = connect(server, "sslmode=disable&binary_params=true&statement_cache_size=0")
    expect_raises(ArgumentError, /Symbol/) { session.query("SELECT $1::int4[]", [session.encode([:x])]) }
    session.closed?.should be_false
    session.query("SELECT $1::int4[]", [session.encode([1])]).tag.should eq "SELECT 0"
  end

  it "counts large strings, json and numerics when it sizes a pipeline batch" do
    sizes = [PG::Types::ParamEncoder.encode(["x" * 50_000], true), PG::Types::ParamEncoder.encode(JSON.parse(%("#{"y" * 50_000}")), true),
             PG::Types::ParamEncoder.encode([PG::Types::DecimalText.new("9" * 50_000)], true)].map(&.deferred.not_nil!.size_hint)
    sizes.each(&.should(be > 50000))
  end

  it "keeps float4 and numeric as text on a server that sends crdb_version, and the rest in binary" do
    bound = nil
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake({"server_version" => "13.0.0", "client_encoding" => "UTF8", "crdb_version" => "CockroachDB CCL v24.3.5"})
      client.serve_prepare([700_u32, 1700_u32, 20_u32, 1007_u32], [] of {String, UInt32})
      bound = raw_bind(client.expect('B'))
      client.expect('E'); client.expect('S')
      client.send('2'); client.command_complete("SELECT 1"); client.ready
    end
    session = connect(server)
    params = [0.1_f32, PG::Types::DecimalText.new("100000000"), 5_i64, [1, 2]].map { |value| session.encode(value) }
    session.query("SELECT $1, $2, $3, $4", params)
    bound.not_nil![:formats].should eq [0_i16, 0_i16, 1_i16, 1_i16]
    bound.not_nil![:values][0..1].should eq ["0.1".to_slice.hexstring, "100000000".to_slice.hexstring]
    session.binary_params_sent.should eq 2
  end

  it "sends text for the types in the text-only list when asked to resolve" do
    numeric = PG::Types::ParamEncoder.encode(PG::Types::DecimalText.new("1.5"), true).deferred.not_nil!
    numeric.resolve(OID::NUMERIC, Binary::COCKROACHDB_TEXT_ONLY).format.should eq PG::Types::Param::TEXT
    numeric.resolve(OID::NUMERIC, [] of UInt32).format.should eq PG::Types::Param::BINARY
    numeric.resolve(nil, [] of UInt32).format.should eq PG::Types::Param::TEXT
  end

  it "hints at least the text size for values that fall back to text, so a pipeline batch cannot outgrow its limit" do
    [Time.utc(2000, 1, 1, 0, 0, 0, nanosecond: 123_456_000), UUID.random, -1.2345678901234567e-300, Int128::MIN, true].each do |value|
      param = PG::Types::ParamEncoder.encode(value, true)
      text = PG::Types::ParamEncoder.encode(value).value.not_nil!.size
      param.deferred.not_nil!.size_hint.should be >= text
    end
  end

  it "does not print parameter values when inspected" do
    PG::Types::ParamEncoder.encode("secret-value").inspect.should_not contain "secret"
    PG::Types::ParamEncoder.encode(123456789, true).inspect.should_not contain "123456789"
  end

  it "validates the option" do
    PG::Config.parse("postgres://h/db?binary_params=true").binary_params?.should be_true
    PG::Config.parse("postgres://h/db?binary_params=off").binary_params?.should be_false
    PG::Config.parse("postgres://h/db").binary_params?.should be_false
    expect_raises(ArgumentError, /binary_params/) { PG::Config.parse("postgres://h/db?binary_params=maybe") }
  end

  it "refuses to send a parameter that still waits for its type" do
    expect_raises(ArgumentError, /waits/) { PG::Wire::Frontend.bind(IO::Memory.new, "", [PG::Types::ParamEncoder.encode(1, true)], [] of Int16) }
  end
end
