require "../spec_helper"
require "../../src/postgres"

# Bound values stay out of crystal-db's "db" Debug log unless CQL::Telemetry.capture_params (DATABASE_URL, else pending).

private MARKER = "alice-marker@secret.example"

private def open_live : CQL::Postgres::Connection
  CQL::Postgres::Connection.open(CQL::Postgres::Config.parse(postgres_database_url))
rescue
  pending! "needs a PostgreSQL server reachable through DATABASE_URL"
end

# The single "Executing query" entry the native driver logs while it runs `SELECT $1::text` with MARKER.
private def logged_select_entry(capture_params : Bool) : Log::Entry
  connection = open_live
  backend = Log::MemoryBackend.new
  previous, CQL::Telemetry.capture_params = CQL::Telemetry.capture_params, capture_params
  Log.builder.bind("db", :debug, backend)
  connection.scalar("SELECT $1::text", MARKER).should eq MARKER
  backend.entries.select(&.message.==("Executing query")).tap(&.size.should(eq 1)).first
ensure
  Log.builder.unbind("db", :debug, backend) if backend
  CQL::Telemetry.capture_params = previous unless previous.nil?
  connection.try &.close
end

describe CQL::Postgres::Statement do
  it "logs the query and the argument count, never the bound values" do
    entry = logged_select_entry(capture_params: false)
    "#{entry.message} #{entry.data}".should_not contain MARKER
    entry.data[:query]?.try(&.raw).should eq "SELECT $1::text"
    entry.data[:args_count]?.try(&.raw).should eq 1
  end

  it "includes the bound values when CQL::Telemetry.capture_params is on" do
    entry = logged_select_entry(capture_params: true)
    entry.data.to_s.should contain MARKER
  end
end
