require "../spec_helper"
require "../../src/postgres"

# `pool_reset` in the URL clears session state when a connection returns to the engine's pool (tenant isolation).

private alias PG = CQL::Postgres

private SESSION_STATE_SQL = "SELECT pg_backend_pid(), coalesce(current_setting('app.tenant', true), ''), current_user::text, " \
                            "current_setting('search_path'), to_regclass('pg_temp.t_leak') IS NOT NULL"

private def session_state(connection : PG::Connection)
  connection.query_one(SESSION_STATE_SQL, as: {Int32, String, String, String, Bool})
end

private def reachable_postgres_url : String?
  url = postgres_database_url
  return unless url && url.starts_with?("postgres")
  PG::Session.connect(PG::Config.parse(url)).close
  url
rescue
  nil
end

# The session state of a one-connection pool before a borrower sets a tenant, a role, a search_path and a temp
# table, and what the next borrower of that connection finds.
private def session_state_around_a_borrower(query : String = "")
  url = reachable_postgres_url || pending!("needs a PostgreSQL server reachable through DATABASE_URL")
  engine = PG::AsyncEngine.connect("#{url}#{url.includes?('?') ? '&' : '?'}pool_size=1#{query}")
  begin
    before = engine.with_connection do |connection|
      state = session_state(connection)
      connection.exec_all("SELECT set_config('app.tenant', 'a', false); CREATE TEMP TABLE t_leak(x int); " \
                          "SET ROLE pg_monitor; SET search_path TO pg_catalog")
      state
    end
    {before, engine.with_connection { |connection| session_state(connection) }}
  ensure
    engine.close
  end
end

describe "pool_reset (URL option of the engine's pool)" do
  it "maps discard_all to DISCARD ALL, and leaves no reset by default" do
    PG::Pool::Options.from(PG::Config.parse("postgres://h/db?pool_reset=discard_all")).reset_sql.should eq "DISCARD ALL"
    PG::Pool::Options.from(PG::Config.parse("postgres://h/db")).reset_sql.should be_nil
  end

  it "rejects any other value, reset_all included, naming the key and discard_all" do
    {"reset_all", "nope"}.each do |value|
      expect_raises(ArgumentError, /pool_reset must be discard_all/) { PG::Pool::Options.from(PG::Config.parse("postgres://h/db?pool_reset=#{value}")) }
    end
  end

  it "lets AsyncEngine.connect(reset:) replace the URL's pool_reset, an empty reset keeping it" do
    {
      {"?pool_reset=discard_all", nil, "DISCARD ALL"}, {"?pool_reset=discard_all", "SELECT 1", "SELECT 1"},
      {"?pool_reset=discard_all", "", "DISCARD ALL"}, {"", nil, nil},
    }.each do |query, reset, expected|
      engine = PG::AsyncEngine.connect("postgres://localhost:1/db#{query}", reset: reset)
      engine.pool.options.reset_sql.should eq expected
      engine.close
    end
  end

  it "hands the next borrower of the same backend the session the previous one found (live)" do
    before, after = session_state_around_a_borrower("&pool_reset=discard_all")
    after.should eq before
  end

  it "leaves the tenant, role, search_path and temp table to the next borrower without pool_reset, as before (live)" do
    before, after = session_state_around_a_borrower
    after.should eq({before[0], "a", "pg_monitor", "pg_catalog", true})
  end
end
