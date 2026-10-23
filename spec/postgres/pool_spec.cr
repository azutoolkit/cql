require "../spec_helper"
require "../support/fake_pg_server"
require "../../src/postgres"

private alias PG = CQL::Postgres

private def idle_server(&on_query : String ->) : FakePG
  FakePG.start do |client|
    client.read_startup
    client.ok_handshake
    client.idle(&on_query)
  end
end

private def idle_server : FakePG
  idle_server { |_| }
end

private def pool_for(server : FakePG, query = "") : PG::Pool
  PG::Pool.new(PG::Config.parse(server.url(query: "sslmode=disable#{query}")))
end

describe CQL::Postgres::Pool do
  it "reuses a released connection instead of opening another" do
    server = idle_server
    pool = pool_for(server)
    first = pool.with_connection(&.itself)
    second = pool.with_connection(&.itself)
    second.should be first
    server.accepted.should eq 1
  end

  it "opens connections up to pool_size, then times out with a useful error" do
    server = idle_server
    pool = pool_for(server, "&pool_size=2&checkout_timeout=0.05")
    a = pool.checkout
    b = pool.checkout
    error = expect_raises(PG::PoolTimeout, /pool size 2/) { pool.checkout }
    error.message.to_s.should_not contain "secret"
    server.accepted.should eq 2
    {a, b}.each(&.release)
  end

  it "hands a connection to a waiting fiber as soon as one is released" do
    server = idle_server
    pool = pool_for(server, "&pool_size=1&checkout_timeout=2")
    held = pool.checkout
    spawn do
      sleep 20.milliseconds
      held.release
    end
    waited = pool.checkout
    waited.should be held
    waited.release
  end

  it "does not let released connections that are mid-transaction back into the pool" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      while message = client.read_message
        case message[0]
        when 'Q' then client.command_complete("BEGIN"); client.ready('T')
        when 'X' then break
        end
      end
    end
    pool = pool_for(server, "&pool_size=1")
    pool.with_connection(&.exec_all("BEGIN"))
    pool.stats.idle.should eq 0
    pool.with_connection(&.itself).closed?.should be_false
    server.accepted.should eq 2
  end

  it "ignores a second release of the same connection instead of lending out an extra slot" do
    pool = pool_for(idle_server, "&pool_size=1&checkout_timeout=0.05")
    connection = pool.checkout
    connection.release
    connection.release
    pool.stats.should eq PG::Pool::Stats.new(1, 1, 0)
    first = pool.checkout
    expect_raises(PG::PoolTimeout) { pool.checkout }
    first.release
  end

  it "keeps a checked-out connection leased across several statements" do
    server = idle_server
    pool = pool_for(server, "&pool_size=2")
    connection = pool.checkout
    connection.exec_all("SELECT 1")
    connection.exec_all("SELECT 2")
    pool.stats.should eq PG::Pool::Stats.new(2, 0, 1)
    connection.release
  end

  it "clears notice and notification handlers when a connection is released" do
    pool = pool_for(idle_server, "&pool_size=1")
    connection = pool.checkout
    connection.on_notice { |_| }
    connection.on_notification { |_| }
    connection.release
    again = pool.checkout
    again.session.on_notice.should be_nil
    again.session.on_notification.should be_nil
    again.release
  end

  it "frees the slot when a checked-out connection is closed" do
    server = idle_server
    pool = pool_for(server, "&pool_size=1&checkout_timeout=0.05")
    pool.checkout.close
    pool.stats.in_use.should eq 0
    pool.with_connection(&.ping).should be_true
  end

  it "frees the slot when connecting fails" do
    server = idle_server
    url = server.url(query: "sslmode=disable&pool_size=1&checkout_timeout=0.05")
    server.close
    pool = PG::Pool.new(PG::Config.parse(url))
    2.times { expect_raises(IO::Error, /cannot connect/) { pool.checkout } }
    pool.stats.in_use.should eq 0
  end

  it "pings connections idle longer than health_check_after and replaces dead ones" do
    pings = 0
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.idle { |sql| pings += 1 if sql.empty? }
    end
    pool = pool_for(server, "&health_check_after=0")
    pool.with_connection(&.itself)
    pool.with_connection(&.itself)
    pings.should eq 1

    dying = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
    end
    dying_pool = pool_for(dying, "&health_check_after=0")
    first = dying_pool.with_connection(&.itself)
    sleep 20.milliseconds
    second = dying_pool.with_connection(&.itself)
    second.should_not be first
    dying.accepted.should eq 2
  end

  it "does not ping connections used recently" do
    pings = 0
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.idle { |sql| pings += 1 if sql.empty? }
    end
    pool = pool_for(server, "&health_check_after=60")
    3.times { pool.with_connection(&.itself) }
    pings.should eq 0
  end

  it "reports idle and in-use connections" do
    pool = pool_for(idle_server, "&pool_size=3")
    a = pool.checkout
    b = pool.checkout
    b.auto_release = false
    pool.stats.should eq PG::Pool::Stats.new(3, 0, 2)
    b.release
    pool.stats.should eq PG::Pool::Stats.new(3, 1, 1)
    a.release
  end

  it "returns the connection even when the block raises" do
    pool = pool_for(idle_server, "&pool_size=1")
    expect_raises(Exception, "boom") { pool.with_connection { |_| raise "boom" } }
    pool.stats.idle.should eq 1
  end

  it "never runs more statements at once than pool_size, whatever the number of fibers" do
    server = idle_server { |_| sleep 5.milliseconds }
    pool = pool_for(server, "&pool_size=3&checkout_timeout=5")
    done = Channel(Nil).new
    20.times do
      spawn do
        pool.with_connection(&.exec_all("SELECT 1"))
        done.send(nil)
      end
    end
    20.times { done.receive }
    server.max_open.should be <= 3
    server.accepted.should be <= 3
  end

  it "closes idle connections and refuses further checkouts once closed" do
    server = idle_server
    pool = pool_for(server)
    pool.with_connection(&.itself)
    held = pool.checkout
    held.auto_release = false
    pool.close
    pool.closed?.should be_true
    expect_raises(PG::PoolClosed) { pool.checkout }
    held.release
    held.closed?.should be_true
  end

  it "refuses a checkout that was waiting when the pool closed, and gives its slot back" do
    pool = pool_for(idle_server, "&pool_size=1&checkout_timeout=2")
    held = pool.checkout
    held.auto_release = false
    waiter = Channel(Exception?).new
    spawn do
      pool.checkout
      waiter.send(nil)
    rescue ex
      waiter.send(ex)
    end
    Fiber.yield
    pool.close
    held.release
    waiter.receive.should be_a PG::PoolClosed
  end

  it "rejects a pool with no room for connections" do
    expect_raises(ArgumentError, /pool_size/) { PG::Pool.new(PG::Config.parse("postgres://h/db?pool_size=0")) }
  end

  describe "lifecycle" do
    it "retires a connection after max_queries requests" do
      server = idle_server
      pool = pool_for(server, "&pool_size=1&max_queries=2")
      first = pool.with_connection { |connection| connection.exec_all("SELECT 1"); connection }
      pool.with_connection { |connection| connection.should be first; connection.exec_all("SELECT 2") }
      first.closed?.should be_true
      pool.with_connection(&.itself).should_not be first
      server.accepted.should eq 2
    end

    it "retires a connection that sat idle for longer than max_idle_lifetime" do
      server = idle_server
      pool = pool_for(server, "&pool_size=1&max_idle_lifetime=0.05")
      first = pool.with_connection(&.itself)
      sleep 80.milliseconds
      pool.with_connection(&.itself).should_not be first
      first.closed?.should be_true
      server.accepted.should eq 2
    end

    it "opens pool_min_size connections up front and fails fast when they cannot be opened" do
      server = idle_server
      pool = pool_for(server, "&pool_size=3&pool_min_size=2").warm_up
      pool.stats.should eq PG::Pool::Stats.new(3, 2, 0)
      server.accepted.should eq 2
      expect_raises(IO::Error, /Connection refused/) { PG::Pool.new(PG::Config.parse("postgres://u:p@127.0.0.1:1/db?sslmode=disable&pool_min_size=1&connect_timeout=1")).warm_up }
    end

    it "runs the setup hook on each new connection and drops one whose setup fails" do
      statements = [] of String
      server = idle_server { |sql| statements << sql }
      config = PG::Config.parse(server.url(query: "sslmode=disable&pool_size=2"))
      options = PG::Pool::Options.from(config).copy_with(setup: ->(connection : PG::Connection) { connection.exec_all("SET search_path TO app") })
      pool = PG::Pool.new(config, options)
      pool.with_connection(&.itself)
      statements.should eq ["SET search_path TO app"]

      failing = PG::Pool::Options.from(config).copy_with(setup: ->(_connection : PG::Connection) { raise "setup broke" })
      expect_raises(Exception, "setup broke") { PG::Pool.new(config, failing).checkout }
    end

    it "rolls back a transaction the borrower left open and reuses the connection" do
      statements = [] of String
      server = FakePG.start do |client|
        client.read_startup
        client.ok_handshake
        while message = client.read_message
          break if message[0] == 'X'
          sql = String.new(message[1]).chomp('\0')
          statements << sql
          status = sql == "BEGIN" ? 'T' : 'I'
          client.command_complete(sql)
          client.ready(status)
        end
      end
      pool = pool_for(server, "&pool_size=1")
      leaked = pool.with_connection { |connection| connection.exec_all("BEGIN"); connection }
      statements.should eq ["BEGIN", "ROLLBACK"]
      pool.with_connection(&.itself).should be leaked
      server.accepted.should eq 1
    end

    it "runs the reset statement on release and drops the connection when it fails" do
      statements = [] of String
      server = FakePG.start do |client|
        client.read_startup
        client.ok_handshake
        while message = client.read_message
          break if message[0] == 'X'
          sql = String.new(message[1]).chomp('\0')
          statements << sql
          sql.starts_with?("RESET") ? client.error("42501", "denied") : client.command_complete("OK")
          client.ready
        end
      end
      config = PG::Config.parse(server.url(query: "sslmode=disable&pool_size=1"))
      options = PG::Pool::Options.from(config)
      kept = PG::Pool.new(config, options.copy_with(reset_sql: "DISCARD ALL"))
      first = kept.with_connection { |connection| connection.exec_all("SELECT 1"); connection }
      kept.with_connection(&.itself).should be first
      statements.should eq ["SELECT 1", "DISCARD ALL", "DISCARD ALL"]

      broken = PG::Pool.new(config, options.copy_with(reset_sql: "RESET broken"))
      lost = broken.with_connection(&.itself)
      lost.closed?.should be_true
      broken.stats.idle.should eq 0
    end

    it "runs the setup hook again after the reset statement, since a reset undoes it" do
      statements = [] of String
      server = idle_server { |sql| statements << sql }
      config = PG::Config.parse(server.url(query: "sslmode=disable&pool_size=1"))
      options = PG::Pool::Options.from(config).copy_with(reset_sql: "RESET ALL", setup: ->(connection : PG::Connection) { connection.exec_all("SET x TO 1") })
      PG::Pool.new(config, options).with_connection(&.itself)
      statements.should eq ["SET x TO 1", "RESET ALL", "SET x TO 1"]
    end

    it "drops a connection whose reset raises something unexpected, and returns its slot" do
      config = PG::Config.parse(idle_server.url(query: "sslmode=disable&pool_size=1&checkout_timeout=0.2"))
      broken = PG::Pool.new(config, PG::Pool::Options.from(config).copy_with(reset_sql: "SELECT '\0'"))
      lost = broken.with_connection(&.itself)
      lost.closed?.should be_true
      broken.with_connection(&.itself).should_not be lost
    end

    it "clears crystal-db's transaction flag when it rolls back a leaked transaction" do
      server = FakePG.start do |client|
        client.read_startup
        client.ok_handshake
        while message = client.read_message
          break if message[0] == 'X'
          sql = String.new(message[1]).chomp('\0')
          status = sql == "BEGIN" ? 'T' : 'I'
          client.command_complete(sql)
          client.ready(status)
        end
      end
      pool = pool_for(server, "&pool_size=1")
      leaked = pool.with_connection { |connection| connection.begin_transaction; connection }
      reused = pool.with_connection do |connection|
        connection.transaction { |_| }
        connection
      end
      reused.should be leaked
    end

    it "closes the connections already opened when warm_up fails part way" do
      server = idle_server
      calls = 0
      config = PG::Config.parse(server.url(query: "sslmode=disable&pool_size=3&pool_min_size=3"))
      options = PG::Pool::Options.from(config).copy_with(setup: ->(_connection : PG::Connection) { (calls += 1) == 3 ? raise("setup broke") : nil })
      expect_raises(Exception, "setup broke") { PG::Pool.new(config, options).warm_up }
    end

    it "does not wait on a health check the idle connection never answers" do
      server = FakePG.start do |client|
        client.read_startup
        client.ok_handshake
        client.read_message # a health-check ping, never answered
        sleep 5.seconds
      end
      pool = pool_for(server, "&pool_size=1&health_check_after=0&checkout_timeout=0.3")
      first = pool.with_connection(&.itself)
      started = Time.instant
      replacement = pool.checkout
      (Time.instant - started).should be < 2.seconds
      replacement.should_not be first
      first.closed?.should be_true
    end

    it "spends one health-check budget per checkout, not one per idle connection" do
      pings = Atomic(Int32).new(0)
      server = FakePG.start do |client|
        client.read_startup
        client.ok_handshake
        message = client.read_message
        pings.add(1) if message && message[0] == 'Q' # a ping; the others only see the Terminate of a discarded connection
        sleep 5.seconds
      end
      pool = pool_for(server, "&pool_size=4&health_check_after=0&checkout_timeout=0.4")
      held = Array.new(3) { pool.checkout }
      held.each(&.release)
      started = Time.instant
      pool.checkout
      (Time.instant - started).should be < 1.5.seconds # three stale connections, one 0.4s budget
      pings.get.should eq 1
    end

    it "wakes fibers waiting for a connection when the pool closes" do
      pool = pool_for(idle_server, "&pool_size=1&checkout_timeout=10")
      held = pool.checkout
      waiter = Channel(Exception?).new
      spawn do
        pool.checkout
        waiter.send(nil)
      rescue ex
        waiter.send(ex)
      end
      Fiber.yield
      started = Time.instant
      pool.close
      waiter.receive.should be_a PG::PoolClosed
      (Time.instant - started).should be < 2.seconds
      held.close
    end

    it "rejects malformed pool options instead of using a default" do
      {"pool_size=abc", "pool_min_size=1.5", "max_queries=many", "max_idle_lifetime=soon", "checkout_timeout=-1", "health_check_after=x"}.each do |option|
        expect_raises(ArgumentError, /#{option.split('=').first}/) { PG::Pool::Options.from(PG::Config.parse("postgres://h/db?#{option}")) }
      end
    end

    it "rejects impossible sizes" do
      expect_raises(ArgumentError, /pool_min_size/) { PG::Pool.new(PG::Config.parse("postgres://h/db?pool_size=2&pool_min_size=3")) }
      expect_raises(ArgumentError, /max_queries/) { PG::Pool.new(PG::Config.parse("postgres://h/db?max_queries=0")) }
    end
  end
end
