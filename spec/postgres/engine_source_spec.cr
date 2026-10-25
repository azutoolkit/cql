require "../spec_helper"
require "../support/fake_pg_server"
require "../../src/postgres"

private alias PG = CQL::Postgres

Spec.after_each { CQL::Telemetry.reset! }

# A schema that runs on the given server through an EngineSource (the schema never opens a crystal-db pool).
private def schema_on(server : FakePG, query = "") : CQL::Schema
  url = server.url(query: "sslmode=disable#{query}")
  CQL::Schema.new(:engine_source_spec, url, CQL::Adapter::Postgres, source: PG::EngineSource.connect(url))
end

# Answers every simple query with OK and records it, reporting the transaction state.
private def recording_server(statements : Array(String)) : FakePG
  FakePG.start do |client|
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
end

private def run_simple(schema : CQL::Schema, sql : String) : Nil
  schema.with_connection(&.unprepared.exec(sql))
end

describe CQL::Postgres::EngineSource do
  it "lends the engine pool's connection to schema.with_connection and returns it" do
    statements = [] of String
    schema = schema_on(recording_server(statements))
    schema.source.should be_a PG::EngineSource
    run_simple(schema, "SELECT 1")
    run_simple(schema, "SELECT 2")
    statements.should eq ["SELECT 1", "SELECT 2"]
    schema.pool_stats.idle.should eq 1
    schema.pool_stats.in_flight.should eq 0
  end

  it "runs schema.transaction on one engine connection and pins statements to it" do
    statements = [] of String
    server = recording_server(statements)
    schema = schema_on(server)
    schema.transaction do |_tx|
      run_simple(schema, "SELECT 1")
      run_simple(schema, "SELECT 2")
    end
    statements.should eq ["BEGIN", "SELECT 1", "SELECT 2", "COMMIT"]
    server.accepted.should eq 1
  end

  it "rolls back when the block raises, and quietly on DB::Rollback" do
    statements = [] of String
    schema = schema_on(recording_server(statements))
    expect_raises(Exception, "abort") { schema.transaction { |_tx| raise "abort" } }
    schema.transaction { |_tx| raise DB::Rollback.new }
    statements.should eq ["BEGIN", "ROLLBACK", "BEGIN", "ROLLBACK"]
    schema.pool_stats.idle.should eq 1
  end

  it "still publishes transaction telemetry from the schema" do
    states = [] of CQL::Telemetry::TransactionState
    CQL::Telemetry.subscribe_transactions("engine_source_spec") { |event| states << event.state }
    schema = schema_on(recording_server([] of String))
    schema.transaction { |_tx| }
    expect_raises(Exception, "abort") { schema.transaction { |_tx| raise "abort" } }
    states.should eq [CQL::Telemetry::TransactionState::Begin, CQL::Telemetry::TransactionState::Commit,
                      CQL::Telemetry::TransactionState::Begin, CQL::Telemetry::TransactionState::Rollback]
  end

  it "reports the engine pool's occupancy as PoolStats" do
    schema = schema_on(recording_server([] of String), "&pool_size=4")
    schema.pool_stats.max.should eq 4
    schema.pool_stats.open.should eq 0
    schema.with_connection do |_|
      stats = schema.pool_stats
      {stats.open, stats.idle, stats.in_flight}.should eq({1, 0, 1})
    end
    schema.pool_stats.open.should eq 1
  end

  it "closes the pool: later statements fail with PoolClosed" do
    schema = schema_on(recording_server([] of String))
    run_simple(schema, "SELECT 1")
    schema.close
    expect_raises(PG::PoolClosed) { run_simple(schema, "SELECT 1") }
  end

  it "raises DB::ConnectionRefused when a connection cannot be opened (lazily, and on connect)" do
    url = "postgres://ada@127.0.0.1:1/app?sslmode=disable"
    schema = CQL::Schema.new(:engine_source_refused, url, CQL::Adapter::Postgres, source: PG::EngineSource.connect(url))
    expect_raises(DB::ConnectionRefused) { run_simple(schema, "SELECT 1") }.cause.should be_a IO::Error
    expect_raises(DB::ConnectionRefused) { PG::EngineSource.connect("#{url}&pool_min_size=1") }
  end

  it "refuses a source for another adapter" do
    source = PG::EngineSource.new(PG::AsyncEngine.new(PG::Pool.new(PG::Config.parse("postgres://ada@127.0.0.1:1/app"))))
    expect_raises(ArgumentError, /speaks Postgres, the schema uses SQLite/) do
      CQL::Schema.new(:engine_source_adapter, "sqlite3://./engine_source.db", CQL::Adapter::SQLite, source: source)
    end
  end

  it "closes twice without error" do
    schema = schema_on(recording_server([] of String))
    run_simple(schema, "SELECT 1")
    schema.close
    schema.close
  end

  it "returns the connection when the block raises, through with_connection and exec_query" do
    schema = schema_on(recording_server([] of String))
    expect_raises(Exception, "boom") { schema.with_connection { |_| raise "boom" } }
    expect_raises(Exception, "boom") { schema.exec_query { |_| raise "boom" } }
    stats = schema.pool_stats
    {stats.in_flight, stats.idle}.should eq({0, 1})
    run_simple(schema, "SELECT 1")
  end

  it "runs a transaction nested in a transaction as a SAVEPOINT on the same connection" do
    statements = [] of String
    server = recording_server(statements)
    schema = schema_on(server)
    schema.transaction { |_tx| schema.transaction { |_inner| } }
    server.accepted.should eq 1
    statements.first.should eq "BEGIN"
    statements[1].should start_with "SAVEPOINT "
    statements[2].should start_with "RELEASE SAVEPOINT "
    statements.last.should eq "COMMIT"
  end

  it "nests a transaction on a pool of one without waiting for a second connection" do
    server = recording_server([] of String)
    schema = schema_on(server, "&pool_size=1&checkout_timeout=0.1")
    schema.transaction { |_tx| schema.transaction { |_inner| } }
    server.accepted.should eq 1
  end

  it "accepts a source of the schema's own adapter: PostgreSQL, and CockroachDB" do
    pool = PG::Pool.new(PG::Config.parse("postgres://ada@127.0.0.1:1/app"))
    source = PG::EngineSource.new(PG::AsyncEngine.new(pool))
    CQL::Schema.new(:engine_source_pg, "postgres://ada@127.0.0.1:1/app", CQL::Adapter::Postgres, source: source).source.should be source

    cockroach = PG::EngineSource.new(PG::AsyncEngine.new(pool, CQL::Adapter::CockroachDB))
    CQL::Schema.new(:engine_source_crdb, "cockroachdb://ada@127.0.0.1:1/app", CQL::Adapter::CockroachDB, source: cockroach).source.should be cockroach
  end

  it "keeps the pool options out of Schema#uri, which SchemaDump opens through crystal-db, and the connection settings in" do
    url = "postgres://ada@127.0.0.1:1/app?%70ool_size=3&sslmode=disable&max_queries=10&application_name=my%20app&binary_params=true&max_protocol_version=3.0#frag"
    schema = CQL::Schema.new(:engine_source_uri, url, CQL::Adapter::Postgres, source: PG::EngineSource.connect(url))
    schema.uri.should eq "postgres://ada@127.0.0.1:1/app?sslmode=disable&application_name=my%20app&binary_params=true&max_protocol_version=3.0#frag"
  end

  it "leaves no trailing ? when the query held only pool options" do
    url = "postgres://ada@127.0.0.1:1/app?pool_size=3&max_queries=10"
    CQL::Schema.new(:engine_source_bare, url, CQL::Adapter::Postgres, source: PG::EngineSource.connect(url)).uri.should eq "postgres://ada@127.0.0.1:1/app"
  end

  it "translates a saturated pool to DB::PoolTimeout, keeping the cause" do
    schema = schema_on(recording_server([] of String), "&pool_size=1&checkout_timeout=0.1")
    schema.with_connection do |_|
      error = expect_raises(DB::PoolTimeout) { schema.source.using_connection { |_| } }
      error.cause.should be_a PG::PoolTimeout
    end
  end

  it "leaves TLS and server errors untranslated" do
    declines = FakePG.start do |client|
      client.read_startup
      client.io.write_byte('N'.ord.to_u8)
      client.io.flush
    end
    refused = CQL::Schema.new(:engine_source_tls, declines.url(query: "sslmode=require"), CQL::Adapter::Postgres,
      source: PG::EngineSource.connect(declines.url(query: "sslmode=require")))
    expect_raises(PG::TLSRefused) { run_simple(refused, "SELECT 1") }

    rejects = FakePG.start do |client|
      client.read_startup
      client.error("28P01", "password authentication failed")
    end
    rejected = schema_on(rejects)
    expect_raises(PG::InvalidAuthorization) { run_simple(rejected, "SELECT 1") }
  end
end

describe CQL::DatabaseSource do
  it "is the default source of a schema, unchanged for crystal-db drivers" do
    schema = CQL::Schema.new(:database_source_spec, spec_sqlite_uri("database_source_spec.db"), CQL::Adapter::SQLite)
    schema.source.should be_a CQL::DatabaseSource
    schema.with_connection { |connection| connection.scalar("SELECT 1").should eq 1 }
    schema.transaction { |tx| tx.connection.scalar("SELECT 2").should eq 2 }
    schema.close
  end
end
