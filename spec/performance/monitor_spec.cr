require "../spec_helper"

describe CQL::Performance::Monitor do
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
        begin
          monitor.monitor_query("SELECT bad") { raise RuntimeError.new("fail") }
        rescue RuntimeError
        end
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
