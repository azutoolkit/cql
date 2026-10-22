require "pg"
require "../spec_helper"
require "../support/fake_pg_server"
require "../../src/postgres"

private alias PG = CQL::Postgres

Spec.after_each { CQL::Telemetry.reset! }

# A Postgres-flavoured schema that never connects (no pooled connection is opened).
private PgSchema = CQL::Schema.define(:wire_engine_spec, "postgres://localhost:1/none?initial_pool_size=0", CQL::Adapter::Postgres) do
  table :accounts do
    primary :id, Int64
    text :name
    bigint :balance, null: true
  end
end

private class WireAccount
  include CQL::ActiveRecord::Model(Int64)

  db_context schema: PgSchema, table: :accounts

  property name : String
  property balance : Int64? = nil

  def initialize(@name : String)
  end
end

private def be_int64(value : Int64) : Bytes
  Bytes.new(8).tap { |bytes| IO::ByteFormat::NetworkEndian.encode(value, bytes) }
end

private def account_columns
  [{"id", 20_u32}, {"name", 25_u32}, {"balance", 20_u32}]
end

private def account_row(id : Int64, name : String, balance : Int64?) : Array(Bytes?)
  [be_int64(id), name.to_slice, balance.try { |value| be_int64(value) }] of Bytes?
end

private def bind_values(payload : Bytes) : Array(String?)
  reader = PG::Wire::Reader.new(payload)
  reader.cstring; reader.cstring
  Array.new(reader.uint16.to_i) { reader.int16 }
  Array.new(reader.uint16.to_i) do
    length = reader.int32
    length < 0 ? nil : String.new(reader.bytes(length))
  end
end

private def engine_for(server : FakePG, query = "") : PG::AsyncEngine
  PG::AsyncEngine.new(PG::Pool.new(PG::Config.parse(server.url(query: "sslmode=disable#{query}"))))
end

# Serves one connection that answers each extended-protocol statement with the given rows.
# *runs* executions of the same statement: it is prepared once, then only bound.
private def serving_accounts(rows : Array(Array(Bytes?)), runs = 1, params = 0, columns = account_columns, on_bind : (Array(String?) ->)? = nil, &on_parse : String ->) : FakePG
  FakePG.start do |client|
    client.read_startup
    client.ok_handshake
    runs.times do |run|
      if run == 0
        on_parse.call(client.cstrings(client.expect('P'))[1])
        client.expect('D'); client.expect('S')
        client.send('1'); client.parameter_description(Array.new(params) { 25_u32 }); client.row_description(columns); client.ready
      end
      values = bind_values(client.expect('B'))
      on_bind.try(&.call(values))
      client.expect('E'); client.expect('S')
      client.send('2'); rows.each { |row| client.data_row(row) }; client.command_complete("SELECT #{rows.size}"); client.ready
    end
  end
end

# A server that answers every simple query with OK, reporting the transaction state.
private def recording_simple_server
  log = [] of String
  server = FakePG.start do |client|
    client.read_startup
    client.ok_handshake
    loop do
      message = client.read_message || break
      case message[0]
      when 'Q'
        log << String.new(message[1]).chomp('\0')
        client.command_complete("OK")
        client.ready(log.last == "BEGIN" || log.last.starts_with?("SET") || log.last.includes?("SAVEPOINT") || log.last.starts_with?("ROLLBACK TO") ? 'T' : 'I')
      when 'X' then break
      else          raise "unexpected message #{message[0]}"
      end
    end
  end
  {server: server, log: log}
end

describe CQL::Postgres::AsyncEngine do
  it "is an Executor reporting the PostgreSQL adapter, or CockroachDB when asked" do
    engine = engine_for(FakePG.start { |_| })
    engine.should be_a CQL::Executor
    engine.adapter.should eq CQL::Adapter::Postgres
    PG::AsyncEngine.new(engine.pool, CQL::Adapter::CockroachDB).adapter.should eq CQL::Adapter::CockroachDB
    expect_raises(ArgumentError, /MySql/) { PG::AsyncEngine.new(engine.pool, CQL::Adapter::MySql) }
  end

  it "runs the Query DSL with bound parameters and maps rows into a tuple" do
    parsed = nil
    bound = nil
    server = serving_accounts([account_row(7_i64, "ada", 100_i64)], params: 1, on_bind: ->(values : Array(String?)) { bound = values }) { |sql| parsed = sql }
    engine = engine_for(server)
    rows = PgSchema.query.from(:accounts).select(:id, :name, :balance).where(name: "ada'; DROP TABLE accounts; --").using(engine).all(as: {Int64, String, Int64?})
    rows.should eq [{7_i64, "ada", 100_i64}]
    parsed.should eq "SELECT accounts.id, accounts.name, accounts.balance FROM accounts WHERE accounts.name = $1"
    bound.should eq ["ada'; DROP TABLE accounts; --"]
  end

  it "hydrates ActiveRecord models without any extra mapping code" do
    server = serving_accounts([account_row(1_i64, "ada", 50_i64), account_row(2_i64, "bob", nil)]) { |_| }
    accounts = WireAccount.query.using(engine_for(server)).to_a
    accounts.map(&.name).should eq ["ada", "bob"]
    accounts.map(&.balance).should eq [50_i64, nil]
    accounts.map(&.id).should eq [1_i64, 2_i64]
  end

  it "returns the first row or nil with get" do
    server = serving_accounts([["ada".to_slice] of Bytes?], columns: [{"name", 25_u32}]) { |_| }
    PgSchema.query.from(:accounts).select(:name).using(engine_for(server)).get(as: String).should eq "ada"
  end

  it "reports every statement to telemetry, without parameter values unless asked" do
    events = [] of CQL::Telemetry::QueryEvent
    CQL::Telemetry.subscribe("wire") { |event| events << event }
    server = serving_accounts([["ada".to_slice] of Bytes?], runs: 2, params: 1, columns: [{"name", 25_u32}]) { |_| }
    engine = engine_for(server)
    query = PgSchema.query.from(:accounts).select(:name).where(name: "hunter2").using(engine)
    query.all(as: String)
    CQL::Telemetry.capture_params = true
    query.all(as: String)

    events.map(&.operation).should eq [:select, :select]
    events.each(&.adapter.should(eq(CQL::Adapter::Postgres)))
    events[0].params.should be_nil
    events[0].sql.should_not contain "hunter2"
    events[0].param_count.should eq 1
    events[1].params.should eq ["hunter2"]
  end

  it "reports a failing statement to telemetry with the typed error and no parameter values" do
    events = [] of CQL::Telemetry::QueryEvent
    CQL::Telemetry.subscribe("wire") { |event| events << event }
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.serve_prepare([20_u32], [] of {String, UInt32})
      client.expect('B'); client.expect('E'); client.expect('S')
      client.send('2')
      client.error("23505", "duplicate key value violates unique constraint \"accounts_name_key\"", {'D' => "Key (name)=(hunter2) already exists."})
      client.ready
    end
    engine = engine_for(server)
    expect_raises(PG::UniqueViolation) { PgSchema.insert.into(:accounts).values(name: "hunter2").using(engine).commit }
    events.size.should eq 1
    events[0].error.should be_a PG::UniqueViolation
    events[0].error.not_nil!.message.to_s.should_not contain "hunter2"
    events[0].operation.should eq :insert
  end

  it "runs a transaction on one connection: BEGIN, the statements, COMMIT" do
    statements = [] of String
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      loop do
        message = client.read_message || break
        case message[0]
        when 'Q'
          statements << String.new(message[1]).chomp('\0')
          client.command_complete("OK")
          client.ready(statements.last == "BEGIN" ? 'T' : 'I')
        when 'X' then break
        else          raise "unexpected message #{message[0]}"
        end
      end
    end
    engine = engine_for(server)
    engine.transaction do |tx|
      tx.exec_query(&.unprepared.exec("SELECT 1"))
      tx.exec_query(&.unprepared.exec("SELECT 2"))
    end
    statements.should eq ["BEGIN", "SELECT 1", "SELECT 2", "COMMIT"]
    server.accepted.should eq 1
  end

  it "rolls back when the block raises and leaves the engine usable" do
    statements = [] of String
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      loop do
        message = client.read_message || break
        case message[0]
        when 'Q'
          statements << String.new(message[1]).chomp('\0')
          client.command_complete("OK")
          client.ready(statements.last == "BEGIN" ? 'T' : 'I')
        when 'X' then break
        else          raise "unexpected message #{message[0]}"
        end
      end
    end
    engine = engine_for(server)
    expect_raises(Exception, "abort") { engine.transaction { |_| raise "abort" } }
    statements.should eq ["BEGIN", "ROLLBACK"]
    engine.pool.stats.idle.should eq 1
    engine.transaction { |_| 1 }.should eq 1
    statements.should eq ["BEGIN", "ROLLBACK", "BEGIN", "COMMIT"]
  end

  it "rolls back silently on DB::Rollback and returns nil" do
    statements = [] of String
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      loop do
        message = client.read_message || break
        case message[0]
        when 'Q'
          statements << String.new(message[1]).chomp('\0')
          client.command_complete("OK")
          client.ready(statements.last == "BEGIN" ? 'T' : 'I')
        when 'X' then break
        else          raise "unexpected message #{message[0]}"
        end
      end
    end
    engine_for(server).transaction { |_| raise DB::Rollback.new }.should be_nil
    statements.should eq ["BEGIN", "ROLLBACK"]
  end

  it "starts a transaction with the requested isolation, access mode and commit durability" do
    statements = recording_simple_server
    engine = engine_for(statements[:server])
    engine.transaction(isolation: :serializable, read_only: true, deferrable: true, synchronous_commit: false) { |_| }
    engine.transaction(isolation: :repeatable_read) { |_| }
    engine.transaction(synchronous_commit: true) { |_| }
    engine.transaction { |_| }
    statements[:log].should eq [
      "BEGIN", "SET TRANSACTION ISOLATION LEVEL SERIALIZABLE, READ ONLY, DEFERRABLE", "SET LOCAL synchronous_commit TO off", "COMMIT",
      "BEGIN", "SET TRANSACTION ISOLATION LEVEL REPEATABLE READ", "COMMIT",
      "BEGIN", "SET LOCAL synchronous_commit TO on", "COMMIT",
      "BEGIN", "COMMIT",
    ]
  end

  it "refuses deferrable transactions on CockroachDB" do
    engine = PG::AsyncEngine.new(PG::Pool.new(PG::Config.parse("postgres://h/db")), CQL::Adapter::CockroachDB)
    expect_raises(ArgumentError, /CockroachDB/) { engine.transaction(deferrable: true) { |_| } }
  end

  it "nests savepoints: a failing block rolls back to its savepoint, the outer transaction goes on" do
    statements = recording_simple_server
    engine = engine_for(statements[:server])
    engine.transaction do |tx|
      expect_raises(Exception, "inner") { tx.savepoint { |_| raise "inner" } }
      tx.savepoint { |_| 1 }.should eq 1
      tx.savepoint { |outer| outer.savepoint { |_| 2 } }.should eq 2
      tx.savepoint { |_| raise DB::Rollback.new }.should be_nil
    end
    log = statements[:log]
    log.first.should eq "BEGIN"
    log.last.should eq "COMMIT"
    verbs = log[1..-2].map { |sql| sql.starts_with?("SAVEPOINT") ? "SAVEPOINT" : sql.split(' ').first(2).join(' ') }
    verbs.should eq ["SAVEPOINT", "ROLLBACK TO", "SAVEPOINT", "RELEASE SAVEPOINT", "SAVEPOINT", "SAVEPOINT", "RELEASE SAVEPOINT", "RELEASE SAVEPOINT", "SAVEPOINT", "ROLLBACK TO"]
    log[2].should eq log[1].sub("SAVEPOINT", "ROLLBACK TO")
  end

  it "pins statements to the transaction connection when they run `using(tx)`" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      loop do
        message = client.read_message || break
        case message[0]
        when 'Q'
          client.command_complete("OK")
          client.ready(String.new(message[1]).starts_with?("BEGIN") ? 'T' : 'I')
        when 'P'
          client.expect('D'); client.expect('S')
          client.send('1'); client.parameter_description([] of UInt32); client.row_description([{"name", 25_u32}]); client.ready
          client.expect('B'); client.expect('E'); client.expect('S')
          client.send('2'); client.data_row(["ada".to_slice] of Bytes?); client.command_complete("SELECT 1"); client.ready
        when 'X' then break
        else          raise "unexpected message #{message[0]}"
        end
      end
    end
    engine = engine_for(server, "&pool_size=2")
    names = engine.transaction { |tx| PgSchema.query.from(:accounts).select(:name).using(tx).all(as: String) }
    names.should eq ["ada"]
    server.accepted.should eq 1
  end

  it "serves many fibers over a bounded pool" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      loop do
        message = client.read_message || break
        case message[0]
        when 'P'
          client.expect('D'); client.expect('S')
          client.send('1'); client.parameter_description([] of UInt32); client.row_description([{"n", 23_u32}]); client.ready
        when 'B'
          client.expect('E'); client.expect('S')
          sleep 5.milliseconds
          client.send('2'); client.data_row([Bytes[0, 0, 0, 1]] of Bytes?); client.command_complete("SELECT 1"); client.ready
        when 'X' then break
        else          raise "unexpected message #{message[0]}"
        end
      end
    end
    engine = engine_for(server, "&pool_size=3&checkout_timeout=5")
    results = Channel(Int32).new
    30.times do
      spawn { results.send(PgSchema.query.from(:accounts).select(:id).using(engine).get!(as: Int32)) }
    end
    Array.new(30) { results.receive }.sum.should eq 30
    server.max_open.should be <= 3
  end

  it "pipelines CQL queries in one round trip, observes each, and hydrates the results" do
    events = [] of CQL::Telemetry::QueryEvent
    CQL::Telemetry.subscribe("wire") { |event| events << event }
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      2.times { client.expect('P'); client.expect('D'); client.expect('S') }
      client.send('1'); client.parameter_description([20_u32]); client.row_description([{"name", 25_u32}]); client.ready
      client.send('1'); client.parameter_description([] of UInt32); client.row_description(account_columns); client.ready
      6.times { client.read_message } # both executions are written before any reply
      client.send('2'); client.data_row(["ada".to_slice] of Bytes?); client.command_complete("SELECT 1"); client.ready
      client.send('2'); account_row(2_i64, "bob", 7_i64).tap { |row| client.data_row(row) }; client.command_complete("SELECT 1"); client.ready
    end
    engine = engine_for(server)
    results = engine.pipeline([
      PgSchema.query.from(:accounts).select(:name).where(id: 1),
      PgSchema.query.from(:accounts).select(:id, :name, :balance),
    ])
    results[0].as(PG::PipelineResult).all(as: String).should eq ["ada"]
    accounts = results[1].as(PG::PipelineResult).all(as: WireAccount)
    {accounts.first.name, accounts.first.balance}.should eq({"bob", 7_i64})
    results[1].as(PG::PipelineResult).all(as: {Int64, String, Int64?}).should eq [{2_i64, "bob", 7_i64}]
    results[0].as(PG::PipelineResult).get(as: String).should eq "ada"
    events.map(&.operation).should eq [:select, :select]
    events.map(&.param_count).should eq [1, 0]
    server.accepted.should eq 1
    engine.pool.stats.in_use.should eq 0
  end

  it "reports a failing pipelined statement as its own error and to telemetry, leaving the others intact" do
    events = [] of CQL::Telemetry::QueryEvent
    CQL::Telemetry.subscribe("wire") { |event| events << event }
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      2.times { client.expect('P'); client.expect('D'); client.expect('S') }
      2.times do
        client.send('1'); client.parameter_description([] of UInt32); client.row_description([{"name", 25_u32}]); client.ready
      end
      6.times { client.read_message }
      client.send('2'); client.error("22012", "division by zero"); client.ready
      client.send('2'); client.data_row(["ok".to_slice] of Bytes?); client.command_complete("SELECT 1"); client.ready
    end
    results = engine_for(server).pipeline([{"SELECT 1/0", [] of ::DB::Any}, {"SELECT 'ok'", [] of ::DB::Any}])
    results[0].should be_a PG::ServerError
    results[1].as(PG::PipelineResult).all(as: String).should eq ["ok"]
    events.map(&.error.class).should eq [PG::ServerError, Nil]
  end

  it "runs a script of several statements through exec when there are no arguments" do
    statements = [] of String
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      message = client.read_message.not_nil!
      statements << String.new(message[1]).chomp('\0')
      client.command_complete("OK")
      client.ready
    end
    engine_for(server).exec("CREATE TABLE a (x int); CREATE TABLE b (x int)")
    statements.should eq ["CREATE TABLE a (x int); CREATE TABLE b (x int)"]
  end

  it "reports each pipelined statement to telemetry with its own operation" do
    events = [] of CQL::Telemetry::QueryEvent
    CQL::Telemetry.subscribe("wire") { |event| events << event }
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      2.times { client.expect('P'); client.expect('D'); client.expect('S') }
      2.times do
        client.send('1'); client.parameter_description([] of UInt32); client.send('n'); client.ready
      end
      6.times { client.read_message }
      client.send('2'); client.command_complete("INSERT 0 1"); client.ready
      client.send('2'); client.command_complete("DELETE 1"); client.ready
    end
    engine_for(server).pipeline([{"INSERT INTO t DEFAULT VALUES", [] of ::DB::Any}, {"  delete from t", [] of ::DB::Any}])
    events.map(&.operation).should eq [:insert, :delete]
  end

  it "returns nothing, without borrowing a connection, for an empty pipeline" do
    engine = engine_for(FakePG.start { |_| })
    engine.pipeline([] of {String, Array(::DB::Any)}).should be_empty
    engine.pool.stats.idle.should eq 0
  end

  it "runs raw SQL through telemetry with exec" do
    events = [] of CQL::Telemetry::QueryEvent
    CQL::Telemetry.subscribe("wire") { |event| events << event }
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('Q')
      client.command_complete("CREATE TABLE")
      client.ready
    end
    engine_for(server).exec("CREATE TABLE t (id int)")
    events.map(&.operation).should eq [:ddl]
    events.first.sql.should eq "CREATE TABLE t (id int)"
  end

  it "closes its pool" do
    engine = engine_for(FakePG.start { |_| })
    engine.close
    engine.pool.closed?.should be_true
  end
end
