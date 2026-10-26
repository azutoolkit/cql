# What CQL's telemetry and performance monitoring add to one ActiveRecord statement. The same two operations,
# `find` by id and `create!`, run against an in-memory SQLite database under each instrumentation configuration;
# compare every configuration's ips and bytes per iteration with "all off".
#
#   crystal run --release benchmarks/telemetry_overhead_bench.cr
#   BENCH_ONLY=tracer crystal run --release benchmarks/telemetry_overhead_bench.cr   # one configuration
require "benchmark"
require "sqlite3"
require "../src/cql"

# One logging setup for the whole process, before any timing: reconfiguring Log for a single configuration skews
# that row, and at debug crystal-db logs every statement.
Log.setup(:error)

# In-memory DBs are per connection, so the pool is pinned to one.
OverheadSchema = CQL::Schema.define(:overhead_bench, adapter: CQL::Adapter::SQLite, uri: "sqlite3::memory:?max_pool_size=1&initial_pool_size=1") do
  table :overhead_items do
    primary :id, Int64, auto_increment: true
    text :name
  end
end

class OverheadItem
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: OverheadSchema, table: :overhead_items

  property name : String

  def initialize(@name)
  end
end

class NoopTracer < CQL::Telemetry::Tracer
  def in_span(operation : Symbol, sql : String, & : -> T) : T forall T
    yield
  end
end

SEEDED_ROWS = 1_000
FIND_ID     = (SEEDED_ROWS // 2).to_i64

OverheadSchema.overhead_items.create!
(1..SEEDED_ROWS).each_slice(500) do |ids|
  rows = ids.map { |id| {:name => "item #{id}"} of Symbol => DB::Any }
  OverheadSchema.insert.into(:overhead_items).values(rows).commit
end

BENCH_ONLY    = ENV["BENCH_ONLY"]?.try(&.downcase)
WORKLOADS_RUN = [] of String

# Every configuration starts from the seeded rows, so rows differ by instrumentation alone.
def all_off
  CQL::Performance.monitor = CQL::Performance::Monitor.new(CQL::Performance.minimal_config)
  CQL::Telemetry.reset!
  OverheadSchema.delete.from(:overhead_items).where { overhead_items.id > SEEDED_ROWS }.commit
end

# Runs one configuration: the block turns the instrumentation on before timing starts, and "all off" is restored afterwards.
def workload(name : String, &)
  return if BENCH_ONLY.try { |only| !name.downcase.includes?(only) }
  WORKLOADS_RUN << name
  puts name
  all_off
  yield
  Benchmark.ips(warmup: 1.second, calculation: 3.seconds) do |job|
    job.report("find") { OverheadItem.find(FIND_ID) }
    job.report("create!") { OverheadItem.new("event").create! }
  end
ensure
  all_off
end

workload("all off") { }

workload("sync subscriber") do
  CQL::Telemetry.subscribe("bench") { |_event| }
end

# The bench loop never yields, so the consumer fiber rarely runs: this row mostly measures the push and drop path.
workload("async subscriber") do
  CQL::Telemetry.subscribe("bench", async: true) { |_event| }
end

workload("tracer") do
  CQL::Telemetry.tracer = NoopTracer.new
end

workload("production monitor") do
  CQL::Performance.enable_production_mode!
end

# Like the async subscriber row, the consumer rarely runs, so this mostly measures the push and drop path.
workload("async monitor") do
  config = CQL::Performance.production_config
  config.monitoring.async = true
  CQL::Performance.monitor = CQL::Performance::Monitor.new(config)
end

# Lines below the log level are never formatted, so this isolates the monitor's own bookkeeping. Failed statements
# and those over `very_slow_threshold` would still be logged at error, with their bound values.
workload("sql logging, filtered out") do
  CQL::Performance.enable_sql_logging(colorize: false)
end

# Repeats the first row so drift over the run is visible.
workload("baseline again") { }

abort "BENCH_ONLY=#{BENCH_ONLY} matched no workload" if WORKLOADS_RUN.empty?
