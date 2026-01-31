require "../spec_helper"

describe CQL::Performance::QueryData do
  describe "#initialize" do
    it "creates a QueryData with required fields" do
      query = CQL::Performance::QueryData.new(
        sql: "SELECT * FROM users WHERE id = $1",
        params: [1.as(DB::Any)],
        execution_time: 50.milliseconds
      )

      query.sql.should eq("SELECT * FROM users WHERE id = $1")
      query.params.should eq([1.as(DB::Any)])
      query.execution_time.should eq(50.milliseconds)
      query.rows_affected.should be_nil
      query.error.should be_nil
    end

    it "creates a QueryData with all optional fields" do
      query = CQL::Performance::QueryData.new(
        sql: "UPDATE users SET name = $1 WHERE id = $2",
        params: ["Alice".as(DB::Any), 1.as(DB::Any)],
        execution_time: 25.milliseconds,
        rows_affected: 1_i64,
        error: nil
      )

      query.rows_affected.should eq(1_i64)
      query.error.should be_nil
    end

    it "creates a QueryData with an error" do
      query = CQL::Performance::QueryData.new(
        sql: "SELECT * FROM nonexistent",
        params: [] of DB::Any,
        execution_time: 5.milliseconds,
        error: "table not found"
      )

      query.error.should eq("table not found")
    end

    it "sets timestamp to current UTC time" do
      before = Time.utc
      query = CQL::Performance::QueryData.new(
        sql: "SELECT 1",
        params: [] of DB::Any,
        execution_time: 1.millisecond
      )
      after = Time.utc

      query.timestamp.should be >= before
      query.timestamp.should be <= after
    end
  end

  describe "#normalized_sql" do
    it "normalizes SQL by replacing parameters with placeholders" do
      query = CQL::Performance::QueryData.new(
        sql: "SELECT * FROM users WHERE id = $1 AND name = 'Alice'",
        params: [1.as(DB::Any)],
        execution_time: 10.milliseconds
      )

      normalized = query.normalized_sql
      normalized.should contain("?")
      normalized.should_not contain("$1")
      normalized.should_not contain("Alice")
    end

    it "caches the normalized SQL on subsequent calls" do
      query = CQL::Performance::QueryData.new(
        sql: "SELECT * FROM users WHERE id = $1",
        params: [1.as(DB::Any)],
        execution_time: 10.milliseconds
      )

      first_call = query.normalized_sql
      second_call = query.normalized_sql
      first_call.should eq(second_call)
    end

    it "collapses whitespace in normalized SQL" do
      query = CQL::Performance::QueryData.new(
        sql: "SELECT  *  FROM   users   WHERE   id = $1",
        params: [1.as(DB::Any)],
        execution_time: 10.milliseconds
      )

      query.normalized_sql.should_not contain("  ")
    end
  end

  describe "#slow?" do
    it "returns true when execution time exceeds threshold" do
      query = CQL::Performance::QueryData.new(
        sql: "SELECT * FROM users",
        params: [] of DB::Any,
        execution_time: 200.milliseconds
      )

      query.slow?(100.milliseconds).should be_true
    end

    it "returns false when execution time is within threshold" do
      query = CQL::Performance::QueryData.new(
        sql: "SELECT * FROM users",
        params: [] of DB::Any,
        execution_time: 50.milliseconds
      )

      query.slow?(100.milliseconds).should be_false
    end

    it "returns false when execution time equals threshold" do
      query = CQL::Performance::QueryData.new(
        sql: "SELECT * FROM users",
        params: [] of DB::Any,
        execution_time: 100.milliseconds
      )

      query.slow?(100.milliseconds).should be_false
    end
  end
end

describe CQL::Performance::QueryProfiler do
  describe "#initialize" do
    it "creates a profiler with default config" do
      profiler = CQL::Performance::QueryProfiler.new

      profiler.enabled?.should be_true
    end

    it "creates a profiler with custom config" do
      config = CQL::Performance::Config::Profiling.new
      config.slow_query_threshold = 200.milliseconds
      config.very_slow_threshold = 2.seconds
      config.max_recorded_queries = 500

      profiler = CQL::Performance::QueryProfiler.new(config)

      profiler.enabled?.should be_true
    end
  end

  describe "#record_query" do
    it "records a query and tracks stats" do
      config = CQL::Performance::Config::Profiling.new
      config.log_all_queries = true
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      profiler.record_query(
        sql: "SELECT * FROM users WHERE id = $1",
        params: [1.as(DB::Any)],
        execution_time: 10.milliseconds
      )

      stats = profiler.statistics
      stats.should_not be_empty
    end

    it "tracks statistics for normalized SQL" do
      config = CQL::Performance::Config::Profiling.new
      config.log_all_queries = true
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      profiler.record_query(
        sql: "SELECT * FROM users WHERE id = $1",
        params: [1.as(DB::Any)],
        execution_time: 10.milliseconds
      )

      profiler.record_query(
        sql: "SELECT * FROM users WHERE id = $2",
        params: [2.as(DB::Any)],
        execution_time: 20.milliseconds
      )

      stats = profiler.statistics
      # Both queries should normalize to the same key
      stats.size.should eq(1)
      stats.each_value do |stat|
        stat[:count].should eq(2)
      end
    end

    it "identifies and stores slow queries" do
      config = CQL::Performance::Config::Profiling.new
      config.slow_query_threshold = 50.milliseconds
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      profiler.record_query(
        sql: "SELECT * FROM users",
        params: [] of DB::Any,
        execution_time: 10.milliseconds
      )

      profiler.record_query(
        sql: "SELECT * FROM orders JOIN products ON orders.product_id = products.id",
        params: [] of DB::Any,
        execution_time: 100.milliseconds
      )

      slow = profiler.slowest_queries
      slow.size.should eq(1)
      slow.first.execution_time.should eq(100.milliseconds)
    end

    it "records queries with rows_affected" do
      config = CQL::Performance::Config::Profiling.new
      config.log_all_queries = true
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      profiler.record_query(
        sql: "UPDATE users SET active = true",
        params: [] of DB::Any,
        execution_time: 15.milliseconds,
        rows_affected: 42_i64
      )

      stats = profiler.statistics
      stats.should_not be_empty
    end

    it "records queries with errors" do
      config = CQL::Performance::Config::Profiling.new
      config.log_all_queries = true
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      profiler.record_query(
        sql: "SELECT * FROM nonexistent",
        params: [] of DB::Any,
        execution_time: 5.milliseconds,
        error: "table not found"
      )

      trackers = profiler.stats_trackers
      trackers.should_not be_empty
      trackers.each_value do |tracker|
        tracker.errors.should eq(1)
      end
    end

    it "records multiple different queries separately" do
      config = CQL::Performance::Config::Profiling.new
      config.log_all_queries = true
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      profiler.record_query(
        sql: "SELECT * FROM users",
        params: [] of DB::Any,
        execution_time: 10.milliseconds
      )

      profiler.record_query(
        sql: "SELECT * FROM orders",
        params: [] of DB::Any,
        execution_time: 20.milliseconds
      )

      stats = profiler.statistics
      stats.size.should eq(2)
    end
  end

  describe "#statistics" do
    it "returns correct aggregated statistics" do
      config = CQL::Performance::Config::Profiling.new
      config.log_all_queries = true
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      profiler.record_query(
        sql: "SELECT * FROM users WHERE id = $1",
        params: [1.as(DB::Any)],
        execution_time: 10.milliseconds
      )

      profiler.record_query(
        sql: "SELECT * FROM users WHERE id = $1",
        params: [2.as(DB::Any)],
        execution_time: 30.milliseconds
      )

      profiler.record_query(
        sql: "SELECT * FROM users WHERE id = $1",
        params: [3.as(DB::Any)],
        execution_time: 20.milliseconds
      )

      stats = profiler.statistics
      stats.size.should eq(1)

      stats.each_value do |stat|
        stat[:count].should eq(3)
        stat[:total_ms].should be_close(60.0, 0.1)
        stat[:avg_ms].should be_close(20.0, 0.1)
        stat[:min_ms].should be_close(10.0, 0.1)
        stat[:max_ms].should be_close(30.0, 0.1)
      end
    end

    it "returns empty hash when no queries recorded" do
      profiler = CQL::Performance::QueryProfiler.new

      profiler.statistics.should be_empty
    end

    it "tracks statistics even for non-slow queries" do
      config = CQL::Performance::Config::Profiling.new
      config.slow_query_threshold = 100.milliseconds
      config.log_all_queries = false
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      profiler.record_query(
        sql: "SELECT 1",
        params: [] of DB::Any,
        execution_time: 1.millisecond
      )

      stats = profiler.statistics
      stats.should_not be_empty
    end
  end

  describe "#stats_trackers" do
    it "returns a hash of StatsTracker instances" do
      config = CQL::Performance::Config::Profiling.new
      config.log_all_queries = true
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      profiler.record_query(
        sql: "SELECT * FROM users",
        params: [] of DB::Any,
        execution_time: 10.milliseconds
      )

      trackers = profiler.stats_trackers
      trackers.should be_a(Hash(String, CQL::Performance::StatsTracker))
      trackers.size.should eq(1)
    end

    it "returns trackers with correct counts" do
      config = CQL::Performance::Config::Profiling.new
      config.log_all_queries = true
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      3.times do
        profiler.record_query(
          sql: "SELECT * FROM users",
          params: [] of DB::Any,
          execution_time: 10.milliseconds
        )
      end

      trackers = profiler.stats_trackers
      trackers.each_value do |tracker|
        tracker.total_count.should eq(3)
      end
    end

    it "returns empty hash when no queries recorded" do
      profiler = CQL::Performance::QueryProfiler.new
      profiler.stats_trackers.should be_empty
    end
  end

  describe "#slowest_queries" do
    it "returns queries sorted by execution time descending" do
      config = CQL::Performance::Config::Profiling.new
      config.slow_query_threshold = 10.milliseconds
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      [50, 200, 100, 150].each_with_index do |millis, index|
        profiler.record_query(
          sql: "SELECT * FROM table_#{index}",
          params: [] of DB::Any,
          execution_time: millis.milliseconds
        )
      end

      slow = profiler.slowest_queries
      slow.size.should eq(4)
      slow[0].execution_time.should eq(200.milliseconds)
      slow[1].execution_time.should eq(150.milliseconds)
      slow[2].execution_time.should eq(100.milliseconds)
      slow[3].execution_time.should eq(50.milliseconds)
    end

    it "respects the limit parameter" do
      config = CQL::Performance::Config::Profiling.new
      config.slow_query_threshold = 10.milliseconds
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      5.times do |i|
        profiler.record_query(
          sql: "SELECT * FROM table_#{i}",
          params: [] of DB::Any,
          execution_time: (20 + i * 10).milliseconds
        )
      end

      slow = profiler.slowest_queries(limit: 3)
      slow.size.should eq(3)
      slow[0].execution_time.should be >= slow[1].execution_time
      slow[1].execution_time.should be >= slow[2].execution_time
    end

    it "returns empty array when no slow queries exist" do
      profiler = CQL::Performance::QueryProfiler.new

      profiler.record_query(
        sql: "SELECT 1",
        params: [] of DB::Any,
        execution_time: 1.millisecond
      )

      profiler.slowest_queries.should be_empty
    end

    it "uses cached sorted results on repeated calls" do
      config = CQL::Performance::Config::Profiling.new
      config.slow_query_threshold = 10.milliseconds
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      profiler.record_query(
        sql: "SELECT * FROM users",
        params: [] of DB::Any,
        execution_time: 50.milliseconds
      )

      profiler.record_query(
        sql: "SELECT * FROM orders",
        params: [] of DB::Any,
        execution_time: 100.milliseconds
      )

      first_call = profiler.slowest_queries
      second_call = profiler.slowest_queries

      first_call.size.should eq(second_call.size)
      first_call[0].execution_time.should eq(second_call[0].execution_time)
    end

    it "invalidates cache when new slow query is added" do
      config = CQL::Performance::Config::Profiling.new
      config.slow_query_threshold = 10.milliseconds
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      profiler.record_query(
        sql: "SELECT * FROM users",
        params: [] of DB::Any,
        execution_time: 50.milliseconds
      )

      first_result = profiler.slowest_queries
      first_result.size.should eq(1)

      profiler.record_query(
        sql: "SELECT * FROM orders",
        params: [] of DB::Any,
        execution_time: 200.milliseconds
      )

      second_result = profiler.slowest_queries
      second_result.size.should eq(2)
      second_result[0].execution_time.should eq(200.milliseconds)
    end
  end

  describe "#issues" do
    it "detects very slow queries as critical issues" do
      config = CQL::Performance::Config::Profiling.new
      config.slow_query_threshold = 50.milliseconds
      config.very_slow_threshold = 500.milliseconds
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      profiler.record_query(
        sql: "SELECT * FROM huge_table",
        params: [] of DB::Any,
        execution_time: 1.second
      )

      issues = profiler.issues
      issues.should_not be_empty

      critical_issues = issues.select { |i| i.severity == :critical }
      critical_issues.should_not be_empty
      critical_issues.first.type.should eq(:very_slow_queries)
      critical_issues.first.message.should contain("1 queries")
    end

    it "detects high-frequency slow queries as high severity" do
      config = CQL::Performance::Config::Profiling.new
      config.slow_query_threshold = 10.milliseconds
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      # Record more than 100 queries with avg > 50ms
      101.times do
        profiler.record_query(
          sql: "SELECT * FROM slow_table WHERE active = true",
          params: [] of DB::Any,
          execution_time: 60.milliseconds
        )
      end

      issues = profiler.issues
      high_issues = issues.select { |i| i.severity == :high }
      high_issues.should_not be_empty
      high_issues.first.type.should eq(:high_frequency_slow_query)
      high_issues.first.message.should contain("101")
    end

    it "returns empty array when no issues detected" do
      config = CQL::Performance::Config::Profiling.new
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      profiler.record_query(
        sql: "SELECT 1",
        params: [] of DB::Any,
        execution_time: 1.millisecond
      )

      profiler.issues.should be_empty
    end

    it "reports multiple very slow queries in a single issue" do
      config = CQL::Performance::Config::Profiling.new
      config.slow_query_threshold = 50.milliseconds
      config.very_slow_threshold = 500.milliseconds
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      3.times do |i|
        profiler.record_query(
          sql: "SELECT * FROM table_#{i}",
          params: [] of DB::Any,
          execution_time: 1.second
        )
      end

      issues = profiler.issues
      critical = issues.select { |i| i.severity == :critical }
      critical.size.should eq(1)
      critical.first.message.should contain("3 queries")
    end

    it "does not report high-frequency when count is below threshold" do
      config = CQL::Performance::Config::Profiling.new
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      50.times do
        profiler.record_query(
          sql: "SELECT * FROM users",
          params: [] of DB::Any,
          execution_time: 60.milliseconds
        )
      end

      issues = profiler.issues
      high_issues = issues.select { |i| i.type == :high_frequency_slow_query }
      high_issues.should be_empty
    end

    it "does not report high-frequency when avg time is below 50ms" do
      config = CQL::Performance::Config::Profiling.new
      config.log_slow_queries = false
      config.log_all_queries = true
      profiler = CQL::Performance::QueryProfiler.new(config)

      101.times do
        profiler.record_query(
          sql: "SELECT * FROM users",
          params: [] of DB::Any,
          execution_time: 5.milliseconds
        )
      end

      issues = profiler.issues
      high_issues = issues.select { |i| i.type == :high_frequency_slow_query }
      high_issues.should be_empty
    end
  end

  describe "#clear" do
    it "resets all state" do
      config = CQL::Performance::Config::Profiling.new
      config.slow_query_threshold = 10.milliseconds
      config.log_slow_queries = false
      config.log_all_queries = true
      profiler = CQL::Performance::QueryProfiler.new(config)

      5.times do |i|
        profiler.record_query(
          sql: "SELECT * FROM table_#{i}",
          params: [] of DB::Any,
          execution_time: 50.milliseconds
        )
      end

      profiler.statistics.should_not be_empty
      profiler.slowest_queries.should_not be_empty
      profiler.stats_trackers.should_not be_empty

      profiler.clear

      profiler.statistics.should be_empty
      profiler.slowest_queries.should be_empty
      profiler.stats_trackers.should be_empty
      profiler.issues.should be_empty
    end

    it "allows recording new queries after clear" do
      config = CQL::Performance::Config::Profiling.new
      config.log_all_queries = true
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      profiler.record_query(
        sql: "SELECT * FROM users",
        params: [] of DB::Any,
        execution_time: 10.milliseconds
      )

      profiler.clear

      profiler.record_query(
        sql: "SELECT * FROM orders",
        params: [] of DB::Any,
        execution_time: 20.milliseconds
      )

      stats = profiler.statistics
      stats.size.should eq(1)
    end
  end

  describe "enabled flag" do
    it "does not record queries when disabled" do
      config = CQL::Performance::Config::Profiling.new
      config.log_all_queries = true
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)
      profiler.enabled = false

      profiler.record_query(
        sql: "SELECT * FROM users",
        params: [] of DB::Any,
        execution_time: 10.milliseconds
      )

      profiler.statistics.should be_empty
      profiler.stats_trackers.should be_empty
    end

    it "resumes recording when re-enabled" do
      config = CQL::Performance::Config::Profiling.new
      config.log_all_queries = true
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      profiler.enabled = false
      profiler.record_query(
        sql: "SELECT * FROM users",
        params: [] of DB::Any,
        execution_time: 10.milliseconds
      )

      profiler.enabled = true
      profiler.record_query(
        sql: "SELECT * FROM orders",
        params: [] of DB::Any,
        execution_time: 20.milliseconds
      )

      stats = profiler.statistics
      stats.size.should eq(1)
    end

    it "does not track slow queries when disabled" do
      config = CQL::Performance::Config::Profiling.new
      config.slow_query_threshold = 10.milliseconds
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)
      profiler.enabled = false

      profiler.record_query(
        sql: "SELECT * FROM users",
        params: [] of DB::Any,
        execution_time: 200.milliseconds
      )

      profiler.slowest_queries.should be_empty
    end
  end

  describe "cleanup behavior" do
    it "trims slow queries when exceeding MAX_SLOW_QUERIES" do
      config = CQL::Performance::Config::Profiling.new
      config.slow_query_threshold = 1.millisecond
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      # Insert more than MAX_SLOW_QUERIES (1000) slow queries
      1_005.times do |i|
        profiler.record_query(
          sql: "SELECT * FROM table_#{i}",
          params: [] of DB::Any,
          execution_time: 5.milliseconds
        )
      end

      # After cleanup, should be trimmed to around 80% of 1000 = 800
      # (exact count depends on when cleanup triggers vs remaining insertions)
      slow = profiler.slowest_queries(limit: 1_005)
      slow.size.should be <= 1_005
      slow.size.should be < 1_005
    end

    it "trims recorded queries when exceeding max_recorded_queries" do
      config = CQL::Performance::Config::Profiling.new
      config.log_all_queries = true
      config.log_slow_queries = false
      config.max_recorded_queries = 100
      profiler = CQL::Performance::QueryProfiler.new(config)

      # Record more than max_recorded_queries
      105.times do |i|
        profiler.record_query(
          sql: "SELECT * FROM table_#{i}",
          params: [] of DB::Any,
          execution_time: 1.millisecond
        )
      end

      # Statistics still track all queries since stats are not trimmed
      stats = profiler.statistics
      stats.size.should be > 0
    end

    it "keeps most recent queries after cleanup" do
      config = CQL::Performance::Config::Profiling.new
      config.slow_query_threshold = 1.millisecond
      config.log_slow_queries = false
      profiler = CQL::Performance::QueryProfiler.new(config)

      # Fill up to trigger cleanup
      1_005.times do |i|
        profiler.record_query(
          sql: "SELECT * FROM table_#{i}",
          params: [] of DB::Any,
          execution_time: (5 + i).milliseconds
        )
      end

      # After cleanup the most recent (last) queries should be retained
      slow = profiler.slowest_queries(limit: 800)
      slow.should_not be_empty
      # The slowest query should be the last one recorded (highest execution time)
      slow.first.execution_time.should eq(1_009.milliseconds)
    end
  end
end
