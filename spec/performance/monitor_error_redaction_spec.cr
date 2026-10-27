require "../spec_helper"
require "log/spec"

# A driver message can echo a bound value unquoted (a trigger's RAISE), so with include_params off only its class and code are kept.
describe "CQL::Performance::Monitor failed statement errors" do
  marker = "marker-secret-42"
  sql = "INSERT INTO pii_people (name) VALUES (?)"
  schema = spec_sqlite_schema("monitor_error_redaction.db")
  schema.exec("CREATE TABLE IF NOT EXISTS pii_people (name TEXT)")
  schema.exec("CREATE TRIGGER IF NOT EXISTS reject_people BEFORE INSERT ON pii_people BEGIN SELECT RAISE(ABORT, 'rejected name #{marker}'); END")

  build_monitor = ->(include_params : Bool) do
    config = CQL::Performance::Config.new
    config.monitoring.enabled = true
    config.logging.enabled = true
    config.logging.include_params = include_params
    config.profiling.slow_query_threshold = Time::Span.zero
    CQL::Performance::Monitor.new(config: config)
  end

  failed_insert = ->(monitor : CQL::Performance::Monitor) do
    Log.capture("*") do |logs|
      with_global_monitor(monitor) do
        expect_raises(SQLite3::Exception, "rejected name #{marker}") { CQL::Execution.run(schema, sql, ["ada"] of DB::Any, :insert, &.exec(sql, args: ["ada"] of DB::Any)) }
      end
      logs.check(:error, /\AQuery failed:/)
    end.entry.message
  end

  it "logs only the error's class and SQLite code when include_params is off" do
    message = failed_insert.call(build_monitor.call(false))
    message.should start_with("Query failed: SQLite3::Exception (code 19)\nSQL: ")
    message.should_not contain(marker)
  end

  it "stores and exports only the error's class and SQLite code when include_params is off" do
    monitor = build_monitor.call(false)
    failed_insert.call(monitor)
    monitor.profiler.not_nil!.slowest_queries(1).first.error.should eq("SQLite3::Exception (code 19)")
    with_global_monitor(monitor) { CQL::Performance.export_metrics_as_json }.should_not contain(marker)
  end

  it "logs the driver's full message when include_params is on" do
    failed_insert.call(build_monitor.call(true)).should contain("Query failed: rejected name #{marker}")
  end

  it "logs only a PostgreSQL error's class and SQLSTATE when include_params is off" do
    error = CQL::Postgres::ServerError.from({'S' => "ERROR", 'C' => "P0001", 'M' => "rejected name #{marker}"})
    event = CQL::Telemetry::QueryEvent.new(sql, 1, nil, 1.millisecond, error, CQL::Adapter::Postgres, :insert, nil, nil)
    Log.capture("*") { |logs| build_monitor.call(false).record(event, ["ada"] of DB::Any); logs.check(:error, /\AQuery failed:/) }
      .entry.message.should start_with("Query failed: CQL::Postgres::ServerError (SQLSTATE P0001)\n")
  end
end
