require "../spec_helper"
require "../support/fake_pg_server"
require "../../src/postgres"

private alias PG = CQL::Postgres

private def handshake(server : FakePG, **options) : PG::Handshake::Outcome
  config = PG::Config.parse(server.url(**options))
  io = PG::Transport.connect(config)
  begin
    PG::Handshake.new(config, io).run
  ensure
    io.close
  end
end

describe CQL::Postgres::Handshake do
  it "starts up with trust authentication and records the server's identity" do
    startup = nil
    server = FakePG.start do |client|
      startup = client.read_startup
      client.ok_handshake
      client.read_message
    end
    outcome = handshake(server, password: nil)
    outcome.process_id.should eq 4242
    outcome.secret_key.should eq Bytes[0, 0, 3, 9]
    outcome.status.should eq 'I'
    outcome.parameters["server_version"].should eq "16.0"
    startup.not_nil!.select("user", "database", "client_encoding", "application_name").should eq(
      {"user" => "ada", "database" => "app", "client_encoding" => "UTF8", "application_name" => "cql"}
    )
  end

  it "answers a cleartext password request" do
    sent = nil
    server = FakePG.start do |client|
      client.read_startup
      client.auth(3)
      sent = client.cstrings(client.expect('p'))
      client.ok_handshake
    end
    handshake(server, password: "s3cret")
    sent.not_nil!.first.should eq "s3cret"
  end

  it "answers an md5 password request" do
    sent = nil
    server = FakePG.start do |client|
      client.read_startup
      client.auth(5, Bytes[1, 2, 3, 4])
      sent = client.cstrings(client.expect('p'))
      client.ok_handshake
    end
    handshake(server, user: "postgres", password: "secret")
    sent.not_nil!.first.should eq "md5bb41a296aab6baccb36ff243a562abff"
  end

  it "completes SCRAM-SHA-256 against an independent server implementation" do
    accepted = nil
    server = FakePG.start do |client|
      client.read_startup
      client.auth(10, "SCRAM-SHA-256\0\0".to_slice)
      accepted = FakeScramServer.new("pencil").run(client)
      client.ok_handshake
    end
    handshake(server, password: "pencil")
    accepted.should be_true
  end

  it "fails SCRAM when the server proves it does not know the password" do
    server = FakePG.start do |client|
      client.read_startup
      client.auth(10, "SCRAM-SHA-256\0\0".to_slice)
      FakeScramServer.new("other-password").run(client)
      client.error("28P01", "password authentication failed for user \"ada\"")
    end
    expect_raises(PG::InvalidAuthorization, /28P01/) { handshake(server, password: "pencil") }
  end

  it "rejects a SCRAM server whose final signature is wrong" do
    server = FakePG.start do |client|
      client.read_startup
      client.auth(10, "SCRAM-SHA-256\0\0".to_slice)
      payload = client.expect('p')
      first = String.new(payload[("SCRAM-SHA-256".size + 5)..])
      nonce = first.split(',').find!(&.starts_with?("r=")).sub("r=", "")
      client.auth(11, "r=#{nonce}x,s=c2FsdA==,i=4096".to_slice)
      client.expect('p')
      client.auth(12, "v=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=".to_slice)
    end
    expect_raises(PG::AuthenticationError, /signature/) { handshake(server, password: "pencil") }
  end

  it "refuses servers that offer no SASL mechanism the driver implements" do
    server = FakePG.start do |client|
      client.read_startup
      client.auth(10, "SCRAM-SHA-256-PLUS\0\0".to_slice)
    end
    expect_raises(PG::AuthenticationError, /unsupported SASL/) { handshake(server) }
  end

  it "fails with AuthenticationError when a password is demanded but none configured" do
    server = FakePG.start do |client|
      client.read_startup
      client.auth(3)
    end
    expect_raises(PG::AuthenticationError, /no.*configured|none was configured/) { handshake(server, password: nil) }
  end

  it "raises the typed ServerError for a startup ErrorResponse" do
    server = FakePG.start do |client|
      client.read_startup
      client.error("3D000", "database \"app\" does not exist")
    end
    expect_raises(PG::ServerError, /3D000/) { handshake(server) }
  end

  it "raises ProtocolError for bytes that are not protocol v3" do
    server = FakePG.start do |client|
      client.read_startup
      client.send('?', Bytes.empty)
    end
    expect_raises(PG::ProtocolError) { handshake(server) }
  end

  it "refuses to be authenticated by an empty SCRAM-final message" do
    server = FakePG.start do |client|
      client.read_startup
      client.auth(10, "SCRAM-SHA-256\0\0".to_slice)
      client.expect('p')
      client.auth(12, "v=".to_slice)
      client.auth(0)
      client.ready
    end
    expect_raises(PG::AuthenticationError, /before the exchange/) { handshake(server, password: "pw") }
  end

  it "refuses AuthenticationOk in the middle of SCRAM" do
    server = FakePG.start do |client|
      client.read_startup
      client.auth(10, "SCRAM-SHA-256\0\0".to_slice)
      client.expect('p')
      client.auth(0)
      client.ready
    end
    expect_raises(PG::ProtocolError, /middle of SCRAM/) { handshake(server, password: "pw") }
  end

  it "refuses ReadyForQuery from a server that never authenticated the client" do
    server = FakePG.start do |client|
      client.read_startup
      client.ready
    end
    expect_raises(PG::ProtocolError, /skipped authentication/) { handshake(server) }
  end

  it "tolerates NegotiateProtocolVersion and refuses huge messages before authenticating" do
    server = FakePG.start do |client|
      client.read_startup
      client.send('v', client.int32(0) + client.int32(0))
      client.ok_handshake
    end
    handshake(server).process_id.should eq 4242

    hostile = FakePG.start do |client|
      client.read_startup
      client.io.write(Bytes['R'.ord.to_u8, 0x00, 0x10, 0x00, 0x00])
    end
    expect_raises(PG::ProtocolError, /invalid message length/) { handshake(hostile) }
  end

  it "gives up on a server that accepts the connection and then says nothing" do
    server = FakePG.start { |_| sleep 1.second }
    started = Time.instant
    expect_raises(IO::TimeoutError) { handshake(server, query: "sslmode=disable&connect_timeout=0.2") }
    (Time.instant - started).should be < 1.5.seconds
  end

  it "asks for protocol 3.2 by default and keeps it when the server accepts" do
    asked = nil
    server = FakePG.start do |client|
      asked = client.read_startup["protocol"]
      client.ok_handshake(secret: Bytes.new(32, &.to_u8))
    end
    outcome = handshake(server)
    asked.should eq "3.2"
    outcome.version.should eq CQL::Postgres::ProtocolVersion::V3_2
    outcome.secret_key.size.should eq 32
  end

  it "settles for the minor version the server offers in NegotiateProtocolVersion" do
    server = FakePG.start do |client|
      client.read_startup
      client.send('v', client.int32(0) + client.int32(0))
      client.ok_handshake
    end
    outcome = handshake(server)
    outcome.version.should eq CQL::Postgres::ProtocolVersion::V3_0
    outcome.secret_key.size.should eq 4
  end

  it "understands the whole-version-number form that servers before PostgreSQL 18 send" do
    server = FakePG.start do |client|
      client.read_startup
      client.send('v', client.int32(196608) + client.int32(0))
      client.ok_handshake
    end
    handshake(server).version.should eq CQL::Postgres::ProtocolVersion::V3_0
  end

  it "reports the options the server did not recognise without failing" do
    server = FakePG.start do |client|
      client.read_startup
      client.send('v', client.int32(0) + client.int32(1) + "_pq_.nope\0".to_slice)
      client.ok_handshake
    end
    handshake(server).version.should eq CQL::Postgres::ProtocolVersion::V3_0
  end

  it "refuses a server that only offers a version older than the configured minimum" do
    server = FakePG.start do |client|
      client.read_startup
      client.send('v', client.int32(0) + client.int32(0))
    end
    expect_raises(PG::UnsupportedProtocol, /3.0 at most, but 3.2 or newer/) { handshake(server, query: "sslmode=disable&min_protocol_version=3.2") }
  end

  it "can be pinned to 3.0, which a 3.0 server accepts without negotiation" do
    asked = nil
    server = FakePG.start do |client|
      asked = client.read_startup["protocol"]
      client.ok_handshake
    end
    handshake(server, query: "sslmode=disable&max_protocol_version=3.0").version.should eq CQL::Postgres::ProtocolVersion::V3_0
    asked.should eq "3.0"
  end

  it "treats a server that closes the connection without answering the startup as an unrecognised reply" do
    server = FakePG.start(&.read_startup)
    expect_raises(PG::UnrecognizedStartupReply) { handshake(server) }
  end

  it "treats a connection reset instead of any answer to the startup like a hang-up" do
    server = FakePG.start do |client|
      client.read_startup
      client.io.linger = 0 # closing now sends a reset, not a FIN
      client.io.close
    end
    error = expect_raises(PG::UnrecognizedStartupReply) { handshake(server) }
    error.cause.should be_a IO::Error
    error.cause.should_not be_a IO::EOFError # a reset, not a plain hang-up
  end

  it "does not take a stall for a rejection" do
    server = FakePG.start do |client|
      client.read_startup
      sleep 1.second
    end
    expect_raises(IO::TimeoutError) { handshake(server, query: "sslmode=disable&connect_timeout=0.2") }
  end

  it "reports a startup EOF with the IO error as its cause, so the driver can hand it to crystal-db's retry" do
    server = FakePG.start(&.read_startup)
    error = expect_raises(PG::UnrecognizedStartupReply) { handshake(server) }
    error.cause.should be_a IO::Error
  end

  it "refuses a version negotiation that arrives after authentication began" do
    server = FakePG.start do |client|
      client.read_startup
      client.auth(0)
      client.send('v', client.int32(0) + client.int32(0))
    end
    expect_raises(PG::ProtocolError, /negotiation after authentication/) { handshake(server) }
  end

  it "rejects a cancel key whose length the negotiated version does not allow" do
    long_key = FakePG.start do |client|
      client.read_startup
      client.send('v', client.int32(0) + client.int32(0))
      client.ok_handshake(secret: Bytes.new(8))
    end
    expect_raises(PG::ProtocolError, /8-byte cancel key is not valid for protocol 3.0/) { handshake(long_key) }

    too_long = FakePG.start do |client|
      client.read_startup
      client.ok_handshake(secret: Bytes.new(257))
    end
    expect_raises(PG::ProtocolError, /257-byte cancel key/) { handshake(too_long) }
  end

  it "rejects unknown protocol version names in the URL" do
    expect_raises(ArgumentError, /unsupported protocol version/) { PG::Config.parse("postgres://h/db?max_protocol_version=3.1") }
    expect_raises(ArgumentError, /newer than max_protocol_version/) { PG::Config.parse("postgres://h/db?min_protocol_version=3.2&max_protocol_version=3.0") }
  end
end
