require "../spec_helper"
require "../support/fake_pg_server"
require "../../src/postgres"

private alias PG = CQL::Postgres

# The pool `DB.open` builds, on this driver whatever claims postgres:// in the spec binary (the pg shard can).
private def open_native(url : String, & : DB::Database ->) : Nil
  uri = URI.parse(url)
  driver, params = PG::Driver.new, HTTP::Params.parse(uri.query || "")
  builder = driver.connection_builder(uri)
  database = DB::Database.new(driver.connection_options(params), driver.pool_options(params)) { builder.build }
  yield database
ensure
  database.try &.close
end

# Reads one INSERT as crystal-db sends it: Parse/Describe/Sync then Bind/Execute/Sync, or one simple Query.
private def read_insert(client : FakePG::Client, prepared : Bool) : Nil
  if prepared
    client.serve_prepare([] of UInt32, [] of {String, UInt32})
    client.expect('B'); client.expect('E'); client.expect('S')
  else
    client.expect('Q')
  end
end

private def answer_insert(client : FakePG::Client, prepared : Bool) : Nil
  client.send('2') if prepared
  client.command_complete("INSERT 0 1"); client.ready
end

describe CQL::Postgres::Statement do
  {true, false}.each do |prepared|
    it "raises instead of running an INSERT again on another connection when the reply is cut (prepared_statements=#{prepared})" do
      executions = 0
      server = FakePG.start do |client|
        client.read_startup
        client.ok_handshake
        read_insert(client, prepared)
        next if (executions += 1) == 1 # the server ran it; a proxy drops the answer
        answer_insert(client, prepared)
        client.idle
      end
      open_native(server.url(query: "sslmode=disable&retry_attempts=3&retry_delay=0&prepared_statements=#{prepared}")) do |db|
        expect_raises(PG::ConnectionLost) { db.exec("INSERT INTO t VALUES (1)") }
        db.pool.stats.open_connections.should eq 0 # the dropped connection is not pooled again
      end
      executions.should eq 1
    end
  end

  it "runs the statement on another connection when the one lent was closed before anything was sent" do
    connections = executions = 0
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      next client.read_message if (connections += 1) == 1 # closed below while idle, never used
      read_insert(client, true)
      executions += 1
      answer_insert(client, true)
      client.idle
    end
    open_native(server.url(query: "sslmode=disable&retry_attempts=3&retry_delay=0")) do |db|
      idle = db.checkout.tap(&.release).as(PG::Connection)
      idle.session.hard_close # the pool lends it next, already closed
      db.exec("INSERT INTO t VALUES (1)").rows_affected.should eq 1
    end
    executions.should eq 1
  end

  {false, true}.each do |fatal|
    it "pings an idle connection the server closed#{" after a FATAL" if fatal} and runs the statement once on another" do
      connections = executions = 0
      server = FakePG.start do |client|
        client.read_startup
        client.ok_handshake
        if (connections += 1) == 1 # ended by the server while it sits idle in the pool
          client.error("57P01", "terminating connection due to administrator command", {'S' => "FATAL", 'V' => "FATAL"}) if fatal
          next
        end
        read_insert(client, true)
        executions += 1
        answer_insert(client, true)
        client.idle
      end
      open_native(server.url(query: "sslmode=disable&retry_attempts=3&retry_delay=0")) do |db|
        server.await # its socket is closed
        db.exec("INSERT INTO t VALUES (1)").rows_affected.should eq 1
      end
      executions.should eq 1
    end
  end
end

# Answers each simple query a connection sends and logs it (pings aside), until the client leaves.
private def log_queries(client : FakePG::Client, log : Array(String)) : Nil
  client.idle { |sql| log << sql unless sql.empty? }
end

private def terminate(client : FakePG::Client) : Nil
  client.error("57P01", "terminating connection due to administrator command", {'S' => "FATAL", 'V' => "FATAL"})
end

# The pool's first connection, opened up front, is ended by the server while it sits idle; the others log what they run.
private def server_ending_idle(log : Array(String), fatal : Bool) : FakePG
  connections = 0
  FakePG.start do |client|
    client.read_startup
    client.ok_handshake
    next log_queries(client, log) if (connections += 1) > 1
    terminate(client) if fatal
  end
end

# CQL's own statements check out through `DatabaseSource#using_connection`, not crystal-db's retrying `Database#exec`.
private def on_schema(server : FakePG, pool = "", &) : Nil
  open_native(server.url(query: "sslmode=disable&retry_attempts=3&retry_delay=0&prepared_statements=false#{pool}")) do |db|
    yield CQL::Schema.new(:statement_retry, server.url, CQL::Adapter::Postgres, source: CQL::DatabaseSource.new(db))
  end
end

describe CQL::DatabaseSource do
  {false, true}.each do |fatal|
    ended = fatal ? "after a FATAL" : "with a FIN"
    it "runs a schema statement once on another connection when the server ended the idle one #{ended}" do
      log = [] of String
      server = server_ending_idle(log, fatal)
      on_schema(server) do |schema|
        server.await # its socket is closed
        schema.exec("INSERT INTO t VALUES (1)")
      end
      log.should eq ["INSERT INTO t VALUES (1)"]
    end

    it "runs a schema transaction once on another connection when the server ended the idle one #{ended}" do
      log = [] of String
      server = server_ending_idle(log, fatal)
      on_schema(server) do |schema|
        server.await
        schema.transaction { schema.exec("INSERT INTO t VALUES (1)") }
      end
      log.should eq ["BEGIN", "INSERT INTO t VALUES (1)", "COMMIT"]
    end
  end

  it "stops after the idle connections and one new one when the server ends every connection it opens" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      terminate(client)
    end
    on_schema(server, "&initial_pool_size=3&max_idle_pool_size=3") do |schema|
      3.times { server.await }
      expect_raises(DB::ConnectionLost) { schema.exec("INSERT INTO t VALUES (1)") }
      server.accepted.should eq 4
      stats = schema.pool_stats
      {stats.open, stats.idle, stats.in_flight}.should eq({0, 0, 0})
    end
  end

  it "raises through the schema instead of running an INSERT again when its reply is cut" do
    log = [] of String
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      log << String.new(client.expect('Q')).chomp('\0') # the server ran it; a proxy drops the answer
    end
    on_schema(server) do |schema|
      expect_raises(PG::ConnectionLost) { schema.exec("INSERT INTO t VALUES (1)") }
    end
    log.should eq ["INSERT INTO t VALUES (1)"]
  end

  it "never runs a block's earlier statements again when a later one finds the connection closed" do
    log = [] of String
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      log_queries(client, log)
    end
    on_schema(server) do |schema|
      expect_raises(DB::ConnectionLost) do
        schema.with_connection do |connection|
          connection.exec("INSERT INTO t VALUES (1)")
          connection.as(PG::Connection).session.hard_close # dropped after the INSERT ran (a timeout the block rescued, say)
          connection.exec("INSERT INTO t VALUES (2)")
        end
      end
    end
    log.should eq ["INSERT INTO t VALUES (1)"]
  end
end
