require "../spec_helper"
require "../support/fake_pg_server"

private alias PG = CQL::Postgres

# Every example uses checkout_timeout=1, and a health check gets at most half of it. A wait that ignores the budget
# takes a fresh one (a connect after the health check: 1.5 s) or connect_timeout (10 s per step), so 1.4 s tells them apart.
private BOUND = 1.4.seconds

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

describe "checkout_timeout bounds a whole checkout" do
  it "fails the engine pool's connect to a server that never answers the startup" do
    server = FakePG.start { |client| silent(client) }
    pool = PG::Pool.new(PG::Config.parse(server.url(query: "sslmode=disable&checkout_timeout=1")))
    elapsed, error = timed { pool.checkout }
    elapsed.should be < BOUND
    error.should be_a IO::TimeoutError
    error.try(&.message).to_s.should contain "127.0.0.1:#{server.port}"
  end

  it "fails the engine pool's connect to a server that never answers the SSLRequest" do
    server = FakePG.start { |client| silent(client) }
    pool = PG::Pool.new(PG::Config.parse(server.url(query: "sslmode=prefer&checkout_timeout=1")))
    elapsed, error = timed { pool.checkout }
    elapsed.should be < BOUND
    error.should be_a IO::TimeoutError
    error.try(&.message).to_s.should contain "127.0.0.1:#{server.port}"
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
    elapsed, error = timed { pool.checkout }
    elapsed.should be < BOUND
    error.should be_a IO::TimeoutError
    error.try(&.message).to_s.should contain "127.0.0.1:#{server.port}"
  end
end
