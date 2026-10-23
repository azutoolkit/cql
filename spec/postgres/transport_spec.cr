require "../spec_helper"
require "../support/fake_pg_server"
require "../../src/postgres"

private alias PG = CQL::Postgres

private def decline_tls_then_start_up(client : FakePG::Client) : Nil
  client.read_startup["protocol"].should eq "80877103"
  client.io.write_byte('N'.ord.to_u8)
  client.io.flush
  client.read_startup["protocol"].should eq "3.2"
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
    expect_raises(PG::TLSRefused, /does not support TLS/) { PG::Transport.connect(PG::Config.parse(server.url(query: "sslmode=require"))) }
  end

  it "refuses an unexpected reply to SSLRequest" do
    server = FakePG.start do |client|
      client.read_startup
      client.io.write_byte('E'.ord.to_u8)
      client.io.flush
    end
    expect_raises(PG::TLSRefused, /answered the SSLRequest with .E./) { PG::Transport.connect(PG::Config.parse(server.url(query: "sslmode=prefer"))) }
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
    asked.should eq "3.2"
  end

  it "sends a CancelRequest with the session's key over a new connection" do
    request = Channel(Hash(String, String)).new(1)
    server = FakePG.start { |client| request.send(client.read_startup) }
    PG::Transport.cancel(PG::Config.parse(server.url), 4242, Bytes[0, 0, 3, 9], 5.seconds)
    select
    when received = request.receive
      received.should eq({"protocol" => "cancel", "pid" => "4242", "secret" => "00000309"})
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
      rescue IO::Error
        hung_up.send(true) # closing with unread bytes in the receive buffer resets the connection instead of ending it
      end
    end
    expect_raises(PG::TLSRefused, /TLS to 127.0.0.1.* failed/) { PG::Transport.connect(PG::Config.parse(server.url(query: "sslmode=require"))) }
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

  describe "network failures during TLS setup stay retryable IO errors" do
    it "when the server hangs up after the SSLRequest" do
      server = FakePG.start(&.read_startup)
      expect_raises(IO::Error, /closed the connection after the SSLRequest/) { PG::Transport.connect(PG::Config.parse(server.url(query: "sslmode=require"))) }
    end

    it "when the server hangs up during the handshake" do
      server = FakePG.start do |client|
        client.read_startup
        client.io.write("S".to_slice)
        client.io.flush
        header = Bytes.new(5)
        client.io.read_fully(header) # the whole ClientHello, so closing sends FIN rather than RST
        client.io.read_fully(Bytes.new((header[3].to_i << 8) | header[4].to_i))
      end
      error = expect_raises(IO::Error) { PG::Transport.connect(PG::Config.parse(server.url(query: "sslmode=require"))) }
      error.should_not be_a PG::TLSRefused
    end
  end

  describe "TLS failures reach callers as TLSRefused, which crystal-db's pool does not retry" do
    it "when the server declines TLS under sslmode=require, through the crystal-db builder" do
      server = FakePG.start do |client|
        client.read_startup
        client.io.write_byte('N'.ord.to_u8)
        client.io.flush
      end
      builder = PG::Driver.new.connection_builder(URI.parse(server.url(query: "sslmode=require")))
      error = expect_raises(PG::TLSRefused, /does not support TLS/) { builder.build }
      error.should_not be_a IO::Error
    end

    it "when verify-full rejects the server's certificate" do
      context = TlsFixture.server_context
      pending! "needs the openssl command line tool for a certificate" unless context
      server = FakePG.start do |client|
        client.read_startup # the SSLRequest
        client.upgrade_to_tls(context)
        client.read_startup
      rescue OpenSSL::SSL::Error | IO::Error
        # the client walked away after the failed certificate check
      end
      builder = PG::Driver.new.connection_builder(URI.parse(server.url(query: "sslmode=verify-full")))
      error = expect_raises(PG::TLSRefused, /TLS to 127.0.0.1.* failed/) { builder.build }
      error.cause.should be_a OpenSSL::SSL::Error
    end

    it "times out and drops a TLS request stalled on a full send buffer" do
      context = TlsFixture.server_context
      pending! "needs the openssl command line tool for a certificate" unless context
      server = FakePG.start do |client|
        startup = client.read_startup
        next if startup["protocol"] == "cancel"
        client.upgrade_to_tls(context)
        client.read_startup
        client.ok_handshake
        client.expect('Q')
        client.send('G', Bytes[0, 0, 0, 0, 0])
        sleep 30.seconds # never reads the COPY data: the client's send buffer fills up
      rescue OpenSSL::SSL::Error | IO::Error
      end
      session = PG::Session.connect(PG::Config.parse(server.url(query: "sslmode=require")))
      session.cancel_grace = 200.milliseconds
      started = Time.instant
      expect_raises(PG::QueryTimeout) do
        session.copy_in("COPY t FROM STDIN", timeout: 300.milliseconds) do |copy|
          chunk = Bytes.new(1 << 20, 'x'.ord.to_u8)
          200.times { copy.write(chunk) }
        end
      end
      (Time.instant - started).should be < 5.seconds
      session.closed?.should be_true
    end
  end
end
