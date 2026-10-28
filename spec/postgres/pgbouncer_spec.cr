require "../spec_helper"
require "../../src/postgres"

# Runs against real PgBouncer instances in front of one PostgreSQL server; `script/pgbouncer-matrix start`
# starts them and prints the environment. Each is pending when its variable is missing:
#   CQL_PGB_TX          transaction pooling, max_prepared_statements = 0, default_pool_size = 1
#   CQL_PGB_TX_PS       transaction pooling, max_prepared_statements = 100, default_pool_size = 1
#   CQL_PGB_SESSION     session pooling, default_pool_size = 3
#   CQL_PGB_TX_MULTI    transaction pooling, max_prepared_statements = 0, default_pool_size = 3
# (each a port on 127.0.0.1; the role cql_scram authenticates with SCRAM through PgBouncer, password: secret)
private alias PG = CQL::Postgres

private def pooler_url(variable : String, extra = "") : String?
  ENV[variable]?.try { |port| "postgres://cql_scram:secret@127.0.0.1:#{port}/postgres?sslmode=disable#{extra}" }
end

private def pooler_session(variable : String, extra = "") : PG::Session
  url = pooler_url(variable, extra)
  raise "required PgBouncer fixture missing: #{variable}" if !url && ENV["CQL_PGB_REQUIRED"]? == "1"
  pending! "set #{variable} (see script/pgbouncer-matrix)" unless url
  PG::Session.connect(PG::Config.parse(url))
end

private def plus_one(session : PG::Session) : Int32
  session.query("SELECT $1::int + 1", [PG::Types::ParamEncoder.encode(1)]).rows.first.first.as(Int32)
end

describe "PgBouncer" do
  describe "transaction pooling without prepared-statement support" do
    it "ends up on protocol 3.0 (1.22 rejects the 3.2 startup, newer versions negotiate down)" do
      session = pooler_session("CQL_PGB_TX", "&statement_cache_size=0")
      begin
        session.protocol_version.should eq PG::ProtocolVersion::V3_0
        plus_one(session).should eq 2
      ensure
        session.close
      end
    end

    it "makes clients that share a server connection collide on cached statement names (SQLSTATE 42P05)" do
      first = pooler_session("CQL_PGB_TX")
      second = pooler_session("CQL_PGB_TX")
      begin
        error = expect_raises(PG::ServerError) do
          plus_one(first) # may already collide with a statement an earlier client left on the server connection
          plus_one(second)
        end
        error.sqlstate.should eq "42P05"
        error.message.to_s.should contain "statement_cache_size=0"
      ensure
        first.close
        second.close
      end
    end

    it "works with statement_cache_size=0, which sends the unnamed statement" do
      first = pooler_session("CQL_PGB_TX", "&statement_cache_size=0")
      second = pooler_session("CQL_PGB_TX", "&statement_cache_size=0")
      begin
        [first, second, first, second].map { |session| plus_one(session) }.should eq [2, 2, 2, 2]
      ensure
        first.close
        second.close
      end
    end

    it "keeps SET LOCAL inside its transaction and starts the next one clean" do
      session = pooler_session("CQL_PGB_TX", "&statement_cache_size=0")
      begin
        session.simple_query("BEGIN; SET LOCAL statement_timeout = 1234")
        session.query("SHOW statement_timeout").rows.should eq [["1234ms"]]
        session.simple_query("COMMIT")
        session.query("SHOW statement_timeout").rows.should eq [["0"]]
      ensure
        session.close
      end
    end
  end

  describe "transaction pooling over several server connections without prepared-statement support" do
    it "runs unnamed statements, streams included, from many clients at once" do
      pending! "set CQL_PGB_TX_MULTI (see script/pgbouncer-matrix)" unless ENV["CQL_PGB_TX_MULTI"]?
      done = Channel(Exception?).new
      8.times do
        spawn do
          session = pooler_session("CQL_PGB_TX_MULTI", "&statement_cache_size=0")
          begin
            10.times { plus_one(session).should eq 2 }
            session.stream("SELECT g::int4 FROM generate_series(1, 500) g", fetch_size: 50, &.to_a).size.should eq 500
            done.send(nil)
          ensure
            session.close
          end
        rescue ex
          done.send(ex)
        end
      end
      failures = Array.new(8) { done.receive }.compact
      failures.should be_empty
    end
  end

  describe "transaction pooling with max_prepared_statements" do
    it "shares one server connection between clients that cache the same statement" do
      first = pooler_session("CQL_PGB_TX_PS")
      second = pooler_session("CQL_PGB_TX_PS")
      begin
        [first, second, first, second].map { |session| plus_one(session) }.should eq [2, 2, 2, 2]
      ensure
        first.close
        second.close
      end
    end

    it "pipelines, and cancels through the pooler with the key the pooler handed out" do
      session = pooler_session("CQL_PGB_TX_PS")
      begin
        session.secret_key.size.should eq 4
        results = session.pipeline((1..5).map { |number| {"SELECT $1::int", [PG::Types::ParamEncoder.encode(number)] of PG::Types::Param} })
        results.size.should eq 5
        expect_raises(PG::QueryTimeout) { session.query("SELECT pg_sleep(10)", timeout: 300.milliseconds) }
        plus_one(session).should eq 2
      ensure
        session.close
      end
    end

    it "streams through a portal, which pins the pooler's server connection until the stream ends" do
      streaming = pooler_session("CQL_PGB_TX_PS")
      other = pooler_session("CQL_PGB_TX_PS")
      answered = Channel(Int32).new(1)
      begin
        count = streaming.stream("SELECT g::int4 FROM generate_series(1, 3000) g", fetch_size: 100) do |rows|
          rows.first(150).to_a # two fetches: the portal is suspended between them
          spawn { answered.send(plus_one(other)) }
          sleep 300.milliseconds
          select
          when answered.receive then fail "another client ran on the single server connection mid-stream"
          else
          end
          rows.to_a.size
        end
        count.should eq 2850
        select
        when value = answered.receive then value.should eq 2
        when timeout(5.seconds) then fail "the waiting client was never served after the stream ended"
        end
      ensure
        streaming.close
        other.close
      end
    end

    it "rolls back a transaction a pooled engine connection leaves open" do
      url = pooler_url("CQL_PGB_TX_PS", "&pool_size=1")
      pending! "set CQL_PGB_TX_PS (see script/pgbouncer-matrix)" unless url
      engine = PG::AsyncEngine.connect(url)
      engine.with_connection(&.exec_all("BEGIN; SET LOCAL statement_timeout = 99"))
      engine.with_connection do |connection|
        connection.session.in_transaction?.should be_false
        connection.scalar("SHOW statement_timeout").should eq "0"
      end
      engine.close
    end
  end

  describe "session pooling" do
    it "behaves like a direct connection, session state included" do
      session = pooler_session("CQL_PGB_SESSION")
      begin
        session.protocol_version.should eq PG::ProtocolVersion::V3_0
        plus_one(session).should eq 2
        session.simple_query("SET application_name = 'cql_pgb'")
        session.query("SHOW application_name").rows.should eq [["cql_pgb"]]
      ensure
        session.close
      end
    end
  end
end
