require "../spec_helper"

# Heap bytes allocated per call of the block, after a warm-up so one-time setup is not counted.
def bytes_per_call(calls : Int32, & : ->) : Float64
  100.times { yield }
  before = GC.stats.total_bytes
  calls.times { yield }
  (GC.stats.total_bytes - before) / calls.to_f
end

# The block does no DB work, so only CQL's telemetry and monitoring around it are measured.
def bytes_per_statement : Float64
  sql = "SELECT 1"
  params = [] of DB::Any
  UserDB.with_connection do |connection|
    executor = CQL::ConnectionExecutor.new(UserDB.adapter, connection)
    bytes_per_call(100_000) { CQL::Execution.run(executor, sql, params, :select) { |_connection| 1 } }
  end
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
end
