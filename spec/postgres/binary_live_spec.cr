require "../spec_helper"
require "../../src/postgres"

# Binary parameters and binary COPY against a real server (DATABASE_URL, pending without one). Every
# value is sent once as text and once as binary, and the server must read both the same way.

private alias PG = CQL::Postgres
private alias OID = CQL::Postgres::Types::OID

private LIVE_URL = postgres_database_url

private module Server
  @@version : String? = nil

  def self.version : String?
    @@version ||= begin
      session = PG::Session.connect(PG::Config.parse(LIVE_URL))
      session.query("SELECT version()").rows.first.first.to_s.tap { session.close }
    rescue
      ""
    end
    @@version.presence
  end

  def self.cockroach? : Bool
    version.try(&.includes?("CockroachDB")) || false
  end
end

private def require_live! : Nil
  pending! "needs a PostgreSQL server reachable through DATABASE_URL" unless Server.version
end

private def session_with(binary : Bool) : PG::Session
  separator = LIVE_URL.includes?('?') ? "&" : "?"
  PG::Session.connect(PG::Config.parse(binary ? "#{LIVE_URL}#{separator}binary_params=true" : LIVE_URL))
end

# What the server makes of *value* as a parameter of *type*, in the shape of the first column as text and the
# second as the driver decodes it.
private def read_back(session : PG::Session, type : String, value) : Array(String)
  row = session.query("SELECT ($1::#{type})::text, $1::#{type}", [session.encode(value)]).rows.first
  row.map(&.to_s)
end

# Sends *value* both ways, asserts the server read them alike and, unless told otherwise, that binary was used.
private def same_both_ways(type : String, value, binary : Bool = true) : Nil
  text_session = session_with(false)
  binary_session = session_with(true)
  begin
    as_text = read_back(text_session, type, value)
    as_binary = read_back(binary_session, type, value)
    as_binary.should eq as_text
    text_session.binary_params_sent.should eq 0
    binary_session.binary_params_sent.should eq(binary ? 1 : 0) unless Server.cockroach?
  ensure
    text_session.close
    binary_session.close
  end
end

describe "binary parameters against a live server" do
  it "reads integers, booleans and floats like their text" do
    require_live!
    printf "  server: %s\n", Server.version
    same_both_ways("int2", Int16::MIN)
    same_both_ways("int2", Int16::MAX)
    same_both_ways("int4", Int32::MIN)
    same_both_ways("int4", 0)
    same_both_ways("int8", Int64::MIN)
    same_both_ways("int8", Int64::MAX)
    same_both_ways("int8", UInt32::MAX)
    same_both_ways("bool", true)
    same_both_ways("bool", false)
    same_both_ways("float4", 1.5_f32)
    same_both_ways("float4", 0.1_f32)
    same_both_ways("float8", 0.1)
    same_both_ways("float8", -0.0)
    same_both_ways("float8", 5e-324)
    same_both_ways("float8", Float64::MAX)
    same_both_ways("float8", Float64::INFINITY)
    same_both_ways("float8", -Float64::INFINITY)
    same_both_ways("float8", Float64::NAN)
    same_both_ways("float8", 0.1_f32)
  end

  it "reads uuid, timestamps and dates like their text" do
    require_live!
    same_both_ways("uuid", UUID.new("123e4567-e89b-12d3-a456-426614174000"))
    same_both_ways("uuid", UUID.empty)
    [Time.utc(2000, 1, 1), Time.utc(1999, 12, 31, 23, 59, 59, nanosecond: 999_999_999), Time.utc(1969, 7, 20, 20, 17, 40),
     Time.utc(2024, 2, 29, 12, 30, 15, nanosecond: 123_456_789), Time.utc(9999, 12, 31, 23, 59, 59, nanosecond: 999_999_000),
     Time.utc(1, 1, 1), Time.local(2020, 6, 1, 12, 0, 0, location: Time::Location.fixed(-7 * 3600))].each do |time|
      same_both_ways("timestamptz", time)
      same_both_ways("timestamp", time)
      same_both_ways("date", time)
    end
  end

  it "reads numeric, jsonb and bytea like their text" do
    require_live!
    ["0", "1", "-1", "12345.678", "0.0012", "100000000", "0.00000001", "-9999.9999", "123456789012345678901234567890.123456789", "1.5000", "0.00", "-0.00", "10000", "99999999999999999999.99"].each do |text|
      same_both_ways("numeric", PG::Types::DecimalText.new(text))
    end
    same_both_ways("numeric", Int64::MIN)
    same_both_ways("numeric", UInt64::MAX)
    same_both_ways("numeric", PG::Types::DecimalText.new("NaN"), binary: false)
    same_both_ways("numeric", PG::Types::DecimalText.new("1e5"), binary: false)
    same_both_ways("jsonb", JSON.parse(%({"a":[1,2.5,{"b":null}],"é":"x\\n","t":true})))
    same_both_ways("jsonb", JSON.parse(%("just a string")))
    same_both_ways("json", JSON.parse(%({"a":1})))
    same_both_ways("bytea", Bytes[0, 1, 255, 10, 92], binary: false)
  end

  it "reads arrays like their text, with NULLs, nesting and quoting" do
    require_live!
    same_both_ways("int4[]", [1, nil, 3])
    same_both_ways("int4[]", [] of Int32)
    same_both_ways("int2[]", [1_i16, -1_i16])
    same_both_ways("int8[]", [Int64::MAX, Int64::MIN])
    unless Server.cockroach? # no multi-dimensional arrays there, in text either
      same_both_ways("int4[]", [[1, 2], [3, 4]])
      same_both_ways("int4[]", [[[1], [2]], [[3], [4]]])
    end
    same_both_ways("text[]", ["a,b", "x\"y", "NULL", "", "é", "{}", "\\", " pad "])
    same_both_ways("varchar[]", ["a", nil])
    same_both_ways("bool[]", [true, nil, false])
    same_both_ways("float8[]", [1.5, -0.25, Float64::INFINITY])
    same_both_ways("float4[]", [1.5_f32, 0.1_f32])
    same_both_ways("uuid[]", [UUID.new("123e4567-e89b-12d3-a456-426614174000"), UUID.empty])
    same_both_ways("timestamptz[]", [Time.utc(2020, 1, 1), Time.utc(1999, 1, 1, 0, 0, 0, nanosecond: 5000)])
    same_both_ways("date[]", [Time.utc(2020, 1, 1), Time.utc(1969, 1, 1)])
    same_both_ways("numeric[]", [PG::Types::DecimalText.new("1.50"), PG::Types::DecimalText.new("-0.0012")])
    same_both_ways("jsonb[]", [JSON.parse(%({"a":1})), JSON.parse("[1]")])
  end

  it "falls back to text when the value does not fit the server's type, and the server says so itself" do
    require_live!
    pending! "CockroachDB describes an int2 cast as int8" if Server.cockroach?
    [false, true].each do |binary|
      session = session_with(binary)
      error = expect_raises(PG::ServerError) { session.query("SELECT $1::int2", [session.encode(70_000)]) }
      error.sqlstate.should eq "22003"
      session.query("SELECT 1").rows.should eq [[1]]
      session.binary_params_sent.should eq 0
      session.close
    end
  end

  it "keeps the types CockroachDB reads differently (float4, numeric) as text there, and sends everything else in binary" do
    require_live!
    pending! "PostgreSQL has no such exclusions" unless Server.cockroach?
    session = session_with(true)
    session.query("SELECT $1::float4, $2::numeric", [session.encode(0.1_f32), session.encode(PG::Types::DecimalText.new("100000000"))])
    session.binary_params_sent.should eq 0
    session.query("SELECT $1::int8", [session.encode(1_i64)])
    session.binary_params_sent.should eq 1
    session.close
  end

  it "keeps values out of the SQL: a hostile string is a parameter, in either format" do
    require_live!
    session = session_with(true)
    hostile = "x'; DROP TABLE nothing; --"
    session.query("SELECT $1::text", [session.encode(hostile)]).rows.should eq [[hostile]]
    session.query("SELECT $1::text[]", [session.encode([hostile])]).rows.first.first.to_s.should contain "DROP TABLE"
    session.close
  end

  it "works through cached and unnamed statements, pipelines and streams" do
    require_live!
    session = session_with(true)
    3.times { |count| session.query("SELECT $1::int8 + 1", [session.encode(count.to_i64)]).rows.should eq [[count + 1]] }
    unnamed = PG::Session.connect(PG::Config.parse("#{LIVE_URL}#{LIVE_URL.includes?('?') ? '&' : '?'}binary_params=true&statement_cache_size=0"))
    unnamed.query("SELECT $1::int8 + 1", [unnamed.encode(41_i64)]).rows.should eq [[42]]
    unnamed.binary_params_sent.should eq 1
    unnamed.close
    results = session.pipeline([{"SELECT $1::int4", [session.encode(1)]}, {"SELECT $1::uuid", [session.encode(UUID.empty)]}])
    results.map { |result| result.as(PG::Result).rows.first.first }.should eq [1, UUID.empty]
    seen = [] of Int64
    session.stream("SELECT g FROM generate_series(1, $1::int8) g", [session.encode(250_i64)], 100) { |rows| rows.each { |row| seen << row.first.as(Int64) } }
    seen.size.should eq 250
    session.binary_params_sent.should be > 5 unless Server.cockroach?
    session.close
  end
end

describe "binary COPY against a live server" do
  table = "cql_binary_copy_#{Process.pid}"

  it "round-trips rows through copy_in_binary and copy_out_binary" do
    require_live!
    session = session_with(false)
    session.simple_query("CREATE TABLE #{table} (id int8, name text, ok bool, price numeric, token uuid, seen timestamptz, born date, doc jsonb, raw bytea, small int2, ratio float8)")
    begin
      types = [OID::INT8, OID::TEXT, OID::BOOL, OID::NUMERIC, OID::UUID, OID::TIMESTAMPTZ, OID::DATE, OID::JSONB, OID::BYTEA, OID::INT2, OID::FLOAT8]
      id = UUID.new("123e4567-e89b-12d3-a456-426614174000")
      stamp = Time.utc(2020, 5, 17, 12, 30, 15, nanosecond: 250_000_000)
      sent = session.copy_in_binary("COPY #{table} FROM STDIN (FORMAT binary)", types) do |rows|
        rows.row(1_i64, "héllo", true, PG::Types::DecimalText.new("-12.50"), id, stamp, Time.utc(1969, 7, 20), JSON.parse(%({"a":[1]})), Bytes[0, 255], 7_i16, 0.1)
        rows.row(2_i64, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
        10_000.times { |index| rows.row(100_i64 + index, "row #{index}", index.odd?, PG::Types::DecimalText.new("#{index}.25"), id, stamp, Time.utc(2000, 1, 1), JSON.parse("{}"), Bytes.empty, 1_i16, index.to_f) }
      end
      sent.should eq 10_002
      session.query("SELECT count(*) FROM #{table}").rows.should eq [[10_002_i64]]
      if Server.cockroach?
        error = expect_raises(PG::ServerError) { session.copy_out_binary("COPY #{table} TO STDOUT (FORMAT binary)", types) { |_| } }
        error.sqlstate.should eq "0A000" # the node says it does not implement binary COPY TO
        session.query("SELECT 1").rows.should eq [[1]]
        next
      end
      rows = [] of Array(PG::Types::Value)
      received = session.copy_out_binary("COPY (SELECT * FROM #{table} ORDER BY id) TO STDOUT (FORMAT binary)", types) { |row| rows << row }
      received.should eq 10_002
      rows.size.should eq 10_002
      first = rows[0]
      first[0].should eq 1_i64
      first[1].should eq "héllo"
      first[2].should be_true
      first[3].to_s.should eq "-12.50"
      first[4].should eq id
      first[5].should eq stamp
      first[6].should eq Time.utc(1969, 7, 20)
      first[7].should eq JSON.parse(%({"a":[1]}))
      first[8].should eq Bytes[0, 255]
      first[9].should eq 7_i16
      first[10].should eq 0.1
      rows[1].all?(Nil).should be_false
      rows[1][0].should eq 2_i64
      rows[1][1..].all?(Nil).should be_true
      rows.last[1].should eq "row 9999"
    ensure
      session.simple_query("DROP TABLE IF EXISTS #{table}")
      session.close
    end
  end

  it "rejects malformed binary rows with the server's error and leaves the session usable" do
    require_live!
    session = session_with(false)
    session.simple_query("CREATE TABLE #{table}_bad (id int4)")
    begin
      expect_raises(PG::ServerError) do
        session.copy_in("COPY #{table}_bad FROM STDIN (FORMAT binary)") { |copy| copy << "this is not a binary copy stream" }
      end
      session.query("SELECT 1").rows.should eq [[1]]
    ensure
      session.simple_query("DROP TABLE IF EXISTS #{table}_bad")
      session.close
    end
  end

  it "stops reading a binary COPY early, keeping the session in sync" do
    require_live!
    pending! "CockroachDB does not implement binary COPY TO" if Server.cockroach?
    session = session_with(false)
    seen = 0
    expect_raises(Exception, "enough") do
      session.copy_out_binary("COPY (SELECT g, g::text FROM generate_series(1, 200000) g) TO STDOUT (FORMAT binary)", [OID::INT4, OID::TEXT]) do |_|
        seen += 1
        raise "enough" if seen == 3
      end
    end
    seen.should eq 3
    session.query("SELECT 7").rows.should eq [[7]]
    session.closed?.should be_false
    session.close
  end

  it "times out and cancels a binary COPY out like a text one" do
    require_live!
    pending! "CockroachDB does not implement binary COPY TO" if Server.cockroach?
    session = session_with(false)
    started = Time.instant
    expect_raises(PG::QueryTimeout) do
      session.copy_out_binary("COPY (SELECT pg_sleep(10)) TO STDOUT (FORMAT binary)", [OID::TEXT], timeout: 300.milliseconds) { |_| }
    end
    (Time.instant - started).should be < 3.seconds
    session.closed?.should be_false
    session.query("SELECT 8").rows.should eq [[8]]
    session.close
  end

  it "cancels a running binary COPY out from another fiber" do
    require_live!
    pending! "CockroachDB does not implement binary COPY TO" if Server.cockroach?
    session = session_with(false)
    spawn do
      sleep 200.milliseconds
      session.cancel
    end
    expect_raises(PG::QueryCanceled) do
      session.copy_out_binary("COPY (SELECT g FROM generate_series(1, 500000000) g) TO STDOUT (FORMAT binary)", [OID::INT4]) { |_| }
    end
    session.query("SELECT 9").rows.should eq [[9]]
    session.close
  end

  it "aborts a binary COPY in when the block raises and keeps the session" do
    require_live!
    session = session_with(false)
    session.simple_query("CREATE TABLE #{table}_abort (id int4)")
    begin
      expect_raises(Exception, "stop") do
        session.copy_in_binary("COPY #{table}_abort FROM STDIN (FORMAT binary)", [OID::INT4]) { |rows| rows.row(1); raise "stop" }
      end
      session.query("SELECT count(*) FROM #{table}_abort").rows.should eq [[0_i64]]
    ensure
      session.simple_query("DROP TABLE IF EXISTS #{table}_abort")
      session.close
    end
  end
end
