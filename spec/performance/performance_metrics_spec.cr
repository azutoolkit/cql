require "../spec_helper"
require "../../src/performance/performance_metrics"
require "../../src/performance/query_profiler"
require "../../src/performance/n_plus_one_detector"
require "../../src/cache/cache"

describe "CQL::Performance::PerformanceMetrics" do
  describe "QueryMetrics struct" do
    it "initializes with correct values" do
      metrics = CQL::Performance::PerformanceMetrics::QueryMetrics.new(
        100_i64, 10_i64, 5_i64, 2_i64,
        Time::Span.new(seconds: 30), Time::Span.new(seconds: 0, nanoseconds: 300_000_000),
        Time::Span.new(seconds: 0, nanoseconds: 100_000_000), Time::Span.new(seconds: 1, nanoseconds: 0),
        2.0, 10.0, 10.0
      )

      metrics.total_queries.should eq(100_i64)
      metrics.slow_queries.should eq(10_i64)
      metrics.very_slow_queries.should eq(5_i64)
      metrics.error_queries.should eq(2_i64)
      metrics.error_rate.should eq(2.0)
      metrics.queries_per_second.should eq(10.0)
      metrics.slow_query_rate.should eq(10.0)
    end

    it "converts to hash correctly" do
      metrics = CQL::Performance::PerformanceMetrics::QueryMetrics.new(
        100_i64, 10_i64, 5_i64, 2_i64,
        Time::Span.new(seconds: 30), Time::Span.new(seconds: 0, nanoseconds: 300_000_000),
        Time::Span.new(seconds: 0, nanoseconds: 100_000_000), Time::Span.new(seconds: 1, nanoseconds: 0),
        2.0, 10.0, 10.0
      )

      hash = metrics.to_h
      hash["total_queries"].should eq(100_i64)
      hash["slow_queries"].should eq(10_i64)
      hash["very_slow_queries"].should eq(5_i64)
      hash["error_queries"].should eq(2_i64)
      hash["total_execution_time_ms"].should eq(30000.0)
      hash["avg_execution_time_ms"].should eq(300.0)
      hash["min_execution_time_ms"].should eq(100.0)
      hash["max_execution_time_ms"].should eq(1000.0)
      hash["error_rate_percent"].should eq(2.0)
      hash["queries_per_second"].should eq(10.0)
      hash["slow_query_rate_percent"].should eq(10.0)
    end
  end

  describe "NPlusOneMetrics struct" do
    it "initializes with correct values" do
      metrics = CQL::Performance::PerformanceMetrics::NPlusOneMetrics.new(
        50, 5, 10, 15, 20, 1000_i64, 20.0, 100, 95.0
      )

      metrics.total_patterns.should eq(50)
      metrics.critical_patterns.should eq(5)
      metrics.high_patterns.should eq(10)
      metrics.medium_patterns.should eq(15)
      metrics.low_patterns.should eq(20)
      metrics.total_repetitions.should eq(1000_i64)
      metrics.avg_repetitions_per_pattern.should eq(20.0)
      metrics.max_repetitions.should eq(100)
      metrics.detection_rate.should eq(95.0)
    end

    it "converts to hash correctly" do
      metrics = CQL::Performance::PerformanceMetrics::NPlusOneMetrics.new(
        50, 5, 10, 15, 20, 1000_i64, 20.0, 100, 95.0
      )

      hash = metrics.to_h
      hash["total_patterns"].should eq(50)
      hash["critical_patterns"].should eq(5)
      hash["high_patterns"].should eq(10)
      hash["medium_patterns"].should eq(15)
      hash["low_patterns"].should eq(20)
      hash["total_repetitions"].should eq(1000_i64)
      hash["avg_repetitions_per_pattern"].should eq(20.0)
      hash["max_repetitions"].should eq(100)
      hash["detection_rate_percent"].should eq(95.0)
    end
  end

  describe "CacheMetrics struct" do
    it "initializes with correct values" do
      metrics = CQL::Performance::PerformanceMetrics::CacheMetrics.new(
        800_i64, 200_i64, 100, 1000, 80.0, 20.0, 50_i64
      )

      metrics.cache_hits.should eq(800_i64)
      metrics.cache_misses.should eq(200_i64)
      metrics.cache_size.should eq(100)
      metrics.max_cache_size.should eq(1000)
      metrics.hit_rate.should eq(80.0)
      metrics.miss_rate.should eq(20.0)
      metrics.evictions.should eq(50_i64)
    end

    it "converts to hash correctly" do
      metrics = CQL::Performance::PerformanceMetrics::CacheMetrics.new(
        800_i64, 200_i64, 100, 1000, 80.0, 20.0, 50_i64
      )

      hash = metrics.to_h
      hash["cache_hits"].should eq(800_i64)
      hash["cache_misses"].should eq(200_i64)
      hash["cache_size"].should eq(100)
      hash["max_cache_size"].should eq(1000)
      hash["hit_rate_percent"].should eq(80.0)
      hash["miss_rate_percent"].should eq(20.0)
      hash["evictions"].should eq(50_i64)
    end
  end

  describe "SystemMetrics struct" do
    it "initializes with correct values" do
      uptime = Time::Span.new(seconds: 3600) # 1 hour
      metrics = CQL::Performance::PerformanceMetrics::SystemMetrics.new(
        uptime, 512.5, 75.0, 25, 100, 25.0
      )

      metrics.uptime.should eq(uptime)
      metrics.memory_usage_mb.should eq(512.5)
      metrics.cpu_usage_percent.should eq(75.0)
      metrics.active_connections.should eq(25)
      metrics.max_connections.should eq(100)
      metrics.connection_pool_utilization.should eq(25.0)
    end

    it "converts to hash correctly" do
      uptime = Time::Span.new(seconds: 3600) # 1 hour
      metrics = CQL::Performance::PerformanceMetrics::SystemMetrics.new(
        uptime, 512.5, 75.0, 25, 100, 25.0
      )

      hash = metrics.to_h
      hash["uptime_seconds"].should eq(3600.0)
      hash["memory_usage_mb"].should eq(512.5)
      hash["cpu_usage_percent"].should eq(75.0)
      hash["active_connections"].should eq(25)
      hash["max_connections"].should eq(100)
      hash["connection_pool_utilization_percent"].should eq(25.0)
    end
  end

  describe "HealthMetrics struct" do
    it "initializes with correct values" do
      metrics = CQL::Performance::PerformanceMetrics::HealthMetrics.new(
        85, 90, 80, 75, 95, 2, 5, 8, 10, 25
      )

      metrics.overall_health_score.should eq(85)
      metrics.query_health_score.should eq(90)
      metrics.n_plus_one_health_score.should eq(80)
      metrics.cache_health_score.should eq(75)
      metrics.system_health_score.should eq(95)
      metrics.critical_issues.should eq(2)
      metrics.high_issues.should eq(5)
      metrics.medium_issues.should eq(8)
      metrics.low_issues.should eq(10)
      metrics.total_issues.should eq(25)
    end

    it "converts to hash correctly" do
      metrics = CQL::Performance::PerformanceMetrics::HealthMetrics.new(
        85, 90, 80, 75, 95, 2, 5, 8, 10, 25
      )

      hash = metrics.to_h
      hash["overall_health_score"].should eq(85)
      hash["query_health_score"].should eq(90)
      hash["n_plus_one_health_score"].should eq(80)
      hash["cache_health_score"].should eq(75)
      hash["system_health_score"].should eq(95)
      hash["critical_issues"].should eq(2)
      hash["high_issues"].should eq(5)
      hash["medium_issues"].should eq(8)
      hash["low_issues"].should eq(10)
      hash["total_issues"].should eq(25)
    end
  end

  describe "TopQueries struct" do
    it "initializes with correct values" do
      slowest_queries = [] of CQL::Performance::QueryData
      most_frequent = [] of NamedTuple(sql: String, count: Int64, avg_time: Time::Span)
      highest_error = [] of NamedTuple(sql: String, errors: Int64, error_rate: Float64)
      most_expensive = [] of NamedTuple(sql: String, total_time: Time::Span, count: Int64)

      top_queries = CQL::Performance::PerformanceMetrics::TopQueries.new(
        slowest_queries, most_frequent, highest_error, most_expensive
      )

      top_queries.slowest_queries.should eq(slowest_queries)
      top_queries.most_frequent_queries.should eq(most_frequent)
      top_queries.highest_error_queries.should eq(highest_error)
      top_queries.most_expensive_queries.should eq(most_expensive)
    end

    it "converts to hash correctly" do
      slowest_queries = [] of CQL::Performance::QueryData
      most_frequent = [] of NamedTuple(sql: String, count: Int64, avg_time: Time::Span)
      highest_error = [] of NamedTuple(sql: String, errors: Int64, error_rate: Float64)
      most_expensive = [] of NamedTuple(sql: String, total_time: Time::Span, count: Int64)

      top_queries = CQL::Performance::PerformanceMetrics::TopQueries.new(
        slowest_queries, most_frequent, highest_error, most_expensive
      )

      hash = top_queries.to_h
      hash["slowest_queries"].should be_a(JSON::Any)
      hash["most_frequent_queries"].should be_a(JSON::Any)
      hash["highest_error_queries"].should be_a(JSON::Any)
      hash["most_expensive_queries"].should be_a(JSON::Any)
    end
  end

  describe "PerformancePatterns struct" do
    it "initializes with correct values" do
      n_plus_one_patterns = [] of CQL::Performance::NPlusOnePattern
      query_patterns = [] of NamedTuple(pattern: String, count: Int64, avg_time: Time::Span)
      time_distribution = {"fast" => 100_i64, "slow" => 20_i64, "very_slow" => 5_i64}
      error_patterns = [] of NamedTuple(error_type: String, count: Int64, percentage: Float64)

      patterns = CQL::Performance::PerformanceMetrics::PerformancePatterns.new(
        n_plus_one_patterns, query_patterns, time_distribution, error_patterns
      )

      patterns.n_plus_one_patterns.should eq(n_plus_one_patterns)
      patterns.query_patterns.should eq(query_patterns)
      patterns.time_distribution.should eq(time_distribution)
      patterns.error_patterns.should eq(error_patterns)
    end

    it "converts to hash correctly" do
      n_plus_one_patterns = [] of CQL::Performance::NPlusOnePattern
      query_patterns = [] of NamedTuple(pattern: String, count: Int64, avg_time: Time::Span)
      time_distribution = {"fast" => 100_i64, "slow" => 20_i64, "very_slow" => 5_i64}
      error_patterns = [] of NamedTuple(error_type: String, count: Int64, percentage: Float64)

      patterns = CQL::Performance::PerformanceMetrics::PerformancePatterns.new(
        n_plus_one_patterns, query_patterns, time_distribution, error_patterns
      )

      hash = patterns.to_h
      hash["n_plus_one_patterns"].should be_a(JSON::Any)
      hash["query_patterns"].should be_a(JSON::Any)
      hash["time_distribution"].should be_a(JSON::Any)
      hash["error_patterns"].should be_a(JSON::Any)
    end
  end

  describe "PerformanceMetrics main class" do
    it "initializes with all required components" do
      query_metrics = CQL::Performance::PerformanceMetrics::QueryMetrics.new(
        100_i64, 10_i64, 5_i64, 2_i64,
        Time::Span.zero, Time::Span.zero, Time::Span.zero, Time::Span.zero,
        2.0, 10.0, 10.0
      )
      n_plus_one_metrics = CQL::Performance::PerformanceMetrics::NPlusOneMetrics.new(
        50, 5, 10, 15, 20, 1000_i64, 20.0, 100, 95.0
      )
      cache_metrics = CQL::Performance::PerformanceMetrics::CacheMetrics.new(
        800_i64, 200_i64, 100, 1000, 80.0, 20.0, 50_i64
      )
      system_metrics = CQL::Performance::PerformanceMetrics::SystemMetrics.new(
        Time::Span.zero, 512.5, 75.0, 25, 100, 25.0
      )
      health_metrics = CQL::Performance::PerformanceMetrics::HealthMetrics.new(
        85, 90, 80, 75, 95, 2, 5, 8, 10, 25
      )
      top_queries = CQL::Performance::PerformanceMetrics::TopQueries.new(
        [] of CQL::Performance::QueryData,
        [] of NamedTuple(sql: String, count: Int64, avg_time: Time::Span),
        [] of NamedTuple(sql: String, errors: Int64, error_rate: Float64),
        [] of NamedTuple(sql: String, total_time: Time::Span, count: Int64)
      )
      patterns = CQL::Performance::PerformanceMetrics::PerformancePatterns.new(
        [] of CQL::Performance::NPlusOnePattern,
        [] of NamedTuple(pattern: String, count: Int64, avg_time: Time::Span),
        {} of String => Int64,
        [] of NamedTuple(error_type: String, count: Int64, percentage: Float64)
      )
      issues = [] of CQL::Performance::Issue

      metrics = CQL::Performance::PerformanceMetrics.new(
        query_metrics, n_plus_one_metrics, cache_metrics, system_metrics,
        health_metrics, top_queries, patterns, issues
      )

      metrics.query_metrics.should eq(query_metrics)
      metrics.n_plus_one_metrics.should eq(n_plus_one_metrics)
      metrics.cache_metrics.should eq(cache_metrics)
      metrics.system_metrics.should eq(system_metrics)
      metrics.health_metrics.should eq(health_metrics)
      metrics.top_queries.should eq(top_queries)
      metrics.patterns.should eq(patterns)
      metrics.issues.should eq(issues)
      metrics.timestamp.should be_a(Time)
      metrics.collection_duration.should be_a(Time::Span)
    end

    it "creates from components with nil values" do
      metrics = CQL::Performance::PerformanceMetrics.from_components

      metrics.query_metrics.total_queries.should eq(0_i64)
      metrics.n_plus_one_metrics.total_patterns.should eq(0)
      metrics.cache_metrics.cache_hits.should eq(0_i64)
      metrics.health_metrics.overall_health_score.should eq(100)
      metrics.issues.should be_empty
    end

    it "converts to hash correctly" do
      metrics = CQL::Performance::PerformanceMetrics.from_components
      hash = metrics.to_h

      hash["timestamp"].should be_a(JSON::Any)
      hash["collection_duration_seconds"].should be_a(JSON::Any)
      hash["query_metrics"].should be_a(JSON::Any)
      hash["n_plus_one_metrics"].should be_a(JSON::Any)
      hash["cache_metrics"].should be_a(JSON::Any)
      hash["system_metrics"].should be_a(JSON::Any)
      hash["health_metrics"].should be_a(JSON::Any)
      hash["top_queries"].should be_a(JSON::Any)
      hash["patterns"].should be_a(JSON::Any)
      hash["issues"].should be_a(JSON::Any)
    end

    it "converts to JSON correctly" do
      metrics = CQL::Performance::PerformanceMetrics.from_components
      json = metrics.to_json

      json.should be_a(String)
      json.should contain("timestamp")
      json.should contain("query_metrics")
      json.should contain("n_plus_one_metrics")
      json.should contain("cache_metrics")
      json.should contain("system_metrics")
      json.should contain("health_metrics")
      json.should contain("top_queries")
      json.should contain("patterns")
      json.should contain("issues")
    end

    it "provides summary metrics" do
      metrics = CQL::Performance::PerformanceMetrics.from_components
      summary = metrics.summary

      summary.has_key?("total_queries").should be_true
      summary.has_key?("slow_queries").should be_true
      summary.has_key?("error_rate_percent").should be_true
      summary.has_key?("avg_query_time_ms").should be_true
      summary.has_key?("n_plus_one_patterns").should be_true
      summary.has_key?("health_score").should be_true
      summary.has_key?("total_issues").should be_true
      summary.has_key?("uptime_seconds").should be_true
    end

    it "checks if performance is healthy" do
      metrics = CQL::Performance::PerformanceMetrics.from_components
      metrics.healthy?.should be_true # Default health score is 100
    end

    it "filters critical issues" do
      metrics = CQL::Performance::PerformanceMetrics.from_components
      critical_issues = metrics.critical_issues

      critical_issues.should be_a(Array(CQL::Performance::Issue))
    end

    it "filters high priority issues" do
      metrics = CQL::Performance::PerformanceMetrics.from_components
      high_priority_issues = metrics.high_priority_issues

      high_priority_issues.should be_a(Array(CQL::Performance::Issue))
    end

    it "filters issues by type" do
      metrics = CQL::Performance::PerformanceMetrics.from_components
      issues_by_type = metrics.issues_by_type(:performance)

      issues_by_type.should be_a(Array(CQL::Performance::Issue))
    end

    it "filters issues by severity" do
      metrics = CQL::Performance::PerformanceMetrics.from_components
      issues_by_severity = metrics.issues_by_severity(:critical)

      issues_by_severity.should be_a(Array(CQL::Performance::Issue))
    end

    it "gets slowest queries with limit" do
      metrics = CQL::Performance::PerformanceMetrics.from_components
      slowest_queries = metrics.slowest_queries(5)

      slowest_queries.should be_a(Array(CQL::Performance::QueryData))
    end

    it "gets most frequent queries with limit" do
      metrics = CQL::Performance::PerformanceMetrics.from_components
      most_frequent = metrics.most_frequent_queries(5)

      most_frequent.should be_a(Array(NamedTuple(sql: String, count: Int64, avg_time: Time::Span)))
    end

    it "filters N+1 patterns by severity" do
      metrics = CQL::Performance::PerformanceMetrics.from_components

      critical_patterns = metrics.n_plus_one_patterns_by_severity(:critical)
      high_patterns = metrics.n_plus_one_patterns_by_severity(:high)
      medium_patterns = metrics.n_plus_one_patterns_by_severity(:medium)
      low_patterns = metrics.n_plus_one_patterns_by_severity(:low)

      critical_patterns.should be_a(Array(CQL::Performance::NPlusOnePattern))
      high_patterns.should be_a(Array(CQL::Performance::NPlusOnePattern))
      medium_patterns.should be_a(Array(CQL::Performance::NPlusOnePattern))
      low_patterns.should be_a(Array(CQL::Performance::NPlusOnePattern))
    end
  end

  describe "Extension methods" do
    describe "QueryData" do
      it "converts to hash correctly" do
        query_data = CQL::Performance::QueryData.new(
          "SELECT * FROM users WHERE id = ?",
          [1.as(DB::Any)],
          Time::Span.new(seconds: 0, nanoseconds: 150_000_000),
          1_i64,
          nil
        )

        hash = query_data.to_h
        hash["sql"].should eq("SELECT * FROM users WHERE id = ?")
        hash["params"].should be_a(JSON::Any)
        hash["execution_time_ms"].should eq(150.0)
        hash["timestamp"].should be_a(JSON::Any)
        hash["rows_affected"].should eq(1_i64)
        hash["error"].should eq("")
        hash["normalized_sql"].should be_a(JSON::Any)
      end
    end

    describe "NPlusOnePattern" do
      it "converts to hash correctly" do
        pattern = CQL::Performance::NPlusOnePattern.new(
          "SELECT * FROM users",
          "SELECT * FROM posts WHERE user_id = ?",
          25
        )

        hash = pattern.to_h
        hash["parent_query"].should eq("SELECT * FROM users")
        hash["repeated_query"].should eq("SELECT * FROM posts WHERE user_id = ?")
        hash["repetition_count"].should eq(25)
        hash["timestamp"].should be_a(JSON::Any)
      end
    end

    describe "Issue" do
      it "converts to hash correctly" do
        issue = CQL::Performance::Issue.new(
          :performance,
          :high,
          "Slow query detected",
          {"query" => "SELECT * FROM users", "time" => "500ms"},
          Time.utc
        )

        hash = issue.to_h
        hash["type"].should eq("performance")
        hash["severity"].should eq("high")
        hash["message"].should eq("Slow query detected")
        hash["details"].should be_a(JSON::Any)
        hash["timestamp"].should be_a(JSON::Any)
      end
    end
  end

  describe "to_json_any helper method" do
    it "handles primitive types" do
      CQL::Performance::PerformanceMetrics.to_json_any("test").should be_a(JSON::Any)
      CQL::Performance::PerformanceMetrics.to_json_any(42).should be_a(JSON::Any)
      CQL::Performance::PerformanceMetrics.to_json_any(42_i64).should be_a(JSON::Any)
      CQL::Performance::PerformanceMetrics.to_json_any(3.14).should be_a(JSON::Any)
      CQL::Performance::PerformanceMetrics.to_json_any(true).should be_a(JSON::Any)
      CQL::Performance::PerformanceMetrics.to_json_any(nil).should be_a(JSON::Any)
    end

    it "handles arrays" do
      array = [1, 2, 3]
      result = CQL::Performance::PerformanceMetrics.to_json_any(array)
      result.should be_a(JSON::Any)
    end

    it "handles hashes" do
      hash = {"key" => "value", "number" => 42}
      result = CQL::Performance::PerformanceMetrics.to_json_any(hash)
      result.should be_a(JSON::Any)
    end

    it "handles Time objects" do
      time = Time.utc
      result = CQL::Performance::PerformanceMetrics.to_json_any(time)
      result.should be_a(JSON::Any)
    end

    it "handles Time::Span objects" do
      span = Time::Span.new(seconds: 30)
      result = CQL::Performance::PerformanceMetrics.to_json_any(span)
      result.should be_a(JSON::Any)
    end

    it "handles objects with to_s method" do
      obj = "test_string"
      result = CQL::Performance::PerformanceMetrics.to_json_any(obj)
      result.should be_a(JSON::Any)
    end
  end
end
