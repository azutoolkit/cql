require "../spec_helper"
require "../../src/postgres"

# A backend that dies while its connection sits idle in the engine's pool (a failover, a restart, a proxy's idle
# timeout, pg_terminate_backend) fails no caller with the default pool options; a statement that reached a backend
# which then died still raises, as it may have run. Pending without a PostgreSQL server at DATABASE_URL.

private alias PG = CQL::Postgres

private LIVE_URL = postgres_database_url
private PID_SQL  = "SELECT pg_backend_pid()"

# Three warm idle connections whose backends can be found by *name*.
private def pooled_url(name : String) : String
  "#{LIVE_URL}#{LIVE_URL.includes?('?') ? '&' : '?'}pool_size=3&pool_min_size=3&application_name=#{name}"
end

# Terminates *name*'s backends (once one is running a statement, when *active*) from a session of its own and waits
# until they are gone, so their FATALs sit in the pooled sockets. Returns their pids.
private def terminate_backends(name : String, active : Bool = false) : Array(Int32)
  admin = PG::Session.connect(PG::Config.parse(LIVE_URL))
  where = "FROM pg_stat_activity WHERE application_name = $1#{" AND state = 'active'" if active}"
  pids = ->(columns : String) { admin.query("SELECT pid#{columns} #{where}", [admin.encode(name)]).rows.map(&.first.as(Int32)) }
  terminated = eventually { (found = pids.call(", pg_terminate_backend(pid)")).empty? ? nil : found }
  eventually { pids.call("").empty? || nil }
  terminated
ensure
  admin.try &.close
end

private def eventually(&)
  100.times { (found = yield) ? (return found) : sleep(20.milliseconds) }
  raise "gave up waiting on pg_stat_activity"
end

describe "CQL::Postgres::AsyncEngine failover (live)" do
  before_each { require_postgres! }

  it "serves the next statements on fresh connections after the idle pooled backends were terminated" do
    name = "cql_failover_#{Random::Secure.hex(4)}"
    engine = PG::AsyncEngine.connect(pooled_url(name))
    dead = terminate_backends(name)
    dead.size.should eq 3
    served = Array.new(3) { engine.with_connection(&.scalar(PID_SQL)) }
    (served & dead).should be_empty
    engine.pool.stats.in_use.should eq 0
    engine.close
  end

  it "does the same for a Schema on an EngineSource" do
    name = "cql_failover_#{Random::Secure.hex(4)}"
    schema = CQL::Schema.new(:engine_failover_live, LIVE_URL, CQL::Adapter::Postgres, source: PG::EngineSource.connect(pooled_url(name)))
    dead = terminate_backends(name)
    served = Array.new(3) { schema.with_connection(&.scalar(PID_SQL)) }
    (served & dead).should be_empty
    schema.pool_stats.in_flight.should eq 0
    schema.close
  end

  it "still raises when the backend dies while running the statement, which may have run" do
    name = "cql_failover_#{Random::Secure.hex(4)}"
    engine = PG::AsyncEngine.connect(pooled_url(name))
    spawn { terminate_backends(name, active: true) }
    expect_raises(PG::ServerError, /57P01/) { engine.with_connection(&.scalar("SELECT pg_sleep(2)")) }
    engine.close
  end
end
