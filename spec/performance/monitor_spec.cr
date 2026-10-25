require "../spec_helper"
require "log/spec"

private class CountingFormatter < CQL::Performance::SQLFormatter
  getter calls = 0

  def format(sql : String, params : Array(DB::Any) = [] of DB::Any,
             execution_time : Time::Span? = nil, rows_affected : Int64? = nil,
             context : String? = nil) : String
    @calls += 1
    super
  end
end

describe CQL::Performance::Monitor do
  describe "query logging" do
    it "formats a query only when its log level is emitted" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.logging.enabled = true
      formatter = CountingFormatter.new(colorize_enabled: false)
      monitor = CQL::Performance::Monitor.new(config: config, sql_formatter: formatter)

      Log.capture("*", level: :warn) { monitor.track("SELECT 1") { 1 } }
      formatter.calls.should eq(0)

      Log.capture("*", level: :info) { monitor.track("SELECT 1") { 1 } }
      formatter.calls.should eq(1)
    end

    it "logs slow queries at warn and very slow ones at error" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.logging.enabled = true
      config.profiling.slow_query_threshold = 0.seconds
      config.profiling.very_slow_threshold = 1.hour
      slow = CQL::Performance::Monitor.new(config: config, sql_formatter: CQL::Performance::SQLFormatter.new(colorize_enabled: false))
      Log.capture("*") do |logs|
        slow.track("SELECT 2") { 2 }
        logs.check(:warn, /SELECT 2/)
      end

      config.profiling.very_slow_threshold = 0.seconds
      very_slow = CQL::Performance::Monitor.new(config: config, sql_formatter: CQL::Performance::SQLFormatter.new(colorize_enabled: false))
      Log.capture("*") do |logs|
        very_slow.track("SELECT 3") { 3 }
        logs.check(:error, /SELECT 3/)
      end
    end
  end

  describe "#initialize" do
    it "creates a monitor with default config" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = false
      monitor = CQL::Performance::Monitor.new(config: config)

      monitor.enabled?.should be_false
      monitor.error_count.should eq(0)
    end

    it "creates a monitor with custom components" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.detection.enabled = true
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      monitor.enabled?.should be_true
      monitor.profiler.should_not be_nil
      monitor.detector.should_not be_nil
    end

    it "creates a monitor with profiling disabled" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = false
      config.detection.enabled = false
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      monitor.profiler.should be_nil
      monitor.detector.should be_nil
    end
  end

  describe "#monitor_query" do
    it "executes the block and returns its result" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      result = monitor.monitor_query("SELECT 1") { 42 }
      result.should eq(42)
    end

    it "returns the block result when monitoring is disabled" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      result = monitor.monitor_query("SELECT 1") { 42 }
      result.should eq(42)
    end

    it "records query execution in the profiler" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      monitor.monitor_query("SELECT * FROM users") { "data" }

      profiler = monitor.profiler
      profiler.should_not be_nil
      stats = profiler.not_nil!.statistics
      stats.should_not be_empty
    end

    it "accepts params array" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      params = [1.as(DB::Any)]
      result = monitor.monitor_query("SELECT * FROM users WHERE id = ?", params) { "found" }
      result.should eq("found")
    end
  end

  describe "#monitor_query error handling" do
    it "tracks errors and re-raises the exception" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      expect_raises(RuntimeError, "query failed") do
        monitor.monitor_query("SELECT * FROM bad_table") do
          raise RuntimeError.new("query failed")
        end
      end

      monitor.error_count.should eq(1)
    end

    it "increments error count for each failed query" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      2.times do
        monitor.monitor_query("SELECT bad") { raise RuntimeError.new("fail") }
      rescue RuntimeError
      end

      monitor.error_count.should eq(2)
    end
  end

  describe "#track" do
    it "is a convenience wrapper for monitor_query" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      result = monitor.track("SELECT 1") { 42 }
      result.should eq(42)
    end

    it "accepts params" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      params = ["test".as(DB::Any)]
      result = monitor.track("SELECT ?", params) { "ok" }
      result.should eq("ok")
    end
  end

  describe "when monitoring is disabled" do
    it "returns the block value and records nothing through Performance.track" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = false
      config.profiling.enabled = true
      config.logging.enabled = false
      monitor = CQL::Performance::Monitor.new(config: config)

      with_global_monitor(monitor) do
        CQL::Performance.track("SELECT 1", [] of DB::Any) { 42 }.should eq(42)
      end

      monitor.profiler.not_nil!.statistics.should be_empty
      monitor.error_count.should eq(0)
    end

    it "lets a raising query propagate without counting or recording it" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = false
      config.profiling.enabled = true
      config.logging.enabled = false
      monitor = CQL::Performance::Monitor.new(config: config)

      expect_raises(RuntimeError, "query failed") do
        monitor.monitor_query("SELECT * FROM bad_table") { raise RuntimeError.new("query failed") }
      end

      monitor.error_count.should eq(0)
      monitor.profiler.not_nil!.statistics.should be_empty
    end
  end

  describe "#with_context" do
    it "sets context and restores it after the block" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      result = monitor.with_context("user_loading") do
        monitor.track("SELECT * FROM users") { "data" }
        "context_result"
      end

      result.should eq("context_result")
    end

    it "restores context even when an exception occurs" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      expect_raises(RuntimeError) do
        monitor.with_context("failing_context") do
          raise RuntimeError.new("context error")
        end
      end

      # Context should be restored to nil (no crash on subsequent operations)
      monitor.with_context("new_context") do
        monitor.track("SELECT 1") { 42 }
      end
    end
  end

  describe "#generate_report" do
    it "generates a text report by default" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.logging.enabled = false
      config.reporting.format = "text"

      monitor = CQL::Performance::Monitor.new(config: config)
      monitor.track("SELECT * FROM users") { nil }

      report = monitor.generate_report
      report.should be_a(String)
      report.should contain("Performance Report")
    end

    it "generates a JSON report" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)
      monitor.track("SELECT 1") { nil }

      report = monitor.generate_report("json")
      report.should be_a(String)
      # JSON report should be parseable
      parsed = JSON.parse(report)
      parsed.should_not be_nil
    end

    it "generates an HTML report" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      report = monitor.generate_report("html")
      report.should be_a(String)
      report.should contain("<html>")
      report.should contain("CQL Performance Report")
    end

    it "falls back to text format for unknown formats" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      report = monitor.generate_report("unknown_format")
      report.should be_a(String)
      report.should contain("Performance Report")
    end
  end

  describe "#metrics" do
    it "returns PerformanceMetrics" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      m = monitor.metrics
      m.should be_a(CQL::Performance::PerformanceMetrics)
    end

    it "reflects query activity in metrics" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      3.times { monitor.track("SELECT * FROM users") { nil } }

      m = monitor.metrics
      m.query_metrics.total_queries.should be >= 3_i64
    end
  end

  describe "#metrics_summary" do
    it "returns a hash with correct keys" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      summary = monitor.metrics_summary
      summary.should be_a(Hash(String, String | Int64 | Float64))
      summary.has_key?("total_queries").should be_true
      summary.has_key?("slow_queries").should be_true
      summary.has_key?("error_rate_percent").should be_true
      summary.has_key?("avg_query_time_ms").should be_true
      summary.has_key?("n_plus_one_patterns").should be_true
      summary.has_key?("health_score").should be_true
      summary.has_key?("total_issues").should be_true
      summary.has_key?("uptime_seconds").should be_true
    end

    it "returns correct types for values" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      summary = monitor.metrics_summary
      summary["total_queries"].should be_a(Int64)
      summary["slow_queries"].should be_a(Int64)
      summary["error_rate_percent"].should be_a(Float64)
      summary["avg_query_time_ms"].should be_a(Float64)
      summary["health_score"].should be_a(String)
      summary["uptime_seconds"].should be_a(Float64)
    end
  end

  describe "#healthy?" do
    it "returns true for a fresh monitor with no issues" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      monitor.healthy?.should be_true
    end

    it "delegates to metrics" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      # healthy? should match metrics.healthy?
      monitor.healthy?.should eq(monitor.metrics.healthy?)
    end
  end

  describe "#clear" do
    it "resets profiler, detector, and error count" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.detection.enabled = true
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      # Generate some activity
      monitor.track("SELECT * FROM users") { nil }
      monitor.track("SELECT * FROM posts") { nil }

      begin
        monitor.track("SELECT bad") { raise RuntimeError.new("fail") }
      rescue RuntimeError
      end

      monitor.error_count.should be > 0

      monitor.clear

      monitor.error_count.should eq(0)

      # Profiler stats should be cleared
      profiler = monitor.profiler
      if profiler
        stats = profiler.statistics
        stats.should be_empty
      end
    end
  end

  describe "#enabled?" do
    it "returns true when monitoring is enabled" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true

      monitor = CQL::Performance::Monitor.new(config: config)

      monitor.enabled?.should be_true
    end

    it "returns false when monitoring is disabled" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      monitor.enabled?.should be_false
    end
  end

  describe "#configure" do
    it "reconfigures components via block" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.detection.enabled = false
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      monitor.detector.should be_nil

      monitor.configure do |cfg|
        cfg.detection.enabled = true
      end

      monitor.detector.should_not be_nil
    end

    it "can disable profiling" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.profiling.enabled = true
      config.logging.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      monitor.profiler.should_not be_nil

      monitor.configure do |cfg|
        cfg.profiling.enabled = false
      end

      monitor.profiler.should be_nil
    end

    it "can toggle monitoring enabled state" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = false

      monitor = CQL::Performance::Monitor.new(config: config)

      monitor.enabled?.should be_false

      monitor.configure do |cfg|
        cfg.monitoring.enabled = true
      end

      monitor.enabled?.should be_true
    end
  end
end

# Spies for the shared-normalization seam: both interfaces' `record_query` accept an optional
# `normalized_sql:` keyword, which the monitor fills in once per query.
class NormalizationSpyProfiler
  include CQL::Performance::QueryProfilerInterface

  getter received = [] of {String, String?}

  def record_query(sql : String, params : Array(DB::Any),
                   execution_time : Time::Span,
                   rows_affected : Int64? = nil,
                   error : String? = nil,
                   normalized_sql : String? = nil) : Void
    @received << {sql, normalized_sql}
  end

  def statistics
    {} of String => NamedTuple(count: Int32, total_ms: Float64, avg_ms: Float64, min_ms: Float64, max_ms: Float64)
  end

  def slowest_queries(limit : Int32) : Array(CQL::Performance::QueryData)
    [] of CQL::Performance::QueryData
  end

  def stats_trackers : Hash(String, CQL::Performance::StatsTracker)
    {} of String => CQL::Performance::StatsTracker
  end

  def issues : Array(CQL::Performance::Issue)
    [] of CQL::Performance::Issue
  end

  def clear : Void
  end
end

class RaisingProfiler
  include CQL::Performance::QueryProfilerInterface

  def record_query(sql : String, params : Array(DB::Any),
                   execution_time : Time::Span,
                   rows_affected : Int64? = nil,
                   error : String? = nil,
                   normalized_sql : String? = nil) : Void
    raise "profiler broke"
  end

  def statistics
    {} of String => NamedTuple(count: Int32, total_ms: Float64, avg_ms: Float64, min_ms: Float64, max_ms: Float64)
  end

  def slowest_queries(limit : Int32) : Array(CQL::Performance::QueryData)
    [] of CQL::Performance::QueryData
  end

  def stats_trackers : Hash(String, CQL::Performance::StatsTracker)
    {} of String => CQL::Performance::StatsTracker
  end

  def issues : Array(CQL::Performance::Issue)
    [] of CQL::Performance::Issue
  end

  def clear : Void
  end
end

class NormalizationSpyDetector
  include CQL::Performance::NPlusOneDetectorInterface

  getter received = [] of {String, String?}

  def record_query(sql : String, normalized_sql : String? = nil) : Void
    @received << {sql, normalized_sql}
  end

  def start_relation_loading(relation_name : String, parent_model : String) : Void
  end

  def end_relation_loading : Void
  end

  def patterns
    [] of CQL::Performance::NPlusOnePattern
  end

  def issues : Array(CQL::Performance::Issue)
    [] of CQL::Performance::Issue
  end

  def clear : Void
  end
end

describe "CQL::Performance::Monitor shared SQL normalization" do
  sql = "SELECT * FROM users WHERE id = 42 AND name = 'Alice'"
  normalized = CQL::Performance::SQLUtils.normalize_sql(sql)

  build_monitor = ->(profiler : NormalizationSpyProfiler, detector : NormalizationSpyDetector) do
    config = CQL::Performance::Config.new
    config.monitoring.enabled = true
    config.logging.enabled = false
    CQL::Performance::Monitor.new(config: config, profiler: profiler, detector: detector)
  end

  it "hands the profiler the SQL normalized by the monitor" do
    profiler = NormalizationSpyProfiler.new
    detector = NormalizationSpyDetector.new

    build_monitor.call(profiler, detector).track(sql) { 1 }

    profiler.received.should eq([{sql, normalized}])
  end

  it "hands the N+1 detector the same normalized SQL as the profiler" do
    profiler = NormalizationSpyProfiler.new
    detector = NormalizationSpyDetector.new

    build_monitor.call(profiler, detector).track(sql) { 1 }

    detector.received.should eq([{sql, normalized}])
  end

  it "still hands the profiler the normalized SQL when the tracked block raises, and skips the detector" do
    profiler = NormalizationSpyProfiler.new
    detector = NormalizationSpyDetector.new

    expect_raises(Exception, "boom") do
      build_monitor.call(profiler, detector).track(sql) { raise "boom" }
    end

    profiler.received.should eq([{sql, normalized}])
    detector.received.should be_empty
  end
end

describe "CQL.config.monitor_performance" do
  after_each { CQL.reset_config! }

  it "enables the global performance monitor when set to true" do
    disabled = CQL::Performance::Config.new
    disabled.monitoring.enabled = false

    with_global_monitor(CQL::Performance::Monitor.new(config: disabled)) do
      CQL.configure(&.monitor_performance=(true))

      CQL::Performance.monitor.enabled?.should be_true
    end
  end

  it "leaves the global performance monitor disabled when false" do
    disabled = CQL::Performance::Config.new
    disabled.monitoring.enabled = false

    with_global_monitor(CQL::Performance::Monitor.new(config: disabled)) do
      CQL.configure(&.monitor_performance=(false))

      CQL::Performance.monitor.enabled?.should be_false
    end
  end
end

describe "CQL::Performance.enable_sql_logging" do
  it "turns monitoring on so tracked queries are logged" do
    disabled = CQL::Performance::Config.new
    disabled.monitoring.enabled = false

    with_global_monitor(CQL::Performance::Monitor.new(config: disabled)) do
      CQL::Performance.enable_sql_logging(colorize: false)

      CQL::Performance.monitor.enabled?.should be_true
      Log.capture("*") do |logs|
        CQL::Performance.track("SELECT 1") { 1 }
        logs.check(:info, /SELECT 1/)
      end
    end
  end
end

describe "CQL::Performance.with_context across fibers" do
  it "shows each fiber's own context in its SQL log entries and never another's" do
    config = CQL::Performance::Config.new
    config.monitoring.enabled = true
    config.logging.enabled = true
    monitor = CQL::Performance::Monitor.new(config: config, sql_formatter: CQL::Performance::SQLFormatter.new(colorize_enabled: false))
    done = Channel(Nil).new
    entries = [] of String

    with_global_monitor(monitor) do
      Log.capture("*") do |logs|
        %w[a b].each do |name|
          spawn do
            CQL::Performance.with_context(name) do
              CQL::Performance.track("SELECT '#{name}1'") { 1 }
              sleep 5.milliseconds
              CQL::Performance.track("SELECT '#{name}2'") { 1 }
            end
            done.send(nil)
          end
        end
        2.times { done.receive }
        4.times { logs.next("a logged statement") { |entry| entries << entry.message; true } }
      end
    end

    {"a" => "b", "b" => "a"}.each do |own, other|
      own_entries = entries.select(&.includes?("'#{own}"))
      own_entries.size.should eq(2)
      own_entries.each(&.should(contain("{#{own}}")))
      own_entries.each(&.should_not(contain("{#{other}}")))
    end
  end
end

describe "CQL::Performance::Monitor with CQL::Execution.run" do
  events = [] of CQL::Telemetry::QueryEvent

  profiling_monitor = -> do
    config = CQL::Performance::Config.new
    config.monitoring.enabled = true
    config.profiling.enabled = true
    config.detection.enabled = false
    config.logging.enabled = false
    CQL::Performance::Monitor.new(config: config)
  end

  raising_monitor = -> do
    config = CQL::Performance::Config.new
    config.monitoring.enabled = true
    config.detection.enabled = false
    config.logging.enabled = false
    CQL::Performance::Monitor.new(config: config, profiler: RaisingProfiler.new)
  end

  statement_count = ->(monitor : CQL::Performance::Monitor) { monitor.profiler.not_nil!.statistics.values.sum(&.[:count]) }
  total_ms = ->(monitor : CQL::Performance::Monitor) { monitor.profiler.not_nil!.statistics.values.sum(&.[:total_ms]) }
  select_names = -> { UserDB.query.from(:users).select(:name).where(name: "ada").all(as: String) }

  before_each do
    CQL::Telemetry.reset!
    UserDB.users.create!
    events.clear
    CQL::Telemetry.subscribe("spec") { |event| events << event }
  end

  after_each do
    CQL::Telemetry.reset!
    UserDB.users.drop!
  end

  it "records the exact duration the telemetry event reports for one statement" do
    monitor = profiling_monitor.call

    with_global_monitor(monitor) { select_names.call }

    events.size.should eq(1)
    statement_count.call(monitor).should eq(1)
    total_ms.call(monitor).should eq(events.first.duration.total_milliseconds)
  end

  it "keeps recording after Telemetry.reset! drops the subscribers" do
    monitor = profiling_monitor.call

    with_global_monitor(monitor) do
      select_names.call
      statement_count.call(monitor).should eq(1)
      CQL::Telemetry.reset!
      select_names.call
    end

    statement_count.call(monitor).should eq(2)
  end

  it "records a failed statement with a measured duration and counts the error" do
    monitor = profiling_monitor.call

    with_global_monitor(monitor) do
      expect_raises(SQLite3::Exception, /no such column/) { UserDB.query.from(:users).where("nope = ?", 1).all(as: Int32) }
    end

    trackers = monitor.profiler.not_nil!.stats_trackers.values
    trackers.size.should eq(1)
    trackers.first.total_time.should be > Time::Span.zero
    trackers.first.errors.should eq(1)
    monitor.error_count.should eq(1)
  end

  it "keeps the driver's exception when the monitor fails recording a failed statement" do
    with_global_monitor(raising_monitor.call) do
      expect_raises(SQLite3::Exception, /no such column/) { UserDB.query.from(:users).where("nope = ?", 1).all(as: Int32) }
    end
  end

  it "leaves the Params section out of a failed statement's log line when include_params is off" do
    config = CQL::Performance::Config.new
    config.monitoring.enabled = true
    config.logging.enabled = true
    config.logging.include_params = false
    secret = "secret@example.com"

    Log.capture("*") do |logs|
      with_global_monitor(CQL::Performance::Monitor.new(config: config)) do
        expect_raises(SQLite3::Exception, /no such column/) { UserDB.query.from(:users).where("nope = ?", secret).all(as: Int32) }
      end

      entry = logs.next(:error, /\AQuery failed:/).entry
      entry.exception.should be_nil
      message = entry.message
      message.should_not contain(secret)
      message.should_not contain("Params:")
      logs.empty
    end
  end

  it "returns the result when the monitor fails recording a successful statement" do
    with_global_monitor(raising_monitor.call) { select_names.call.should eq([] of String) }
  end

  it "logs a monitor failure as an error" do
    Log.capture("*") do |logs|
      with_global_monitor(raising_monitor.call) { select_names.call }
      logs.check(:error, /performance monitor/i)
    end
  end

  it "does not record an explain" do
    monitor = profiling_monitor.call

    with_global_monitor(monitor) { UserDB.query.from(:users).where(name: "ada").explain }

    events.map(&.operation).should eq([:explain])
    monitor.profiler.not_nil!.statistics.should be_empty
  end

  it "does not record DDL run through Schema#exec" do
    monitor = profiling_monitor.call

    with_global_monitor(monitor) { UserDB.exec("SELECT 1") }

    events.map(&.operation).should eq([:ddl])
    monitor.profiler.not_nil!.statistics.should be_empty
  end
end

describe "CQL::Performance::Monitor SQL logging of bound values" do
  secret = "secret@example.com"
  sql = "SELECT * FROM users WHERE email = ?"

  # Statements count as slow unless an example raises the threshold, so their log line is a warning.
  build_monitor = ->(include_params : Bool) do
    config = CQL::Performance::Config.new
    config.monitoring.enabled = true
    config.logging.enabled = true
    config.logging.colorize = false
    config.logging.pretty_format = false
    config.logging.include_params = include_params
    config.profiling.slow_query_threshold = Time::Span.zero
    CQL::Performance::Monitor.new(config: config)
  end

  it "leaves bound values out of a slow statement's log line when include_params is off" do
    monitor = build_monitor.call(false)

    Log.capture("*") do |logs|
      monitor.track(sql, [secret] of DB::Any) { 1 }

      logs.check(:warn, /SQL \(.*\)\n  SELECT/).entry.message.should_not contain(secret)
    end
  end

  it "leaves bound values out of a fast statement's log line when include_params is off" do
    monitor = build_monitor.call(false)
    monitor.configure(&.profiling.slow_query_threshold=(1.hour))

    Log.capture("*") do |logs|
      monitor.track(sql, [secret] of DB::Any) { 1 }

      logs.check(:info, /SQL \(.*\)\n  SELECT/).entry.message.should_not contain(secret)
    end
  end

  it "leaves bound values out of a failed statement's log line when include_params is off" do
    monitor = build_monitor.call(false)

    Log.capture("*") do |logs|
      expect_raises(RuntimeError, "boom") do
        monitor.track(sql, [secret] of DB::Any) { raise RuntimeError.new("boom") }
      end

      message = logs.check(:error, /Query failed: boom/).entry.message
      message.should_not contain(secret)
      message.should_not contain("Params:")
    end
  end

  describe "a driver error message that quotes a bound value" do
    failure = ->(monitor : CQL::Performance::Monitor) do
      error = Exception.new("Duplicate entry '#{secret}' for key 'users.email'")
      event = CQL::Telemetry::QueryEvent.new(sql, 1, nil, 1.millisecond, error, CQL::Adapter::SQLite, :insert, nil, nil)
      message = ""
      Log.capture("*") do |logs|
        monitor.record(event, [secret] of DB::Any)
        message = logs.check(:error, /\AQuery failed:/).entry.message
      end
      message
    end

    it "is redacted in the failed statement's log line when include_params is off" do
      message = failure.call(build_monitor.call(false))

      message.should contain("Duplicate entry '?'")
      message.should_not contain(secret)
    end

    it "is logged verbatim when include_params is on" do
      failure.call(build_monitor.call(true)).should contain("Duplicate entry '#{secret}'")
    end
  end

  it "logs bound values once include_params is turned on" do
    monitor = build_monitor.call(false)
    monitor.configure(&.logging.include_params=(true))

    Log.capture("*") do |logs|
      monitor.track(sql, [secret] of DB::Any) { 1 }

      logs.check(:warn, /Parameters: \[secret@example\.com\]/)
    end
  end

  it "truncates a failed statement's bound values at max_param_length" do
    monitor = build_monitor.call(true)
    monitor.configure(&.logging.max_param_length=(10))
    long_value = "a" * 50

    Log.capture("*") do |logs|
      expect_raises(RuntimeError, "boom") do
        monitor.track(sql, [long_value] of DB::Any) { raise RuntimeError.new("boom") }
      end

      logs.check(:error, /Params: \[a{10}\.\.\.\]/).entry.message.should_not contain(long_value)
    end
  end
end

describe "CQL::Performance::Monitor metrics export of bound values" do
  secret = "secret@example.com"

  # The profiler already holds one slow query that bound *secret*.
  build_monitor = ->(include_params : Bool) do
    config = CQL::Performance::Config.new
    config.monitoring.enabled = true
    config.logging.include_params = include_params
    profiler = CQL::Performance::QueryProfiler.new(config.profiling)
    profiler.record_query("SELECT * FROM users WHERE email = ?", [secret] of DB::Any, 1.hour)
    CQL::Performance::Monitor.new(config: config, profiler: profiler)
  end

  it "leaves a slow query's params out of the metrics JSON when include_params is off" do
    json = build_monitor.call(false).metrics.to_json

    slowest = JSON.parse(json)["top_queries"]["slowest_queries"].as_a
    slowest.size.should eq(1)
    slowest.first.as_h.has_key?("params").should be_false
    json.should_not contain(secret)
  end

  describe "a failed slow query whose driver message quotes a bound value" do
    export_failure = ->(include_params : Bool) do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = true
      config.logging.include_params = include_params
      config.profiling.slow_query_threshold = 0.seconds
      monitor = CQL::Performance::Monitor.new(config: config, profiler: CQL::Performance::QueryProfiler.new(config.profiling))
      error = Exception.new("Duplicate entry '#{secret}' for key 'users.email'")
      event = CQL::Telemetry::QueryEvent.new("INSERT INTO users (email) VALUES (?)", 1, nil, 1.millisecond, error, CQL::Adapter::SQLite, :insert, nil, nil)
      monitor.record(event, [secret] of DB::Any)
      monitor.metrics.to_json
    end

    it "is redacted in the metrics JSON when include_params is off" do
      json = export_failure.call(false)

      JSON.parse(json)["top_queries"]["slowest_queries"][0]["error"].should eq("Duplicate entry '?'")
      json.should_not contain(secret)
    end

    it "is exported verbatim when include_params is on" do
      JSON.parse(export_failure.call(true))["top_queries"]["slowest_queries"][0]["error"].should eq("Duplicate entry '#{secret}' for key 'users.email'")
    end
  end

  it "exports a slow query's params in the metrics JSON when include_params is on" do
    json = build_monitor.call(true).metrics.to_json

    JSON.parse(json)["top_queries"]["slowest_queries"][0]["params"].should eq(JSON.parse(%(["#{secret}"])))
  end
end
