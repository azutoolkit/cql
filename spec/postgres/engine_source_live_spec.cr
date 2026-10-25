require "../spec_helper"
require "../../src/postgres"

# A Schema on the engine's pool against a real PostgreSQL (DATABASE_URL, default postgres://localhost/cql_test):
# models, transactions with savepoints and fiber isolation. Pending when no server accepts this driver. Its table lives
# in a PostgreSQL schema of its own (cql_src_live_<pid>, via search_path), so concurrent runs do not collide.

private alias PG = CQL::Postgres

private PG_SCHEMA = "cql_src_live_#{Process.pid}"

# Only a postgres:// or cockroachdb:// URL can serve this spec; anything else builds a schema that is never used.
private LIVE_URL   = postgres_database_url.try { |url| url.starts_with?("postgres") || url.starts_with?("cockroachdb") ? url : nil } || "postgres://localhost:1/none"
private ENGINE_URL = "#{LIVE_URL}#{LIVE_URL.includes?('?') ? '&' : '?'}search_path=#{PG_SCHEMA}"

private def live? : Bool
  session = PG::Session.connect(PG::Config.parse(LIVE_URL))
  session.query("CREATE SCHEMA IF NOT EXISTS #{PG_SCHEMA}")
  session.close
  true
rescue
  false
end

private def live_schema : CQL::Schema
  adapter = ENGINE_URL.starts_with?("cockroachdb:") ? CQL::Adapter::CockroachDB : CQL::Adapter::Postgres
  # Built without connecting (no warm-up), so an unreachable DATABASE_URL leaves the examples pending.
  engine = PG::AsyncEngine.new(PG::Pool.new(PG::Config.parse(ENGINE_URL)), adapter)
  CQL::Schema.define(:engine_source_live, ENGINE_URL, adapter, source: PG::EngineSource.new(engine)) do
    table :cql_source_live_people do
      primary :id, Int64, auto_increment: true
      text :name
    end
  end
end

private LiveSchema = live_schema

private class LivePerson
  include CQL::ActiveRecord::Model(Int64)

  db_context schema: LiveSchema, table: :cql_source_live_people

  property name : String

  def initialize(@name : String)
  end
end

describe "CQL::Schema on a Postgres::EngineSource (live)" do
  before_each do
    pending! "needs a PostgreSQL server reachable through DATABASE_URL" unless live?
    LiveSchema.exec("DROP TABLE IF EXISTS cql_source_live_people")
    LiveSchema.exec("CREATE TABLE cql_source_live_people (id BIGSERIAL PRIMARY KEY, name TEXT NOT NULL)")
  end

  after_each do
    LiveSchema.exec("DROP TABLE IF EXISTS cql_source_live_people") if live?
  end

  after_all do
    next unless live?
    session = PG::Session.connect(PG::Config.parse(LIVE_URL))
    session.query("DROP SCHEMA IF EXISTS #{PG_SCHEMA} CASCADE")
    session.close
  end

  it "saves, finds and deletes a model on the engine pool" do
    LivePerson.new("ada").save!
    person = LivePerson.query.first.not_nil!
    id = person.id.not_nil!
    LivePerson.query.find!(id).name.should eq "ada"
    person.delete!
    LivePerson.query.find(id).should be_nil
    LiveSchema.pool_stats.idle.should be >= 1
  end

  it "commits and rolls back Model.transaction, with a savepoint inside" do
    LivePerson.transaction do |tx|
      LivePerson.new("kept").save!
      LivePerson.transaction(tx) do |inner|
        LivePerson.new("undone").save!
        inner.rollback
      end
    end
    LivePerson.query.all.map(&.name).should eq ["kept"]

    expect_raises(Exception, "abort") do
      LivePerson.transaction do |_tx|
        LivePerson.new("lost").save!
        raise "abort"
      end
    end
    LivePerson.query.count.should eq 1
  end

  it "uses one connection per transaction while other fibers use their own" do
    done = Channel(Int64).new
    LiveSchema.transaction do |_tx|
      LivePerson.new("inside").save!
      spawn do # another fiber does not see the uncommitted row
        begin
          done.send(LivePerson.query.count.to_i64)
        rescue
          done.send(-1_i64)
        end
      end
      done.receive.should eq 0
    end
    LivePerson.query.count.should eq 1
  end
end
