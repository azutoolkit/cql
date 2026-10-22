require "pg"
require "../spec_helper"
require "../../src/postgres"

# Specs against a real PostgreSQL server: they run when `DATABASE_URL` (default
# postgres://localhost/cql_test) accepts this driver's connection and are
# pending otherwise. Tables are prefixed per process and dropped afterwards.

private alias PG = CQL::Postgres
private alias Enc = CQL::Postgres::Types::ParamEncoder

private LIVE_URL = postgres_database_url

private module LiveServer
  @@reachable : Bool? = nil

  def self.reachable? : Bool
    cached = @@reachable
    return cached unless cached.nil?
    @@reachable = begin
      PG::Session.connect(PG::Config.parse(LIVE_URL)).close
      true
    rescue
      false
    end
  end
end

private def live_postgres? : Bool
  LiveServer.reachable?
end

private def require_live! : Nil
  pending! "needs a PostgreSQL server reachable through DATABASE_URL" unless live_postgres?
end

private def live_session : PG::Session
  PG::Session.connect(PG::Config.parse(LIVE_URL))
end

private TABLE = "cql_wire_live_#{Process.pid}"

private LiveSchema = CQL::Schema.define(:wire_live, "postgres://localhost:1/none?initial_pool_size=0", CQL::Adapter::Postgres) do
  table :cql_wire_live_accounts do
    primary :id, Int64, auto_increment: true
    text :name
    bigint :balance, null: true
  end
end

private class LiveAccount
  include CQL::ActiveRecord::Model(Int64)

  db_context schema: LiveSchema, table: :cql_wire_live_accounts

  property name : String
  property balance : Int64? = nil

  def initialize(@name : String, @balance : Int64? = nil)
  end
end

describe "CQL::Postgres against a live server" do
  before_each do
    next unless live_postgres?
    session = live_session
    session.simple_query("DROP TABLE IF EXISTS #{TABLE}; CREATE TABLE #{TABLE} (id bigserial primary key, name text unique not null, qty int, price numeric(10,2), meta jsonb, at timestamptz default now())")
    session.simple_query("DROP TABLE IF EXISTS cql_wire_live_accounts; CREATE TABLE cql_wire_live_accounts (id bigserial primary key, name text not null, balance bigint)")
    session.close
  end

  after_each do
    next unless live_postgres?
    session = live_session
    session.simple_query("DROP TABLE IF EXISTS #{TABLE}; DROP TABLE IF EXISTS cql_wire_live_accounts")
    session.close
  end

  it "authenticates and reports the server" do
    require_live!
    session = live_session
    session.server_parameters["server_version"].should_not be_empty
    session.server_parameters["client_encoding"].should eq "UTF8"
    session.process_id.should be > 0
    session.close
  end

  it "negotiates the newest protocol the server supports, and cancels with that version's key" do
    require_live!
    session = live_session
    server_major = session.server_parameters["server_version"].split('.').first.to_i
    expected = server_major >= 18 ? PG::ProtocolVersion::V3_2 : PG::ProtocolVersion::V3_0
    session.protocol_version.should eq expected
    session.secret_key.size.should be >= 4
    expect_raises(PG::QueryTimeout) { session.query("SELECT pg_sleep(10)", timeout: 200.milliseconds) }
    session.query("SELECT 1").rows.should eq [[1]]
    session.close

    pinned = PG::Session.connect(PG::Config.parse("#{LIVE_URL}#{LIVE_URL.includes?('?') ? '&' : '?'}max_protocol_version=3.0"))
    pinned.protocol_version.should eq PG::ProtocolVersion::V3_0
    pinned.secret_key.size.should eq 4
    pinned.close
  end

  it "round-trips every supported type through bound parameters and binary results" do
    require_live!
    session = live_session
    now = Time.utc(2024, 3, 5, 6, 7, 8, nanosecond: 123_456_000)
    uuid = UUID.random
    row = session.query(
      "SELECT $1::int2, $2::int4, $3::int8, $4::float4, $5::float8, $6::bool, $7::text, $8::bytea, $9::uuid, $10::timestamptz, $11::date, $12::jsonb, $13::numeric, $14::int4, $15::time",
      [Enc.encode(-2_i16), Enc.encode(70_000), Enc.encode(5_000_000_000_i64), Enc.encode(1.5_f32), Enc.encode(2.25), Enc.encode(true),
       Enc.encode("héllo ✓"), Enc.encode(Bytes[0, 1, 255]), Enc.encode(uuid), Enc.encode(now), Enc.encode(Time.utc(2024, 3, 5)),
       Enc.encode(JSON.parse(%({"a":[1,2]}))), Enc.encode(CQL::Postgres::Types::DecimalText.new("12.50")), Enc.encode(nil), Enc.encode("04:05:06.5")]
    ).rows.first
    row[0].should eq -2_i16
    row[1].should eq 70_000
    row[2].should eq 5_000_000_000_i64
    row[3].should eq 1.5_f32
    row[4].should eq 2.25
    row[5].should eq true
    row[6].should eq "héllo ✓"
    row[7].should eq Bytes[0, 1, 255]
    row[8].should eq uuid
    row[9].should eq now
    row[10].should eq Time.utc(2024, 3, 5)
    row[11].as(JSON::Any)["a"][1].as_i.should eq 2
    row[12].to_s.should eq "12.50"
    row[13].should be_nil
    row[14].should eq Time::Span.new(hours: 4, minutes: 5, seconds: 6, nanoseconds: 500_000_000)
    session.close
  end

  it "decodes timestamps before 2000 and dates far from the epoch" do
    require_live!
    session = live_session
    session.query("SELECT '1969-07-20 20:17:40.5+00'::timestamptz, '0044-03-15'::date + 0, '9999-12-31'::date").rows.first.should eq(
      [Time.utc(1969, 7, 20, 20, 17, 40, nanosecond: 500_000_000), Time.utc(44, 3, 15), Time.utc(9999, 12, 31)]
    )
    session.close
  end

  it "treats hostile text as data" do
    require_live!
    session = live_session
    evil = "x'); DROP TABLE #{TABLE}; --"
    session.query("INSERT INTO #{TABLE} (name) VALUES ($1)", [Enc.encode(evil)])
    session.query("SELECT name FROM #{TABLE}").rows.should eq [[evil]]
    session.close
  end

  it "maps server errors to typed exceptions and keeps the session usable" do
    require_live!
    session = live_session
    session.query("INSERT INTO #{TABLE} (name) VALUES ($1)", [Enc.encode("ada")])
    error = expect_raises(PG::UniqueViolation) { session.query("INSERT INTO #{TABLE} (name) VALUES ($1)", [Enc.encode("ada")]) }
    error.constraint.should eq "#{TABLE}_name_key"
    error.message.to_s.should_not contain "ada"
    expect_raises(PG::NotNullViolation) { session.query("INSERT INTO #{TABLE} (name) VALUES (NULL)") }
    expect_raises(PG::UndefinedTable) { session.query("SELECT * FROM #{TABLE}_missing") }
    expect_raises(PG::SyntaxOrAccessError) { session.query("SELEC 1") }
    expect_raises(PG::ServerError) { session.query("SELECT $1::int4", [Enc.encode("hunter2")]) }.message.to_s.should_not contain "hunter2"
    session.query("SELECT count(*) FROM #{TABLE}").rows.should eq [[1_i64]]
    session.close
  end

  it "reports the transaction state after each statement" do
    require_live!
    session = live_session
    session.transaction_status.should eq 'I'
    session.simple_query("BEGIN")
    session.transaction_status.should eq 'T'
    expect_raises(PG::ServerError) { session.query("SELECT 1/0") }
    session.transaction_status.should eq 'E'
    session.simple_query("ROLLBACK")
    session.transaction_status.should eq 'I'
    session.close
  end

  it "re-prepares a cached statement after the table's shape changed" do
    require_live!
    session = live_session
    session.query("SELECT * FROM #{TABLE} WHERE id = $1", [Enc.encode(1)]).columns.map(&.name).should_not contain "extra"
    session.simple_query("ALTER TABLE #{TABLE} ADD COLUMN extra int")
    session.query("SELECT * FROM #{TABLE} WHERE id = $1", [Enc.encode(1)]).columns.map(&.name).should contain "extra"
    session.close
  end

  it "pipelines statements and isolates a failing one" do
    require_live!
    session = live_session
    results = session.pipeline([
      {"SELECT $1::int + 1", [Enc.encode(1)]},
      {"SELECT 1/0", [] of PG::Types::Param},
      {"INSERT INTO #{TABLE} (name) VALUES ($1)", [Enc.encode("pipelined")]},
      {"SELECT count(*) FROM #{TABLE}", [] of PG::Types::Param},
    ])
    results[0].as(PG::Result).rows.should eq [[2]]
    results[1].should be_a PG::ServerError
    results[2].as(PG::Result).rows_affected.should eq 1
    results[3].as(PG::Result).rows.should eq [[1_i64]]
    session.close
  end

  it "pipelines far more statements than fit in the socket buffers without deadlocking" do
    require_live!
    session = live_session
    statements = Array.new(150_000) { {"SELECT repeat($1, 500)", [Enc.encode("x")]} }
    results = session.pipeline(statements, timeout: 60.seconds)
    results.size.should eq 150_000
    results.all?(&.as(PG::Result).rows.first.first.to_s.size.==(500)).should be_true
    session.close
  end

  it "recovers from a failed pipelined statement or an unencodable one without losing sync" do
    require_live!
    session = live_session
    expect_raises(ArgumentError, /NUL/) { session.pipeline([{"SELECT 1", [] of PG::Types::Param}, {"SELECT 'a\0'", [] of PG::Types::Param}]) }
    expect_raises(PG::UnsupportedValue) { session.pipeline([{"SELECT 'infinity'::timestamptz", [] of PG::Types::Param}, {"SELECT 2", [] of PG::Types::Param}]) }
    session.query("SELECT 42").rows.should eq [[42]]
    expect_raises(PG::QueryCanceled) { session.query("COPY #{TABLE} FROM STDIN") }
    session.query("SELECT 43").rows.should eq [[43]]
    session.close
  end

  it "streams COPY in and out" do
    require_live!
    session = live_session
    session.copy_in("COPY #{TABLE} (name, qty) FROM STDIN") { |copy| copy << "a\t1\nb\t2\n" }.should eq 2
    chunks = String.build { |io| session.copy_out("COPY (SELECT name, qty FROM #{TABLE} ORDER BY name) TO STDOUT") { |chunk| io.write(chunk) } }
    chunks.should eq "a\t1\nb\t2\n"
    expect_raises(Exception, "stop") { session.copy_in("COPY #{TABLE} (name) FROM STDIN") { |copy| copy << "z\n"; raise "stop" } }
    session.query("SELECT count(*) FROM #{TABLE}").rows.should eq [[2_i64]]
    session.close
  end

  it "cancels a statement that outlives its timeout, then keeps working" do
    require_live!
    session = live_session
    started = Time.instant
    expect_raises(PG::QueryTimeout) { session.query("SELECT pg_sleep(10)", timeout: 200.milliseconds) }
    (Time.instant - started).should be < 3.seconds
    session.closed?.should be_false
    session.query("SELECT 1").rows.should eq [[1]]
    session.close
  end

  it "delivers NOTIFY and server notices to callbacks" do
    require_live!
    listener = live_session
    notifications = [] of String
    notices = [] of String
    listener.on_notification = ->(note : PG::Notification) { notifications << "#{note.channel}:#{note.payload}" }
    listener.on_notice = ->(fields : Hash(Char, String)) { notices << fields['C'] }
    listener.simple_query("LISTEN cql_wire_live")
    sender = live_session
    sender.simple_query("NOTIFY cql_wire_live, 'hello'")
    listener.simple_query("DROP TABLE IF EXISTS cql_wire_live_never")
    notifications.should eq ["cql_wire_live:hello"]
    notices.should eq ["00000"]
    listener.close
    sender.close
  end

  it "runs the CQL DSL and hydrates models through AsyncEngine" do
    require_live!
    engine = PG::AsyncEngine.connect(LIVE_URL)
    LiveSchema.insert.into(:cql_wire_live_accounts).values(name: "ada", balance: 100_i64).using(engine).commit
    LiveSchema.insert.into(:cql_wire_live_accounts).values(name: "bob").using(engine).commit

    LiveAccount.query.order_by(id: :asc).using(engine).to_a.map { |account| {account.name, account.balance} }.should eq [{"ada", 100_i64}, {"bob", nil}]
    LiveSchema.query.from(:cql_wire_live_accounts).select(:name).where(name: "ada").using(engine).all(as: String).should eq ["ada"]
    LiveSchema.update.table(:cql_wire_live_accounts).set(balance: 5_i64).where(name: "bob").using(engine).commit
    LiveSchema.query.from(:cql_wire_live_accounts).select(:balance).where(name: "bob").using(engine).get!(as: Int64).should eq 5_i64
    LiveSchema.delete.from(:cql_wire_live_accounts).where(name: "bob").using(engine).commit
    LiveAccount.query.using(engine).to_a.size.should eq 1
    engine.close
  end

  it "pipelines CQL queries through the engine, one round trip, with typed results" do
    require_live!
    engine = PG::AsyncEngine.connect(LIVE_URL)
    LiveSchema.insert.into(:cql_wire_live_accounts).values(name: "ada", balance: 100_i64).using(engine).commit
    LiveSchema.insert.into(:cql_wire_live_accounts).values(name: "bob").using(engine).commit
    events = [] of CQL::Telemetry::QueryEvent
    CQL::Telemetry.subscribe("live") { |event| events << event }
    begin
      results = engine.pipeline([
        LiveSchema.query.from(:cql_wire_live_accounts).select(:name).order(name: :asc),
        LiveSchema.query.from(:cql_wire_live_accounts).select(:id, :name, :balance).where(name: "ada"),
      ])
      failing = engine.pipeline([{"SELECT nope FROM cql_wire_live_accounts", [] of ::DB::Any}, {"SELECT 1", [] of ::DB::Any}])
    ensure
      CQL::Telemetry.reset!
    end
    results[0].as(PG::PipelineResult).all(as: String).should eq ["ada", "bob"]
    results[1].as(PG::PipelineResult).all(as: LiveAccount).map { |account| {account.name, account.balance} }.should eq [{"ada", 100_i64}]
    failing[0].should be_a PG::UndefinedColumn
    failing[1].as(PG::PipelineResult).all(as: Int32).should eq [1]
    events.map(&.error.class).should eq [Nil, Nil, PG::UndefinedColumn, Nil]
    engine.close
  end

  it "commits and rolls back transactions across the pool" do
    require_live!
    engine = PG::AsyncEngine.connect(LIVE_URL)
    engine.transaction do |tx|
      LiveSchema.insert.into(:cql_wire_live_accounts).values(name: "kept").using(tx).commit
    end
    expect_raises(Exception, "undo") do
      engine.transaction do |tx|
        LiveSchema.insert.into(:cql_wire_live_accounts).values(name: "undone").using(tx).commit
        raise "undo"
      end
    end
    LiveAccount.query.using(engine).to_a.map(&.name).should eq ["kept"]
    engine.close
  end

  it "applies isolation level, access mode and commit durability to one transaction only" do
    require_live!
    engine = PG::AsyncEngine.connect(LIVE_URL)
    engine.transaction(isolation: :serializable, synchronous_commit: false) do |tx|
      tx.exec_query(&.scalar("SHOW transaction_isolation")).should eq "serializable"
      tx.exec_query(&.scalar("SHOW synchronous_commit")).should eq "off"
    end
    engine.exec_query(&.scalar("SHOW synchronous_commit")).should eq "on"
    engine.exec_query(&.scalar("SHOW transaction_isolation")).should eq "read committed"
    denied = expect_raises(PG::ServerError) do
      engine.transaction(read_only: true) do |tx|
        LiveSchema.insert.into(:cql_wire_live_accounts).values(name: "denied").using(tx).commit
      end
    end
    denied.sqlstate.should eq "25006"
    engine.close
  end

  it "rolls back to a savepoint without ending the surrounding transaction" do
    require_live!
    engine = PG::AsyncEngine.connect(LIVE_URL)
    engine.transaction do |tx|
      LiveSchema.insert.into(:cql_wire_live_accounts).values(name: "outer").using(tx).commit
      tx.savepoint do |inner|
        LiveSchema.insert.into(:cql_wire_live_accounts).values(name: "inner").using(inner).commit
        raise DB::Rollback.new
      end
    end
    LiveAccount.query.using(engine).to_a.map(&.name).should eq ["outer"]
    engine.close
  end

  it "keeps a pool tidy: setup on new connections, rollback of leaked transactions, retirement after max_queries" do
    require_live!
    separator = LIVE_URL.includes?('?') ? '&' : '?'
    setup = ->(connection : PG::Connection) { connection.exec_all("SET application_name TO 'cql_pooled'") }
    engine = PG::AsyncEngine.connect("#{LIVE_URL}#{separator}pool_size=1&pool_min_size=1&max_queries=4", setup: setup)
    engine.pool.stats.idle.should eq 1
    backend = engine.with_connection do |connection|
      connection.exec_all("BEGIN")
      connection.exec_all("SET LOCAL statement_timeout = 1234")
      connection.session.process_id
    end
    engine.with_connection do |connection|
      connection.session.in_transaction?.should be_false
      connection.session.process_id.should eq backend
      connection.scalar("SHOW application_name").should eq "cql_pooled"
    end
    engine.with_connection(&.scalar("SELECT 1"))
    engine.with_connection { |connection| connection.session.process_id.should_not eq backend }
    engine.close
  end

  it "re-prepares cached statements after the pool's reset statement was DISCARD ALL" do
    require_live!
    separator = LIVE_URL.includes?('?') ? '&' : '?'
    engine = PG::AsyncEngine.connect("#{LIVE_URL}#{separator}pool_size=1", reset: "DISCARD ALL")
    3.times { |round| engine.exec_query(&.scalar("SELECT $1::int8 + 1", round.to_i64)).should eq round + 1 }
    engine.close
  end

  it "serves many fibers over a small pool" do
    require_live!
    engine = PG::AsyncEngine.connect("#{LIVE_URL}#{LIVE_URL.includes?('?') ? '&' : '?'}pool_size=4")
    done = Channel(Int64).new
    40.times do |index|
      spawn { done.send(engine.exec_query(&.query_one("SELECT pg_sleep(0.01), $1::int8", index.to_i64, as: {String, Int64}))[1]) }
    end
    40.times.sum { done.receive }.should eq (0...40).sum
    engine.pool.stats.in_use.should eq 0
    engine.close
  end
end
