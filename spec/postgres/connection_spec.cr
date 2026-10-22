require "../spec_helper"
require "../support/fake_pg_server"
require "../../src/postgres"

private alias PG = CQL::Postgres

private def open_connection(server : FakePG) : PG::Connection
  PG::Connection.open(PG::Config.parse(server.url(query: "sslmode=disable")))
end

private def be_int32(value : Int32) : Bytes
  Bytes.new(4).tap { |bytes| IO::ByteFormat::NetworkEndian.encode(value, bytes) }
end

private struct Pet
  include DB::Serializable

  getter id : Int32
  getter name : String
  getter age : Int32?
end

private PET_COLUMNS = [{"id", 23_u32}, {"name", 25_u32}, {"age", 23_u32}]

private def serve_pets(client : FakePG::Client, params = 0) : Nil
  client.serve_prepare(Array.new(params) { 25_u32 }, PET_COLUMNS)
  client.serve_execute([
    [be_int32(1), "rex".to_slice, be_int32(3)] of Bytes?,
    [be_int32(2), "tom".to_slice, nil] of Bytes?,
  ], "SELECT 2")
end

describe CQL::Postgres::Connection do
  it "is a crystal-db connection that maps rows into tuples, models and scalars" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      serve_pets(client)
      client.expect('B'); client.expect('E'); client.expect('S')
      client.send('2')
      client.data_row([be_int32(1), "rex".to_slice, be_int32(3)] of Bytes?)
      client.data_row([be_int32(2), "tom".to_slice, nil] of Bytes?)
      client.command_complete("SELECT 2")
      client.ready
      client.serve_prepare([] of UInt32, [{"count", 20_u32}])
      client.serve_execute([[Bytes[0, 0, 0, 0, 0, 0, 0, 2]] of Bytes?], "SELECT 1")
    end
    db = open_connection(server)
    db.should be_a DB::Connection
    db.query_all("SELECT id, name, age FROM pets", as: {Int32, String, Int32?}).should eq [{1, "rex", 3}, {2, "tom", nil}]
    db.query_all("SELECT id, name, age FROM pets", as: Pet).map { |pet| {pet.name, pet.age} }.should eq [{"rex", 3}, {"tom", nil}]
    db.scalar("SELECT count(*) FROM pets").should eq 2_i64
  end

  it "binds arguments as parameters and reports rows affected for exec" do
    bound = nil
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.serve_prepare([25_u32, 23_u32, 1184_u32, 17_u32], [] of {String, UInt32})
      reader = PG::Wire::Reader.new(client.expect('B'))
      reader.cstring; reader.cstring
      formats = Array.new(reader.uint16.to_i) { reader.int16 }
      values = Array.new(reader.uint16.to_i) do
        length = reader.int32
        length < 0 ? nil : reader.bytes(length)
      end
      bound = {formats, values.map { |value| value.try { |bytes| String.new(bytes) } }}
      client.expect('E'); client.expect('S')
      client.send('2'); client.command_complete("INSERT 0 1"); client.ready
    end
    db = open_connection(server)
    result = db.exec("INSERT INTO pets (name, age, born, photo) VALUES ($1, $2, $3, $4)", "rex'; --", nil, Time.utc(2024, 1, 2, 3, 4, 5), Bytes[0xff, 0])
    result.rows_affected.should eq 1
    formats, values = bound.not_nil!
    formats.should eq [0_i16, 0_i16, 0_i16, 1_i16]
    values[0].should eq "rex'; --"
    values[1].should be_nil
    values[2].should eq "2024-01-02 03:04:05.000000+00"
  end

  it "runs unprepared statements without parameters through the simple protocol" do
    statements = [] of String
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      loop do
        message = client.read_message || break
        case message[0]
        when 'Q'
          statements << String.new(message[1]).chomp('\0')
          client.command_complete(statements.last.starts_with?("UPDATE") ? "UPDATE 3" : "OK")
          client.ready(statements.last == "BEGIN" ? 'T' : 'I')
        when 'X' then break
        else          raise "unexpected #{message[0]}"
        end
      end
    end
    db = open_connection(server)
    db.unprepared.exec("UPDATE pets SET age = 1").rows_affected.should eq 3
    db.exec_all("INSERT INTO pets DEFAULT VALUES; INSERT INTO pets DEFAULT VALUES")
    db.transaction { |tx| tx.connection.unprepared.exec("UPDATE pets SET age = 2") }
    statements.should eq ["UPDATE pets SET age = 1", "INSERT INTO pets DEFAULT VALUES; INSERT INTO pets DEFAULT VALUES", "BEGIN", "UPDATE pets SET age = 2", "COMMIT"]
  end

  it "rolls back on Rollback and on exceptions" do
    statements = [] of String
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      loop do
        message = client.read_message || break
        case message[0]
        when 'Q'
          statements << String.new(message[1]).chomp('\0')
          client.command_complete("OK")
          client.ready(statements.last == "BEGIN" ? 'T' : 'I')
        when 'X' then break
        end
      end
    end
    db = open_connection(server)
    db.transaction(&.rollback)
    expect_raises(Exception, "boom") { db.transaction { |_| raise "boom" } }
    statements.should eq ["BEGIN", "ROLLBACK", "BEGIN", "ROLLBACK"]
    db.in_transaction?.should be_false
  end

  it "turns a lost connection into DB::ConnectionLost, which crystal-db's pool understands" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('P')
    end
    db = open_connection(server)
    expect_raises(DB::ConnectionLost) { db.scalar("SELECT 1") }
    db.session.closed?.should be_true
  end

  it "raises the typed server error through the DB API" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.serve_prepare([] of UInt32, [] of {String, UInt32})
      client.expect('B'); client.expect('E'); client.expect('S')
      client.send('2'); client.error("23505", "duplicate key value violates unique constraint \"pets_name_key\""); client.ready
    end
    expect_raises(PG::UniqueViolation, /pets_name_key/) { open_connection(server).exec("INSERT INTO pets (name) VALUES ('rex')") }
  end

  it "rejects a column read as the wrong type with crystal-db's usual error" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      serve_pets(client)
    end
    expect_raises(DB::ColumnTypeMismatchError, /returned a Int32 but a String was expected/) { open_connection(server).query_all("SELECT id FROM pets", as: {String, String, Int32?}) }
  end

  it "exposes ping, notices, notifications and COPY from the session" do
    notices = [] of String
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('Q'); client.notice("hello"); client.command_complete("OK"); client.ready
      client.expect('Q'); client.send('H', Bytes[0, 0, 1, 0, 0]); client.send('d', "a\n".to_slice); client.send('c'); client.command_complete("COPY 1"); client.ready
      client.expect('Q'); client.send('I'); client.ready
    end
    db = open_connection(server)
    db.on_notice { |fields| notices << fields['M'] }
    db.exec_all("SELECT 1")
    notices.should eq ["hello"]
    chunks = [] of String
    db.copy_out("COPY t TO STDOUT") { |chunk| chunks << String.new(chunk) }.should eq 1
    chunks.should eq ["a\n"]
    db.ping.should be_true
  end

  it "closes the session when closed" do
    received = [] of Char
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.read_message
      received.concat(client.received)
    end
    db = open_connection(server)
    db.close
    db.closed?.should be_true
    server.await
    received.should eq ['X']
  end
end
