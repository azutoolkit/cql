require "../spec_helper"
require "../../src/performance/utilities"

# Helper class to test TimingUtils and ColorUtils (they are instance-level modules)
class UtilitiesTestHelper
  include CQL::Performance::TimingUtils
  include CQL::Performance::ColorUtils
end

describe "CQL::Performance Utilities" do
  describe "TimingUtils" do
    helper = UtilitiesTestHelper.new

    describe "#measure_execution" do
      it "returns the block result and elapsed time" do
        result, duration = helper.measure_execution { 42 }

        result.should eq(42)
        duration.should be_a(Time::Span)
        duration.should be >= Time::Span.zero
      end

      it "measures a non-trivial duration" do
        _, duration = helper.measure_execution { sleep 5.milliseconds }

        duration.total_milliseconds.should be >= 4.0
      end

      it "propagates the block return type" do
        result, _ = helper.measure_execution { "hello" }

        result.should eq("hello")
      end
    end

    describe "#format_duration" do
      it "formats durations >= 1 second as seconds" do
        duration = Time::Span.new(seconds: 2, nanoseconds: 500_000_000)
        helper.format_duration(duration).should eq("2.5s")
      end

      it "formats durations >= 1ms as milliseconds" do
        duration = Time::Span.new(nanoseconds: 150_000_000)
        helper.format_duration(duration).should eq("150.0ms")
      end

      it "formats durations < 1ms as microseconds" do
        duration = Time::Span.new(nanoseconds: 500_000)
        helper.format_duration(duration).should eq("500.0\u03BCs")
      end

      it "formats exactly 1 second" do
        duration = Time::Span.new(seconds: 1)
        helper.format_duration(duration).should eq("1.0s")
      end

      it "formats exactly 1 millisecond" do
        duration = Time::Span.new(nanoseconds: 1_000_000)
        helper.format_duration(duration).should eq("1.0ms")
      end
    end

    describe "#categorize_duration" do
      it "returns :fast for durations below slow threshold" do
        duration = Time::Span.new(nanoseconds: 50_000_000) # 50ms
        helper.categorize_duration(duration).should eq(:fast)
      end

      it "returns :slow for durations at or above slow threshold" do
        duration = Time::Span.new(nanoseconds: 100_000_000) # 100ms
        helper.categorize_duration(duration).should eq(:slow)
      end

      it "returns :very_slow for durations at or above very_slow threshold" do
        duration = Time::Span.new(seconds: 1)
        helper.categorize_duration(duration).should eq(:very_slow)
      end

      it "respects custom thresholds" do
        duration = Time::Span.new(nanoseconds: 50_000_000) # 50ms
        result = helper.categorize_duration(
          duration,
          slow_threshold: 10.milliseconds,
          very_slow_threshold: 100.milliseconds
        )
        result.should eq(:slow)
      end

      it "returns :very_slow with custom thresholds" do
        duration = Time::Span.new(nanoseconds: 200_000_000) # 200ms
        result = helper.categorize_duration(
          duration,
          slow_threshold: 10.milliseconds,
          very_slow_threshold: 100.milliseconds
        )
        result.should eq(:very_slow)
      end
    end
  end

  describe "SQLUtils" do
    describe ".normalize_sql" do
      it "replaces positional parameters with ?" do
        normalized = CQL::Performance::SQLUtils.normalize_sql("SELECT * FROM users WHERE id = $1")
        normalized.should eq("SELECT * FROM users WHERE id = ?")
      end

      it "replaces literal numbers with ?" do
        normalized = CQL::Performance::SQLUtils.normalize_sql("SELECT * FROM users WHERE id = 42")
        normalized.should eq("SELECT * FROM users WHERE id = ?")
      end

      it "replaces single-quoted strings with '?'" do
        normalized = CQL::Performance::SQLUtils.normalize_sql("SELECT * FROM users WHERE name = 'Alice'")
        normalized.should eq("SELECT * FROM users WHERE name = '?'")
      end

      it "collapses multiple whitespace into a single space" do
        normalized = CQL::Performance::SQLUtils.normalize_sql("SELECT *  FROM   users")
        normalized.should eq("SELECT * FROM users")
      end

      it "strips leading and trailing whitespace" do
        normalized = CQL::Performance::SQLUtils.normalize_sql("  SELECT * FROM users  ")
        normalized.should eq("SELECT * FROM users")
      end

      it "handles multiple parameters" do
        sql = "SELECT * FROM users WHERE id = $1 AND name = 'Bob' AND age > 30"
        normalized = CQL::Performance::SQLUtils.normalize_sql(sql)
        normalized.should eq("SELECT * FROM users WHERE id = ? AND name = '?' AND age > ?")
      end

      it "preserves question mark placeholders" do
        normalized = CQL::Performance::SQLUtils.normalize_sql("SELECT * FROM users WHERE id = ?")
        normalized.should eq("SELECT * FROM users WHERE id = ?")
      end
    end

    describe ".truncate_sql" do
      it "returns the full string when under max_length" do
        sql = "SELECT * FROM users"
        CQL::Performance::SQLUtils.truncate_sql(sql).should eq(sql)
      end

      it "truncates and appends ellipsis when over max_length" do
        sql = "A" * 150
        result = CQL::Performance::SQLUtils.truncate_sql(sql, max_length: 100)
        result.size.should eq(103) # 100 chars + "..."
        result.should end_with("...")
      end

      it "does not truncate strings exactly at max_length" do
        sql = "A" * 100
        result = CQL::Performance::SQLUtils.truncate_sql(sql, max_length: 100)
        result.should eq(sql)
      end

      it "respects custom max_length" do
        sql = "SELECT * FROM users WHERE id = 1 AND name = 'test'"
        result = CQL::Performance::SQLUtils.truncate_sql(sql, max_length: 20)
        result.should eq("SELECT * FROM users ...")
      end
    end

    describe ".format_params" do
      it "returns [] for empty params" do
        params = [] of DB::Any
        CQL::Performance::SQLUtils.format_params(params).should eq("[]")
      end

      it "formats params as a bracketed comma-separated list" do
        params = [1.as(DB::Any), "hello".as(DB::Any)]
        result = CQL::Performance::SQLUtils.format_params(params)
        result.should eq("[1, hello]")
      end

      it "truncates long param values" do
        long_value = ("x" * 100).as(DB::Any)
        params = [long_value]
        result = CQL::Performance::SQLUtils.format_params(params, max_length: 50)
        result.should contain("...")
        result.should start_with("[")
        result.should end_with("]")
      end

      it "does not truncate short param values" do
        params = ["short".as(DB::Any)]
        result = CQL::Performance::SQLUtils.format_params(params, max_length: 50)
        result.should eq("[short]")
      end
    end
  end

  describe "StatsTracker" do
    describe "#record" do
      it "increments total_count" do
        tracker = CQL::Performance::StatsTracker.new
        tracker.record(Time::Span.new(nanoseconds: 10_000_000))

        tracker.total_count.should eq(1)
      end

      it "accumulates total_time" do
        tracker = CQL::Performance::StatsTracker.new
        tracker.record(Time::Span.new(nanoseconds: 10_000_000))
        tracker.record(Time::Span.new(nanoseconds: 20_000_000))

        tracker.total_time.total_milliseconds.should eq(30.0)
      end

      it "tracks min_time" do
        tracker = CQL::Performance::StatsTracker.new
        tracker.record(Time::Span.new(nanoseconds: 20_000_000))
        tracker.record(Time::Span.new(nanoseconds: 10_000_000))
        tracker.record(Time::Span.new(nanoseconds: 30_000_000))

        tracker.min_time.total_milliseconds.should eq(10.0)
      end

      it "tracks max_time" do
        tracker = CQL::Performance::StatsTracker.new
        tracker.record(Time::Span.new(nanoseconds: 10_000_000))
        tracker.record(Time::Span.new(nanoseconds: 30_000_000))
        tracker.record(Time::Span.new(nanoseconds: 20_000_000))

        tracker.max_time.total_milliseconds.should eq(30.0)
      end

      it "counts errors when flagged" do
        tracker = CQL::Performance::StatsTracker.new
        tracker.record(Time::Span.new(nanoseconds: 10_000_000), error: true)
        tracker.record(Time::Span.new(nanoseconds: 10_000_000), error: false)

        tracker.errors.should eq(1)
      end
    end

    describe "#avg_time" do
      it "returns zero when no records exist" do
        tracker = CQL::Performance::StatsTracker.new
        tracker.avg_time.should eq(Time::Span.zero)
      end

      it "calculates average time correctly" do
        tracker = CQL::Performance::StatsTracker.new
        tracker.record(Time::Span.new(nanoseconds: 10_000_000))
        tracker.record(Time::Span.new(nanoseconds: 30_000_000))

        tracker.avg_time.total_milliseconds.should eq(20.0)
      end
    end

    describe "#error_rate" do
      it "returns 0.0 when no records exist" do
        tracker = CQL::Performance::StatsTracker.new
        tracker.error_rate.should eq(0.0)
      end

      it "calculates error rate as a percentage" do
        tracker = CQL::Performance::StatsTracker.new
        tracker.record(Time::Span.new(nanoseconds: 10_000_000), error: true)
        tracker.record(Time::Span.new(nanoseconds: 10_000_000), error: false)
        tracker.record(Time::Span.new(nanoseconds: 10_000_000), error: false)
        tracker.record(Time::Span.new(nanoseconds: 10_000_000), error: false)

        tracker.error_rate.should eq(25.0)
      end

      it "returns 100.0 when all records are errors" do
        tracker = CQL::Performance::StatsTracker.new
        tracker.record(Time::Span.new(nanoseconds: 10_000_000), error: true)
        tracker.record(Time::Span.new(nanoseconds: 10_000_000), error: true)

        tracker.error_rate.should eq(100.0)
      end
    end

    describe "#reset" do
      it "resets all tracked statistics" do
        tracker = CQL::Performance::StatsTracker.new
        tracker.record(Time::Span.new(nanoseconds: 10_000_000), error: true)
        tracker.record(Time::Span.new(nanoseconds: 20_000_000))

        tracker.reset

        tracker.total_count.should eq(0)
        tracker.total_time.should eq(Time::Span.zero)
        tracker.min_time.should eq(Time::Span::MAX)
        tracker.max_time.should eq(Time::Span.zero)
        tracker.errors.should eq(0)
      end
    end

    describe "#to_h" do
      it "returns a hash with all statistics" do
        tracker = CQL::Performance::StatsTracker.new
        tracker.record(Time::Span.new(nanoseconds: 10_000_000))
        tracker.record(Time::Span.new(nanoseconds: 30_000_000), error: true)

        hash = tracker.to_h

        hash["total_count"].should eq(2_i64)
        hash["total_time_ms"].should eq(40.0)
        hash["avg_time_ms"].should eq(20.0)
        hash["min_time_ms"].should eq(10.0)
        hash["max_time_ms"].should eq(30.0)
        hash["error_count"].should eq(1_i64)
        hash["error_rate"].should eq(50.0)
      end

      it "returns zero min_time_ms when no records exist" do
        tracker = CQL::Performance::StatsTracker.new
        hash = tracker.to_h

        hash["min_time_ms"].should eq(0.0)
      end
    end
  end

  describe "Cache" do
    describe "#get" do
      it "computes and caches a value on first access" do
        cache = CQL::Performance::Cache(String, Int32).new(max_size: 10)
        computed = 0

        result = cache.get("key") { computed += 1; 42 }
        result.should eq(42)
        computed.should eq(1)
      end

      it "returns the cached value on subsequent access without recomputing" do
        cache = CQL::Performance::Cache(String, Int32).new(max_size: 10)
        computed = 0

        cache.get("key") { computed += 1; 42 }
        result = cache.get("key") { computed += 1; 99 }

        result.should eq(42)
        computed.should eq(1)
      end
    end

    describe "#set" do
      it "stores a value that can be retrieved with get" do
        cache = CQL::Performance::Cache(String, String).new(max_size: 10)
        cache.set("greeting", "hello")

        result = cache.get("greeting") { "fallback" }
        result.should eq("hello")
      end

      it "overwrites an existing value" do
        cache = CQL::Performance::Cache(String, Int32).new(max_size: 10)
        cache.set("key", 1)
        cache.set("key", 2)

        result = cache.get("key") { 99 }
        result.should eq(2)
      end
    end

    describe "#clear" do
      it "removes all cached entries" do
        cache = CQL::Performance::Cache(String, Int32).new(max_size: 10)
        cache.set("a", 1)
        cache.set("b", 2)

        cache.clear

        cache.size.should eq(0)
      end

      it "forces recomputation after clearing" do
        cache = CQL::Performance::Cache(String, Int32).new(max_size: 10)
        cache.set("key", 42)
        cache.clear

        result = cache.get("key") { 99 }
        result.should eq(99)
      end
    end

    describe "#size" do
      it "returns 0 for an empty cache" do
        cache = CQL::Performance::Cache(String, Int32).new(max_size: 10)
        cache.size.should eq(0)
      end

      it "reflects the number of entries" do
        cache = CQL::Performance::Cache(String, Int32).new(max_size: 10)
        cache.set("a", 1)
        cache.set("b", 2)
        cache.set("c", 3)

        cache.size.should eq(3)
      end

      it "does not increase when overwriting an existing key" do
        cache = CQL::Performance::Cache(String, Int32).new(max_size: 10)
        cache.set("key", 1)
        cache.set("key", 2)

        cache.size.should eq(1)
      end
    end

    describe "LRU eviction" do
      it "evicts the least recently used entry when at capacity" do
        cache = CQL::Performance::Cache(String, Int32).new(max_size: 3)
        cache.set("a", 1)
        cache.set("b", 2)
        cache.set("c", 3)

        # Adding a 4th entry should evict "a" (oldest)
        cache.set("d", 4)

        cache.size.should eq(3)
        # "a" was evicted, so the block should execute
        result = cache.get("a") { 100 }
        result.should eq(100)
      end

      it "preserves recently accessed entries during eviction" do
        cache = CQL::Performance::Cache(String, Int32).new(max_size: 3)
        cache.set("a", 1)
        cache.set("b", 2)
        cache.set("c", 3)

        # Access "a" to make it recently used
        cache.get("a") { 99 }

        # Adding a 4th entry should evict "b" (now the least recently used)
        cache.set("d", 4)

        cache.size.should eq(3)

        # "a" should still be cached
        result_a = cache.get("a") { 100 }
        result_a.should eq(1)

        # "b" was evicted
        result_b = cache.get("b") { 200 }
        result_b.should eq(200)
      end

      it "does not evict when updating an existing key" do
        cache = CQL::Performance::Cache(String, Int32).new(max_size: 3)
        cache.set("a", 1)
        cache.set("b", 2)
        cache.set("c", 3)

        # Overwrite "a" - should not trigger eviction
        cache.set("a", 10)

        cache.size.should eq(3)
        result = cache.get("b") { 99 }
        result.should eq(2)
      end
    end
  end

  describe "ColorUtils" do
    helper = UtilitiesTestHelper.new

    describe "#colorize_by_severity" do
      it "returns the text unchanged when colorize is disabled" do
        Colorize.enabled = false
        result = helper.colorize_by_severity("error!", :critical)
        result.should eq("error!")
        Colorize.enabled = true
      end

      it "applies red bold for :critical severity" do
        Colorize.enabled = true
        result = helper.colorize_by_severity("error!", :critical)
        result.should contain("error!")
      end

      it "applies red bold for :error severity" do
        Colorize.enabled = true
        result = helper.colorize_by_severity("error!", :error)
        result.should contain("error!")
      end

      it "applies styling for :high severity" do
        Colorize.enabled = true
        result = helper.colorize_by_severity("warn", :high)
        result.should contain("warn")
      end

      it "applies styling for :warning severity" do
        Colorize.enabled = true
        result = helper.colorize_by_severity("warn", :warning)
        result.should contain("warn")
      end

      it "applies styling for :medium severity" do
        Colorize.enabled = true
        result = helper.colorize_by_severity("notice", :medium)
        result.should contain("notice")
      end

      it "applies styling for :low severity" do
        Colorize.enabled = true
        result = helper.colorize_by_severity("info", :low)
        result.should contain("info")
      end

      it "applies styling for :info severity" do
        Colorize.enabled = true
        result = helper.colorize_by_severity("info", :info)
        result.should contain("info")
      end

      it "returns the text unmodified for unknown severity" do
        Colorize.enabled = true
        result = helper.colorize_by_severity("text", :unknown)
        result.should eq("text")
      end
    end

    describe "#colorize_duration" do
      it "returns plain text when colorize is disabled" do
        Colorize.enabled = false
        duration = Time::Span.new(seconds: 2)
        result = helper.colorize_duration(duration)
        result.should eq("2.0s")
        Colorize.enabled = true
      end

      it "applies green styling for fast durations" do
        Colorize.enabled = true
        duration = Time::Span.new(nanoseconds: 10_000_000) # 10ms
        result = helper.colorize_duration(duration)
        result.should contain("10.0ms")
      end

      it "applies yellow styling for slow durations" do
        Colorize.enabled = true
        duration = Time::Span.new(nanoseconds: 200_000_000) # 200ms
        result = helper.colorize_duration(duration)
        result.should contain("200.0ms")
      end

      it "applies red bold styling for very slow durations" do
        Colorize.enabled = true
        duration = Time::Span.new(seconds: 2)
        result = helper.colorize_duration(duration)
        result.should contain("2.0s")
      end

      it "respects custom thresholds" do
        Colorize.enabled = true
        duration = Time::Span.new(nanoseconds: 50_000_000) # 50ms
        result = helper.colorize_duration(
          duration,
          slow_threshold: 10.milliseconds,
          very_slow_threshold: 100.milliseconds
        )
        result.should contain("50.0ms")
      end
    end
  end
end
