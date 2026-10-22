require "../spec_helper"
require "../support/fake_pg_server"
require "../../src/postgres"

private alias PG = CQL::Postgres

private def decline_tls_then_start_up(client : FakePG::Client) : Nil
  client.read_startup["protocol"].should eq "80877103"
  client.io.write_byte('N'.ord.to_u8)
  client.io.flush
  client.read_startup["protocol"].should eq "3.0"
  client.ok_handshake
end

describe CQL::Postgres::Transport do
  it "falls back to plain text when sslmode=prefer and the server declines TLS" do
    server = FakePG.start { |client| decline_tls_then_start_up(client) }
    config = PG::Config.parse(server.url(query: "sslmode=prefer"))
    io = PG::Transport.connect(config)
    PG::Handshake.new(config, io).run.process_id.should eq 4242
    io.close
  end

  it "refuses to continue without TLS when sslmode=require and the server declines" do
    server = FakePG.start do |client|
      client.read_startup
      client.io.write_byte('N'.ord.to_u8)
      client.io.flush
    end
    expect_raises(IO::Error, /does not support TLS/) { PG::Transport.connect(PG::Config.parse(server.url(query: "sslmode=require"))) }
  end

  it "refuses an unexpected reply to SSLRequest" do
    server = FakePG.start do |client|
      client.read_startup
      client.io.write_byte('E'.ord.to_u8)
      client.io.flush
    end
    expect_raises(IO::Error, /unexpected reply/) { PG::Transport.connect(PG::Config.parse(server.url(query: "sslmode=prefer"))) }
  end

  it "does not ask for TLS when sslmode=disable" do
    asked = nil
    server = FakePG.start do |client|
      asked = client.read_startup["protocol"]
      client.ok_handshake
    end
    config = PG::Config.parse(server.url(query: "sslmode=disable"))
    io = PG::Transport.connect(config)
    PG::Handshake.new(config, io).run
    io.close
    asked.should eq "3.0"
  end

  it "sends a CancelRequest with the session's key over a new connection" do
    request = Channel(Hash(String, String)).new(1)
    server = FakePG.start { |client| request.send(client.read_startup) }
    PG::Transport.cancel(PG::Config.parse(server.url), 4242, 777)
    select
    when received = request.receive
      received.should eq({"protocol" => "cancel", "pid" => "4242", "secret" => "777"})
    when timeout(2.seconds)
      fail "the server never saw the cancel request"
    end
  end

  it "closes the socket when the TLS handshake fails instead of leaking it" do
    hung_up = Channel(Bool).new(1)
    server = FakePG.start do |client|
      client.read_startup
      client.io.write("S\x16\x03\x01garbage that is not a TLS server hello".to_slice)
      client.io.flush
      client.io.read_timeout = 1.second
      begin
        while client.io.read_byte
        end
        hung_up.send(true)
      rescue IO::TimeoutError
        hung_up.send(false)
      end
    end
    expect_raises(IO::Error, /cannot connect/) { PG::Transport.connect(PG::Config.parse(server.url(query: "sslmode=require"))) }
    select
    when closed = hung_up.receive
      closed.should be_true
    when timeout(3.seconds)
      fail "the client kept the socket open"
    end
  end

  it "stops waiting for a silent server after connect_timeout" do
    server = FakePG.start { |_| sleep 2.seconds }
    started = Time.instant
    expect_raises(IO::TimeoutError, /cannot connect to 127.0.0.1/) { PG::Transport.connect(PG::Config.parse(server.url(query: "sslmode=prefer&connect_timeout=0.2"))) }
    (Time.instant - started).should be < 1.5.seconds
  end

  it "lifts the startup time limits once the session is up" do
    server = FakePG.start { |_| sleep 100.milliseconds }
    io = PG::Transport.connect(PG::Config.parse(server.url(query: "sslmode=disable&connect_timeout=0.5"))).as(TCPSocket)
    io.read_timeout.should eq 0.5.seconds
    PG::Transport.relax(io)
    io.read_timeout.should be_nil
    io.write_timeout.should be_nil
    io.close
  end

  it "reports a refused connection with the target but not the password" do
    server = FakePG.start { |_| }
    url = server.url(password: "hunter2")
    server.close
    error = expect_raises(IO::Error, /cannot connect to 127.0.0.1/) { PG::Transport.connect(PG::Config.parse(url)) }
    error.message.to_s.should_not contain "hunter2"
  end
end
