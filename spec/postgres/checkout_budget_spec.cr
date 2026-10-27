require "../spec_helper"
require "../support/fake_pg_server"
require "../support/native_database"

private alias PG = CQL::Postgres

# Every example uses checkout_timeout=1, and a health check gets at most half of it. A wait that ignores the budget
# takes a fresh one (a connect after the health check: 1.5 s) or connect_timeout (10 s per step), so 1.4 s tells them apart.
private BOUND = 1.4.seconds

# Writes to the socket a byte every *pause*: each read the client makes is answered in time, but a connect that bounds
# reads rather than the whole connect lasts as long as the server likes.
private class TrickleIO < IO
  def initialize(@socket : IO, @pause : Time::Span)
  end

  delegate read, to: @socket

  def write(slice : Bytes) : Nil
    slice.each { |byte| sleep @pause; @socket.write_byte(byte) }
  end
end

# Reads the startup and answers nothing until the client hangs up, like a peer behind a half-open path.
private def silent(client : FakePG::Client) : Nil
  client.read_startup
  client.read_message
end

# How long the block ran, and what it raised.
private def timed(&) : {Time::Span, Exception?}
  started = Time.instant
  begin
    yield
    {Time.instant - started, nil}
  rescue ex
    {Time.instant - started, ex}
  end
end

# How long an INSERT took, what it raised and what the server ran, on a schema over crystal-db's pool whose *dead* idle
# connections all have input waiting (each checkout pings one) and never answer; later connections answer at once.
private def insert_past_dead_idle(dead : Int32) : {Time::Span, Exception?, Array(String)}
  poke, log, connections, result = Channel(Nil).new(dead), [] of String, 0, nil
  server = FakePG.start do |client|
    client.read_startup
    client.ok_handshake
    next client.idle { |sql| log << sql unless sql.empty? } if (connections += 1) > dead
    poke.receive
    client.notice("unsolicited") # input waiting on an idle connection: its checkout pings it
    client.read_message          # the ping, never answered
    client.read_message
  end
  open_native(server.url(query: "sslmode=disable&initial_pool_size=#{dead}&max_idle_pool_size=#{dead}&checkout_timeout=1&prepared_statements=false")) do |db|
    schema = CQL::Schema.new(:checkout_budget, server.url, CQL::Adapter::Postgres, source: CQL::DatabaseSource.new(db))
    dead.times { poke.send(nil) }
    sleep 100.milliseconds # the notices reach every idle socket
    result = timed { schema.exec("INSERT INTO t VALUES (1)") }
  end
  {*result.not_nil!, log}
end

# The checkout gives up within BOUND with a timeout that names the server.
private def checkout_times_out(pool : PG::Pool, server : FakePG) : Nil
  elapsed, error = timed { pool.checkout }
  elapsed.should be < BOUND
  error.should be_a IO::TimeoutError
  error.try(&.message).to_s.should contain "127.0.0.1:#{server.port}"
end

describe "checkout_timeout bounds a whole checkout" do
  it "fails the engine pool's connect to a server that never answers the startup" do
    server = FakePG.start { |client| silent(client) }
    pool = PG::Pool.new(PG::Config.parse(server.url(query: "sslmode=disable&checkout_timeout=1")))
    checkout_times_out(pool, server)
  end

  it "fails the engine pool's connect to a server that never answers the SSLRequest" do
    server = FakePG.start { |client| silent(client) }
    pool = PG::Pool.new(PG::Config.parse(server.url(query: "sslmode=prefer&checkout_timeout=1")))
    checkout_times_out(pool, server)
  end

  it "gives up connecting when the budget an unanswered health check left runs out" do
    connections = 0
    server = FakePG.start do |client|
      next silent(client) if (connections += 1) > 1
      client.read_startup
      client.ok_handshake
      client.read_message # the health-check ping, never answered
      client.read_message
    end
    pool = PG::Pool.new(PG::Config.parse(server.url(query: "sslmode=disable&checkout_timeout=1&health_check_after=0")))
    pool.with_connection { }
    checkout_times_out(pool, server)
  end

  it "fails a connect whose first startup reply trickles in a byte at a time" do
    server = FakePG.start do |client|
      client.read_startup
      TrickleIO.new(client.io, 0.3.seconds).write(FakePG.frame('R', client.int32(0)))
    end
    checkout_times_out(PG::Pool.new(PG::Config.parse(server.url(query: "sslmode=disable&checkout_timeout=1"))), server)
  end

  it "fails a connect whose later startup message trickles in a byte at a time" do
    server = FakePG.start do |client|
      client.read_startup
      client.auth(0)
      TrickleIO.new(client.io, 0.3.seconds).write(FakePG.frame('N', "Mslow\0\0".to_slice))
    end
    checkout_times_out(PG::Pool.new(PG::Config.parse(server.url(query: "sslmode=disable&checkout_timeout=1"))), server)
  end

  it "fails a connect whose TLS handshake trickles in after a late SSLRequest answer" do
    context = TlsFixture.server_context
    pending! "needs the openssl command line tool for a certificate" unless context
    server = FakePG.start do |client|
      client.read_startup # the SSLRequest
      sleep 0.9.seconds
      client.io.write("S".to_slice)
      OpenSSL::SSL::Socket::Server.new(TrickleIO.new(client.io, 2.milliseconds), context, sync_close: false)
    rescue OpenSSL::Error # the client walked away mid-handshake
    end
    checkout_times_out(PG::Pool.new(PG::Config.parse(server.url(query: "sslmode=prefer&checkout_timeout=1"))), server)
  end

  it "fails crystal-db's connect to a server that never answers the startup" do
    server = FakePG.start { |client| silent(client) }
    open_native(server.url(query: "sslmode=disable&initial_pool_size=0&checkout_timeout=1")) do |db|
      elapsed, error = timed { db.checkout }
      elapsed.should be < BOUND
      error.should be_a DB::ConnectionRefused
      error.try(&.message).to_s.should contain "127.0.0.1:#{server.port}"
    end
  end

  # Three, so pings bounded by half a budget each (1.5 s) do not pass for one budget.
  it "spends one budget on the idle connections a schema finds with unanswered input in crystal-db's pool" do
    elapsed, error, log = insert_past_dead_idle(3)
    elapsed.should be < BOUND
    error.try &.should be_a DB::Error
    log.should eq(error ? [] of String : ["INSERT INTO t VALUES (1)"]) # failed having sent nothing, or ran once
  end

  # Six, so pings taking half of what each finds left (0.5 + 0.25 + ... s) would leave the connect no time.
  it "leaves the replacement connect the half of a schema's budget its health checks did not share" do
    elapsed, error, log = insert_past_dead_idle(6)
    error.should be_nil
    elapsed.should be < BOUND
    log.should eq ["INSERT INTO t VALUES (1)"]
  end
end
