require "log/spec"
require "../spec_helper"
require "../../src/postgres"

private alias PG = CQL::Postgres

# Completes the handshake and answers the simple queries named in *answered* (BEGIN, SAVEPOINT) as a server
# inside a transaction would, then reads and never answers, like a server behind a half-open TCP path.
# Cancel requests are accepted and ignored; the read timeout only frees the script after the example.
private def silent_server(answered : Array(String) = [] of String) : FakePG
  FakePG.start do |client|
    next if client.read_startup["protocol"] == "cancel"
    client.ok_handshake
    client.io.read_timeout = 4.seconds
    answered.each { |tag| client.expect('Q'); client.command_complete(tag); client.ready('T') }
    while client.read_message
    end
  end
end

private def live_url(query : String = "") : String
  url = postgres_database_url
  query.empty? ? url : "#{url}#{url.includes?('?') ? '&' : '?'}#{query}"
end

private def live_pool(query : String = "") : PG::Pool
  PG::Pool.new(PG::Config.parse(live_url(query)))
end

describe "query_timeout, the URL key that bounds every statement of the native PostgreSQL driver" do
  it "is unset unless the URL names it, and must be a positive number of seconds" do
    PG::Config.parse("postgres://u@h/db").query_timeout.should be_nil
    PG::Config.parse("postgres://u@h/db?query_timeout=0.5").query_timeout.should eq 0.5.seconds
    {"abc", "0", "-1", "1e-10"}.each do |value|
      expect_raises(ArgumentError, %(query_timeout must be a positive number of seconds up to a year, got "#{value}")) { PG::Config.parse("postgres://u@h/db?query_timeout=#{value}") }
    end
  end

  it "fails a statement on a silent server within the timeout plus the cancel grace, and does not pool the connection" do
    pool = PG::Pool.new(PG::Config.parse(silent_server.url(query: "sslmode=disable&query_timeout=1&pool_size=1")))
    elapsed = Time.measure do
      expect_raises(PG::QueryTimeout) do
        pool.with_connection do |connection|
          connection.session.cancel_grace = 200.milliseconds
          connection.scalar("SELECT 1")
        end
      end
    end
    elapsed.should be < 3.seconds
    pool.stats.to_s.should eq "0 in use, 0 idle, 1 max"
  end

  it "surfaces as QueryTimeout when it drops the session inside a transaction or a savepoint, not as the rollback's lost connection" do
    {["BEGIN"], ["BEGIN", "SAVEPOINT"]}.each do |answered|
      pool = PG::Pool.new(PG::Config.parse(silent_server(answered).url(query: "sslmode=disable&query_timeout=0.2&pool_size=1")))
      expect_raises(PG::QueryTimeout) do
        pool.with_connection do |connection|
          connection.session.cancel_grace = 200.milliseconds
          connection.transaction do |tx|
            answered.size == 1 ? tx.connection.exec("SELECT 1") : tx.transaction(&.connection.exec("SELECT 1"))
          end
        end
      end
    end
  end

  it "leaves a ping to its own deadline: past query_timeout no cancel request is sent" do
    server = silent_server
    session = PG::Session.connect(PG::Config.parse(server.url(query: "sslmode=disable&query_timeout=0.1")))
    session.ping(400.milliseconds).should be_false
    server.accepted.should eq 1
  end

  it "is ignored by a schema opened through crystal-db when another driver (the pg shard, linked in the specs) takes the scheme, and says so" do
    require_postgres!
    CQL.config.log_level = Log::Severity::Warn # the test environment's CQL logger shows errors only
    Log.capture("*", level: :warn) do |logs|
      CQL::Schema.new(:unbounded, live_url, CQL::Adapter::Postgres).close
      logs.empty
      CQL::Schema.new(:bounded, live_url("query_timeout=1"), CQL::Adapter::Postgres).close
      logs.check(:warn, %r{query_timeout is ignored by schemas opened through crystal-db\b.*PG::Driver handles postgres://})
    end
  ensure
    CQL.reset_config!
  end

  it "cancels a live statement that outlives it and keeps the connection; unset, a statement runs to its end" do
    require_postgres!
    bounded = live_pool("query_timeout=1")
    bounded.with_connection do |connection|
      started = Time.instant
      expect_raises(PG::QueryTimeout, /canceled after/) { connection.exec("SELECT pg_sleep(3)") }
      (Time.instant - started).should be < 2.seconds
      connection.scalar("SELECT 1").should eq 1
    end
    bounded.stats.idle.should eq 1
    bounded.close
    unbounded = live_pool
    unbounded.with_connection(&.exec("SELECT pg_sleep(1.2)"))
    unbounded.close
  end
end
