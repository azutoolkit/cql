require "../spec_helper"
require "../support/fake_pg_server"

describe "native pool setup deadline" do
  it "also bounds setup when DISCARD ALL reruns it during check-in" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.idle
    end
    resume = Channel(Nil).new(1)
    finished = Channel(Nil).new(1)
    calls = Atomic(Int32).new(0)
    hook = ->(_connection : CQL::Postgres::Connection) do
      if calls.add(1) == 1
        resume.receive
        finished.send(nil)
      end
      nil
    end
    config = CQL::Postgres::Config.parse(server.url(query: "sslmode=disable"))
    options = CQL::Postgres::Pool::Options.new(max_size: 1, checkout_timeout: 200.milliseconds,
      reset_sql: "DISCARD ALL", setup: hook)
    pool = CQL::Postgres::Pool.new(config, options)
    connection = pool.checkout
    started = Time.instant
    connection.release
    (Time.instant - started).should be < 1.second
    connection.closed?.should be_true
    pool.with_connection(&.should_not(be(connection)))
    resume.send(nil)
    select
    when finished.receive
    when timeout(1.second) then fail "reset worker did not finish"
    end
  ensure
    resume.try(&.close)
    pool.try(&.close)
    server.try(&.close)
  end

  it "drops stalled setup SQL within checkout_timeout and recovers the only pool slot" do
    connections = Atomic(Int32).new(0)
    disconnected = Channel(Bool).new(1)
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      if connections.add(1) == 0
        client.expect('Q')
        disconnected.send(client.read_message.nil?)
      else
        client.idle
      end
    end
    hook = ->(connection : CQL::Postgres::Connection) { connection.exec_all("SELECT setup") }
    config = CQL::Postgres::Config.parse(server.url(query: "sslmode=disable"))
    options = CQL::Postgres::Pool::Options.new(max_size: 1, checkout_timeout: 200.milliseconds, setup: hook)
    pool = CQL::Postgres::Pool.new(config, options)
    started = Time.instant
    expect_raises(IO::TimeoutError, /setup/) { pool.checkout }
    (Time.instant - started).should be < 1.second
    select
    when closed = disconnected.receive then closed.should be_true
    when timeout(1.second) then fail "setup socket remained open"
    end
    pool.with_connection(&.exec_all("SELECT recovered"))
    pool.stats.should eq CQL::Postgres::Pool::Stats.new(1, 1, 0)
  ensure
    pool.try(&.close)
    server.try(&.close)
  end

  it "releases a slot even when the hook waits outside SQL, and never admits its late result" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.idle
    end
    resume = Channel(Nil).new(1)
    entered = Channel(CQL::Postgres::Connection).new(1)
    finished = Channel(Nil).new(1)
    calls = Atomic(Int32).new(0)
    hook = ->(connection : CQL::Postgres::Connection) do
      if calls.add(1) == 0
        entered.send(connection)
        resume.receive
        finished.send(nil)
      end
      nil
    end
    config = CQL::Postgres::Config.parse(server.url(query: "sslmode=disable"))
    options = CQL::Postgres::Pool::Options.new(max_size: 1, checkout_timeout: 200.milliseconds, setup: hook,
      connect_failure_threshold: 1, connect_retry_delay: 20.milliseconds)
    pool = CQL::Postgres::Pool.new(config, options)
    expect_raises(IO::TimeoutError, /setup/) { pool.checkout }
    abandoned = entered.receive
    abandoned.closed?.should be_true
    expect_raises(CQL::Postgres::CircuitOpen) { pool.checkout }
    sleep 30.milliseconds
    pool.with_connection do |connection|
      connection.should_not be abandoned
      connection.exec_all("SELECT recovered")
    end
    resume.send(nil)
    select
    when finished.receive
    when timeout(1.second) then fail "setup worker did not finish"
    end
    pool.stats.should eq CQL::Postgres::Pool::Stats.new(1, 1, 0)
  ensure
    resume.try(&.close)
    pool.try(&.close)
    server.try(&.close)
  end
end
