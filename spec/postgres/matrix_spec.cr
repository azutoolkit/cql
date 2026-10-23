require "../spec_helper"
require "../../src/postgres"

# One harness, every server version. `script/pg-matrix start` brings up a server per major version and
# `script/pg-matrix run` points CQL_PG_MATRIX at them ("11=5511,12=5512,..."); without it every example is
# pending. The superuser `cql` trusts local connections; cql_scram, cql_md5 and cql_clear authenticate
# with the method their names say (password: secret).
private alias PG = CQL::Postgres

private record Target, major : Int32, port : Int32 do
  def url(user : String = "cql", password : String? = nil) : String
    "postgres://#{user}#{password.try { |secret| ":#{secret}" }}@127.0.0.1:#{port}/postgres?sslmode=disable"
  end

  def session(user : String = "cql", password : String? = nil, extra = "") : PG::Session
    PG::Session.connect(PG::Config.parse(url(user, password) + extra))
  end

  def newest_protocol : PG::ProtocolVersion
    major >= 18 ? PG::ProtocolVersion::V3_2 : PG::ProtocolVersion::V3_0
  end
end

private TARGETS = (ENV["CQL_PG_MATRIX"]? || "").split(',', remove_empty: true).map do |entry|
  major, _, port = entry.partition('=')
  Target.new(major.to_i, port.to_i)
end

private def prepare_roles(target : Target) : Nil
  session = target.session
  session.simple_query("SET password_encryption = 'scram-sha-256'; DROP ROLE IF EXISTS cql_scram; CREATE ROLE cql_scram LOGIN PASSWORD 'secret'")
  session.simple_query("SET password_encryption = 'md5'; DROP ROLE IF EXISTS cql_md5; CREATE ROLE cql_md5 LOGIN PASSWORD 'secret'; DROP ROLE IF EXISTS cql_clear; CREATE ROLE cql_clear LOGIN PASSWORD 'secret'")
  session.close
end

describe "PostgreSQL version matrix" do
  if TARGETS.empty?
    it "runs against every server script/pg-matrix started" do
      pending! "set CQL_PG_MATRIX (see script/pg-matrix)"
    end
  end

  TARGETS.each do |target|
    describe "PostgreSQL #{target.major}" do
      before_all { prepare_roles(target) }

      it "is the server we think it is" do
        session = target.session
        session.server_parameters["server_version"].should match(/\A#{target.major}(\.|[a-z])/) # "19.0", or "19rc1" for a release candidate
        session.close
      end

      it "negotiates #{target.newest_protocol} and cancels with that version's key" do
        session = target.session
        session.protocol_version.should eq target.newest_protocol
        session.secret_key.size.should eq(target.major >= 18 ? 32 : 4)
        expect_raises(PG::QueryTimeout) { session.query("SELECT pg_sleep(10)", timeout: 200.milliseconds) }
        session.query("SELECT 7").rows.should eq [[7]]
        session.close
      end

      it "can be pinned to protocol 3.0, and refuses to start when 3.2 is required but unavailable" do
        pinned = target.session(extra: "&max_protocol_version=3.0")
        pinned.protocol_version.should eq PG::ProtocolVersion::V3_0
        pinned.secret_key.size.should eq 4
        pinned.close
        if target.major < 18
          expect_raises(PG::UnsupportedProtocol) { target.session(extra: "&min_protocol_version=3.2") }
        end
      end

      {"cql_scram" => "SCRAM-SHA-256", "cql_md5" => "MD5", "cql_clear" => "cleartext"}.each do |user, method|
        it "authenticates with #{method} and rejects a wrong password" do
          session = target.session(user, "secret")
          session.query("SELECT current_user").rows.should eq [[user]]
          session.close
          expect_raises(PG::InvalidAuthorization) { target.session(user, "wrong") }
        end
      end

      it "applies synchronous_commit per transaction and leaves the session default alone" do
        engine = PG::AsyncEngine.connect(target.url + "&pool_size=1")
        engine.transaction(synchronous_commit: false) { |tx| tx.exec_query(&.scalar("SHOW synchronous_commit")).should eq "off" }
        engine.exec_query(&.scalar("SHOW synchronous_commit")).should eq "on"
        engine.close
      end
    end
  end
end
