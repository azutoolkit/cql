require "../spec_helper"
require "../support/fake_pg_server"
require "../../src/postgres"

private alias PG = CQL::Postgres
private alias OID = CQL::Postgres::Types::OID

# The bytes inside the CopyData frames a writer queued.
private def copy_data_of(buffer : IO::Memory) : Bytes
  bytes = buffer.to_slice
  data = IO::Memory.new
  position = 0
  while position < bytes.size
    bytes[position].should eq 'd'.ord
    length = IO::ByteFormat::BigEndian.decode(Int32, bytes[position + 1, 4])
    data.write(bytes[position + 5, length - 4])
    position += 1 + length
  end
  data.to_slice.dup
end

private def written(types : Array(UInt32), & : PG::BinaryCopy::Writer ->) : Bytes
  buffer = IO::Memory.new
  writer = PG::BinaryCopy::Writer.new(PG::CopyIn.new(buffer, -> { }), types)
  yield writer
  writer.finish
  copy_data_of(buffer)
end

private def read_rows(types : Array(UInt32), chunks : Array(Bytes)) : Array(Array(PG::Types::Value))
  rows = [] of Array(PG::Types::Value)
  reader = PG::BinaryCopy::Reader.new(types) { |row| rows << row }
  chunks.each { |chunk| reader.feed(chunk) }
  reader.finish
  rows
end

describe CQL::Postgres::BinaryCopy do
  it "writes the signature, the rows and the trailer" do
    bytes = written([OID::INT4, OID::TEXT]) do |rows|
      rows.row(1, "a")
      rows.row(2, nil)
    end
    expected = "5047434f50590aff0d0a00" + "00000000" + "00000000" +
               "0002" + "00000004" + "00000001" + "00000001" + "61" +
               "0002" + "00000004" + "00000002" + "ffffffff" +
               "ffff"
    bytes.hexstring.should eq expected
  end

  it "writes a file with no rows as a header and a trailer" do
    written([OID::INT4]) { |_| }.hexstring.should eq "5047434f50590aff0d0a00" + "00000000" + "00000000" + "ffff"
  end

  it "refuses a row of the wrong width or a value the column's type cannot take, without quoting the value" do
    written([OID::INT4]) do |rows|
      expect_raises(ArgumentError, /1 columns, the row has 2/) { rows.row(1, 2) }
      error = expect_raises(ArgumentError, /column 1 \(type 23\) cannot take a String/) { rows.row("hunter2-secret") }
      error.message.to_s.should_not contain "hunter2"
      expect_raises(ArgumentError, /Int64/) { rows.row(5_i64 << 40) }
    end
  end

  it "reads rows however the chunks are cut" do
    types = [OID::INT8, OID::TEXT, OID::BOOL, OID::NUMERIC, OID::UUID, OID::TIMESTAMPTZ, OID::BYTEA]
    id = UUID.new("123e4567-e89b-12d3-a456-426614174000")
    stamp = Time.utc(2020, 5, 17, 12, 30, 15, nanosecond: 250_000_000)
    bytes = written(types) do |rows|
      rows.row(1_i64, "héllo", true, PG::Types::DecimalText.new("-12.50"), id, stamp, Bytes[1, 2, 3])
      rows.row(nil, nil, nil, nil, nil, nil, nil)
    end
    [bytes.size, 1, 3, 7].each do |size|
      chunks = bytes.each_slice(size).map(&.to_a).map { |slice| Bytes.new(slice.size) { |index| slice[index] } }.to_a
      rows = read_rows(types, chunks)
      rows.size.should eq 2
      rows[0][0].should eq 1_i64
      rows[0][1].should eq "héllo"
      rows[0][2].should eq true
      rows[0][3].to_s.should eq "-12.50"
      rows[0][4].should eq id
      rows[0][5].should eq stamp
      rows[0][6].should eq Bytes[1, 2, 3]
      rows[1].all?(Nil).should be_true
    end
  end

  it "reads a long row that arrives in many small chunks" do
    big = Bytes.new(300_000) { |index| (index % 251).to_u8 }
    bytes = written([OID::BYTEA, OID::INT4]) { |rows| rows.row(big, 1); rows.row(big, 2) }
    chunks = [] of Bytes
    position = 0
    while position < bytes.size
      size = Math.min(1000, bytes.size - position)
      chunks << bytes[position, size]
      position += size
    end
    rows = read_rows([OID::BYTEA, OID::INT4], chunks)
    rows.map(&.last).should eq [1, 2]
    rows.first.first.should eq big
  end

  it "drops consumed bytes from its buffer on long streams and keeps a row split across the cut" do
    big = Bytes.new(100_000) { |index| (index % 241).to_u8 }
    bytes = written([OID::BYTEA, OID::INT4]) { |rows| 25.times { |index| rows.row(big, index) } }
    bytes.size.should be > 2 * (1 << 20)
    chunks = [] of Bytes
    position = 0
    sizes = [70_001, 1, 33_333, 250_000]
    while position < bytes.size
      size = Math.min(sizes[chunks.size % sizes.size], bytes.size - position)
      chunks << bytes[position, size]
      position += size
    end
    rows = read_rows([OID::BYTEA, OID::INT4], chunks)
    rows.map(&.last).should eq (0...25).to_a
    rows.all? { |row| row.first == big }.should be_true
  end

  it "accepts a JSON::Any for a json column" do
    bytes = written([OID::JSON]) { |rows| rows.row(JSON.parse(%({"a":1}))) }
    read_rows([OID::JSON], [bytes]).first.first.should eq JSON.parse(%({"a":1}))
  end

  it "returns bytes for a type it has no decoder for" do
    bytes = written([OID::INT4_ARRAY], &.row([1, 2]))
    read_rows([OID::INT4_ARRAY], [bytes]).first.first.should be_a Bytes
  end

  it "rejects damaged streams without echoing their content" do
    good = written([OID::INT4], &.row(1))
    expect_raises(PG::ProtocolError, /signature/) { read_rows([OID::INT4], ["not a binary copy at all".to_slice]) }
    expect_raises(PG::ProtocolError, /trailer/) { read_rows([OID::INT4], [good[0, good.size - 2]]) }
    expect_raises(PG::ProtocolError, /trailer/) { read_rows([OID::INT4], [good[0, good.size - 5]]) }
    expect_raises(PG::ProtocolError, /after the end/) { read_rows([OID::INT4], [good, Bytes[0]]) }
    expect_raises(PG::ProtocolError, /after the end/) { read_rows([OID::INT4], [good + Bytes[0]]) }
    expect_raises(PG::ProtocolError, /2 fields for 1 columns/) { read_rows([OID::INT4], [written([OID::INT4, OID::INT4], &.row(1, 2))]) }
    flagged = good.dup
    flagged[14] = 1_u8
    expect_raises(PG::ProtocolError, /flags/) { read_rows([OID::INT4], [flagged]) }
  end
end

describe "binary COPY on a session" do
  it "aborts the COPY when the block raises, like the text form" do
    received = [] of Char
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('Q')
      client.send('G', Bytes[1, 0, 1, 0, 1])
      loop do
        type, _ = client.read_message || break
        received << type
        break if type == 'f'
      end
      client.error("57014", "COPY from stdin failed: the client aborted the COPY")
      client.ready
    end
    session = PG::Session.connect(PG::Config.parse(server.url))
    expect_raises(Exception, "stop") { session.copy_in_binary("COPY t FROM STDIN (FORMAT binary)", [OID::INT4]) { |rows| rows.row(1); raise "stop" } }
    received.last.should eq 'f'
    received.includes?('c').should be_false
  end
end
