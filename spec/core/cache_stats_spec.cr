require "spec"
require "../../src/cache_stats"

describe CQL::CacheStats do
  describe "#initialize" do
    it "initializes with zero values" do
      stats = CQL::CacheStats.new

      stats.hits.should eq 0_i64
      stats.misses.should eq 0_i64
      stats.total_requests.should eq 0_i64
      stats.total_cache_time.should eq 0.0
      stats.total_execution_time.should eq 0.0
      stats.start_time.should be > 0_i64
    end

    it "sets start_time to current unix timestamp" do
      before_time = Time.utc.to_unix
      stats = CQL::CacheStats.new
      after_time = Time.utc.to_unix

      stats.start_time.should be >= before_time
      stats.start_time.should be <= after_time
    end
  end

  describe "#hit_rate" do
    it "returns 0.0 when no requests" do
      stats = CQL::CacheStats.new
      stats.hit_rate.should eq 0.0
    end

    it "returns 100.0 when all requests are hits" do
      stats = CQL::CacheStats.new
      stats.hits = 10_i64
      stats.total_requests = 10_i64

      stats.hit_rate.should eq 100.0
    end

    it "returns 0.0 when all requests are misses" do
      stats = CQL::CacheStats.new
      stats.misses = 10_i64
      stats.total_requests = 10_i64

      stats.hit_rate.should eq 0.0
    end

    it "returns correct percentage for mixed hits and misses" do
      stats = CQL::CacheStats.new
      stats.hits = 7_i64
      stats.misses = 3_i64
      stats.total_requests = 10_i64

      stats.hit_rate.should eq 70.0
    end

    it "handles fractional percentages" do
      stats = CQL::CacheStats.new
      stats.hits = 1_i64
      stats.total_requests = 3_i64

      stats.hit_rate.should be_close(33.33333333333333, 0.0001)
    end
  end

  describe "#miss_rate" do
    it "returns 0.0 when no requests" do
      stats = CQL::CacheStats.new
      stats.miss_rate.should eq 0.0
    end

    it "returns 100.0 when all requests are misses" do
      stats = CQL::CacheStats.new
      stats.misses = 10_i64
      stats.total_requests = 10_i64

      stats.miss_rate.should eq 100.0
    end

    it "returns 0.0 when all requests are hits" do
      stats = CQL::CacheStats.new
      stats.hits = 10_i64
      stats.total_requests = 10_i64

      stats.miss_rate.should eq 0.0
    end

    it "returns correct percentage for mixed hits and misses" do
      stats = CQL::CacheStats.new
      stats.hits = 3_i64
      stats.misses = 7_i64
      stats.total_requests = 10_i64

      stats.miss_rate.should eq 70.0
    end

    it "hit_rate and miss_rate sum to 100.0" do
      stats = CQL::CacheStats.new
      stats.hits = 3_i64
      stats.misses = 7_i64
      stats.total_requests = 10_i64

      (stats.hit_rate + stats.miss_rate).should be_close(100.0, 0.0001)
    end
  end

  describe "#average_cache_time" do
    it "returns 0.0 when no requests" do
      stats = CQL::CacheStats.new
      stats.average_cache_time.should eq 0.0
    end

    it "returns correct average for single request" do
      stats = CQL::CacheStats.new
      stats.total_cache_time = 0.5
      stats.total_requests = 1_i64

      stats.average_cache_time.should eq 0.5
    end

    it "returns correct average for multiple requests" do
      stats = CQL::CacheStats.new
      stats.total_cache_time = 1.5
      stats.total_requests = 3_i64

      stats.average_cache_time.should eq 0.5
    end

    it "handles fractional averages" do
      stats = CQL::CacheStats.new
      stats.total_cache_time = 1.0
      stats.total_requests = 3_i64

      stats.average_cache_time.should be_close(0.3333333333333333, 0.0001)
    end
  end

  describe "#average_execution_time" do
    it "returns 0.0 when no requests" do
      stats = CQL::CacheStats.new
      stats.average_execution_time.should eq 0.0
    end

    it "returns correct average for single request" do
      stats = CQL::CacheStats.new
      stats.total_execution_time = 2.0
      stats.total_requests = 1_i64

      stats.average_execution_time.should eq 2.0
    end

    it "returns correct average for multiple requests" do
      stats = CQL::CacheStats.new
      stats.total_execution_time = 6.0
      stats.total_requests = 2_i64

      stats.average_execution_time.should eq 3.0
    end

    it "handles fractional averages" do
      stats = CQL::CacheStats.new
      stats.total_execution_time = 5.0
      stats.total_requests = 4_i64

      stats.average_execution_time.should eq 1.25
    end
  end

  describe "#uptime" do
    it "returns Time::Span" do
      stats = CQL::CacheStats.new
      stats.uptime.should be_a(Time::Span)
    end

    it "returns positive duration" do
      stats = CQL::CacheStats.new
      stats.uptime.total_seconds.should be >= 0.0
    end

    it "increases over time" do
      stats = CQL::CacheStats.new
      initial_uptime = stats.uptime.total_seconds

      sleep(0.1.seconds) # Small delay to ensure time passes

      stats.uptime.total_seconds.should be >= initial_uptime
    end

    it "calculates correct duration" do
      start_time = Time.utc.to_unix
      stats = CQL::CacheStats.new

      # The uptime should be very close to the difference between now and start_time
      expected_uptime = Time.utc.to_unix - start_time
      actual_uptime = stats.uptime.total_seconds.to_i

      (actual_uptime - expected_uptime).abs.should be <= 1
    end
  end

  describe "#reset" do
    it "resets all counters to zero" do
      stats = CQL::CacheStats.new

      # Set some values
      stats.hits = 10_i64
      stats.misses = 5_i64
      stats.total_requests = 15_i64
      stats.total_cache_time = 1.5
      stats.total_execution_time = 3.0

      # Reset
      stats.reset

      stats.hits.should eq 0_i64
      stats.misses.should eq 0_i64
      stats.total_requests.should eq 0_i64
      stats.total_cache_time.should eq 0.0
      stats.total_execution_time.should eq 0.0
    end

    it "resets start_time to current time" do
      stats = CQL::CacheStats.new
      original_start_time = stats.start_time

      sleep(0.1.seconds) # Small delay

      stats.reset

      stats.start_time.should be >= original_start_time
    end

    it "resets calculated values" do
      stats = CQL::CacheStats.new

      # Set values that affect calculations
      stats.hits = 5_i64
      stats.total_requests = 10_i64
      stats.total_cache_time = 1.0
      stats.total_execution_time = 2.0

      # Verify calculations work
      stats.hit_rate.should eq 50.0
      stats.average_cache_time.should eq 0.1
      stats.average_execution_time.should eq 0.2

      # Reset
      stats.reset

      # Verify calculations are reset
      stats.hit_rate.should eq 0.0
      stats.average_cache_time.should eq 0.0
      stats.average_execution_time.should eq 0.0
    end
  end

  describe "property access" do
    it "allows reading and writing hits" do
      stats = CQL::CacheStats.new
      stats.hits = 42_i64
      stats.hits.should eq 42_i64
    end

    it "allows reading and writing misses" do
      stats = CQL::CacheStats.new
      stats.misses = 24_i64
      stats.misses.should eq 24_i64
    end

    it "allows reading and writing total_requests" do
      stats = CQL::CacheStats.new
      stats.total_requests = 100_i64
      stats.total_requests.should eq 100_i64
    end

    it "allows reading and writing total_cache_time" do
      stats = CQL::CacheStats.new
      stats.total_cache_time = 1.5
      stats.total_cache_time.should eq 1.5
    end

    it "allows reading and writing total_execution_time" do
      stats = CQL::CacheStats.new
      stats.total_execution_time = 2.5
      stats.total_execution_time.should eq 2.5
    end

    it "allows reading start_time" do
      stats = CQL::CacheStats.new
      stats.start_time.should be > 0_i64
    end
  end

  describe "edge cases" do
    it "handles very large numbers" do
      stats = CQL::CacheStats.new
      stats.hits = Int64::MAX
      stats.total_requests = Int64::MAX

      stats.hit_rate.should eq 100.0
    end

    it "handles very small time values" do
      stats = CQL::CacheStats.new
      stats.total_cache_time = 0.000001
      stats.total_requests = 1_i64

      stats.average_cache_time.should eq 0.000001
    end

    it "handles zero time values" do
      stats = CQL::CacheStats.new
      stats.total_cache_time = 0.0
      stats.total_execution_time = 0.0
      stats.total_requests = 10_i64

      stats.average_cache_time.should eq 0.0
      stats.average_execution_time.should eq 0.0
    end
  end
end
