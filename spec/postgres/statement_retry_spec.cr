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
