require "../spec_helper"

# The block does no DB work, so only CQL's telemetry and monitoring around it are measured.
def bytes_per_statement : Float64
  sql = "SELECT 1"
  params = [] of DB::Any
  UserDB.with_connection do |connection|
    executor = CQL::ConnectionExecutor.new(UserDB.adapter, connection)
    bytes_per_call(100_000) { CQL::Execution.run(executor, sql, params, :select) { |_connection| 1 } }
  end
end

# Holds the first recorded statement until its gate closes, so the async queue behind it stays full.
class BlockedProfiler < CQL::Performance::QueryProfiler
  def initialize(@gate : Channel(Nil))
    super()
  end

  def record_query(sql : String, params : Array(DB::Any), execution_time : Time::Span, rows_affected : Int64? = nil,
                   error : String? = nil, normalized_sql : String? = nil) : Void
    @gate.receive?
  end
end

# Profiling, detection and logging stay off, so the consumer allocates nothing either.
private def async_config(capacity : Int32) : CQL::Performance::Config
  config = CQL::Performance.minimal_config
  config.monitoring.enabled = true
  config.monitoring.async = true
  config.monitoring.async_queue_capacity = capacity
  config
end

describe "instrumentation allocation budget" do
  before_each { CQL::Telemetry.reset! }
  after_each { CQL::Telemetry.reset! }

  it "allocates nothing per statement with telemetry and monitoring off" do
    with_global_monitor(CQL::Performance::Monitor.new(CQL::Performance.minimal_config)) do
      bytes_per_statement.should be < 1.0
    end
  end

  it "allocates nothing per statement with one synchronous subscriber" do
    CQL::Telemetry.subscribe("overhead") { |_event| }
    CQL::Telemetry.subscribed?("overhead").should be_true
    with_global_monitor(CQL::Performance::Monitor.new(CQL::Performance.minimal_config)) do
      bytes_per_statement.should be < 1.0
    end
  end

  it "allocates nothing per statement with one async subscriber" do
    # Room for every measured event, so the enqueue path is measured and not only the drop path.
    CQL::Telemetry.async_queue_capacity = 150_000
    CQL::Telemetry.subscribe("overhead", async: true) { |_event| }
    with_global_monitor(CQL::Performance::Monitor.new(CQL::Performance.minimal_config)) do
      bytes_per_statement.should be < 1.0
    end
  ensure
    CQL::Telemetry.reset!
    CQL::Telemetry.async_queue_capacity = 4096
  end

  it "allocates nothing per statement with an async monitor and no bound values" do
    monitor = CQL::Performance::Monitor.new(async_config(150_000))
    with_global_monitor(monitor) { bytes_per_statement.should be < 1.0 }
  ensure
    monitor.try(&.close)
  end

  it "allocates nothing for a statement the full async queue drops, bound values included" do
    gate = Channel(Nil).new
    monitor = CQL::Performance::Monitor.new(async_config(1), profiler: BlockedProfiler.new(gate))
    params = [1, "x"] of DB::Any
    event = CQL::Telemetry.query_event(CQL::Adapter::SQLite, :select, "SELECT 1", params, 1.millisecond, nil, nil)
    bytes_per_call(100_000) { monitor.record(event, params) }.should be < 1.0
    monitor.counters.dropped_events.should be > 99_000
  ensure
    gate.try(&.close)
    monitor.try(&.close)
  end

  it "allocates nothing beginning a transaction without transaction subscribers" do
    bytes_per_call(100_000) { CQL::Telemetry.begin_transaction(CQL::Adapter::SQLite, false) }.should be < 1.0
  end

  it "allocates nothing for a context, around a block or a statement" do
    bytes_per_call(100_000) { CQL::Performance.with_context("req") { } }.should be < 1.0
    CQL::Telemetry.subscribe("overhead") { |_event| }
    with_global_monitor(CQL::Performance::Monitor.new(CQL::Performance.minimal_config)) do
      CQL::Telemetry.with_context("req") { bytes_per_statement.should be < 1.0 }
    end
  end
end

describe "performance recording allocation budget" do
  it "allocates nothing per repeated statement with the production monitor" do
    with_global_monitor(CQL::Performance::Monitor.new(CQL::Performance.production_config)) do
      bytes_per_statement.should be < 1.0
    end
  end

  it "allocates nothing recording a repeated query in the N+1 detector" do
    detector = CQL::Performance::NPlusOneDetector.new
    sql = "SELECT * FROM posts WHERE user_id = 1"
    bytes_per_call(100_000) { detector.record_query(sql, normalized_sql: "SELECT * FROM posts WHERE user_id = ?") }.should be < 1.0
  end

  it "allocates nothing recording a fast query in the profiler" do
    profiler = CQL::Performance::QueryProfiler.new
    params = [] of DB::Any
    bytes = bytes_per_call(100_000) { profiler.record_query("SELECT 1", params, 1.millisecond, nil, nil, normalized_sql: "SELECT ?") }

    bytes.should be < 1.0
  end

  it "allocates nothing recording a duration in a stats tracker" do
    tracker = CQL::Performance::StatsTracker.new

    bytes_per_call(100_000) { tracker.record(1.millisecond) }.should be < 1.0
  end
end
