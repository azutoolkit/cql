# Query profiler with direct method calls
# Removes event system overhead for better performance

require "db"
require "./utilities"
require "./config"
require "./interfaces"

module CQL::Performance
  # Query execution data
  struct QueryData
    getter sql : String
    getter params : Array(DB::Any)
    getter execution_time : Time::Span
    getter timestamp : Time = Time.utc
    getter rows_affected : Int64?
    getter error : String?
    @normalized_sql : String?

    def initialize(@sql, @params, @execution_time, @rows_affected = nil, @error = nil)
    end

    def normalized_sql : String
      @normalized_sql ||= SQLUtils.normalize_sql(sql)
    end

    def slow?(threshold : Time::Span) : Bool
      execution_time > threshold
    end
  end

  # Query profiler without event system
  class QueryProfiler < BasePerformanceComponent
    include CQL::Performance::QueryProfilerInterface
    @queries : Array(QueryData) = [] of QueryData
    @query_stats : Hash(String, StatsTracker) = {} of String => StatsTracker
    @slow_queries : Array(QueryData) = [] of QueryData
    @slow_queries_sorted : Array(QueryData)? = nil
    @config : Config::Profiling
    @mutex : Mutex = Mutex.new

    MAX_SLOW_QUERIES = 1000

    def initialize(@config : Config::Profiling = Config::Profiling.new)
      super()
    end

    # Direct method call instead of event handling
    def record_query(sql : String, params : Array(DB::Any),
                     execution_time : Time::Span,
                     rows_affected : Int64? = nil,
                     error : String? = nil) : Void
      return unless @enabled

      # Create query data
      query = QueryData.new(sql, params, execution_time, rows_affected, error)

      @mutex.synchronize do
        # Record in memory if needed
        if @config.log_all_queries? || query.slow?(@config.slow_query_threshold)
          @queries << query
          cleanup_old_queries if @queries.size > @config.max_recorded_queries
        end

        # Track statistics
        track_stats(query)

        # Track slow queries
        if query.slow?(@config.slow_query_threshold)
          @slow_queries << query
          @slow_queries_sorted = nil
          cleanup_slow_queries if @slow_queries.size > MAX_SLOW_QUERIES
        end
      end

      # Log outside mutex to avoid holding lock during I/O
      if query.slow?(@config.slow_query_threshold) && @config.log_slow_queries?
        log_slow_query(query)
      end
    end

    # Get query statistics
    def statistics : Hash(String, NamedTuple(
      count: Int32,
      total_ms: Float64,
      avg_ms: Float64,
      min_ms: Float64,
      max_ms: Float64))
      @mutex.synchronize do
        result = {} of String => NamedTuple(
          count: Int32,
          total_ms: Float64,
          avg_ms: Float64,
          min_ms: Float64,
          max_ms: Float64)

        @query_stats.each do |sql, stats|
          result[sql] = {
            count:    stats.total_count.to_i32,
            total_ms: stats.total_time.total_milliseconds,
            avg_ms:   stats.avg_time.total_milliseconds,
            min_ms:   stats.min_time == Time::Span::MAX ? 0.0 : stats.min_time.total_milliseconds,
            max_ms:   stats.max_time.total_milliseconds,
          }
        end

        result
      end
    end

    # Get stats trackers for report generation
    def stats_trackers : Hash(String, StatsTracker)
      @mutex.synchronize { @query_stats.dup }
    end

    # Get slowest queries (cached sort)
    def slowest_queries(limit : Int32 = 10) : Array(QueryData)
      @mutex.synchronize do
        sorted = @slow_queries_sorted ||= @slow_queries
          .sort_by(&.execution_time.total_milliseconds)
          .reverse!
        @slow_queries_sorted = sorted
        sorted.first(limit)
      end
    end

    # Clear all data
    def clear : Void
      @mutex.synchronize do
        @queries.clear
        @query_stats.clear
        @slow_queries.clear
        @slow_queries_sorted = nil
        reset
      end
    end

    # Get performance issues
    def issues : Array(Issue)
      @mutex.synchronize do
        issues = [] of Issue

        # Check for very slow queries
        very_slow = @slow_queries.select { |query| query.execution_time > @config.very_slow_threshold }
        if very_slow.any?
          issues << Issue.new(
            type: :very_slow_queries,
            severity: :critical,
            message: "#{very_slow.size} queries exceeded #{@config.very_slow_threshold.total_milliseconds}ms",
            details: {
              "count"        => very_slow.size.to_s,
              "threshold_ms" => @config.very_slow_threshold.total_milliseconds.to_s,
            }
          )
        end

        # Check for high frequency queries
        @query_stats.each do |sql, stats|
          if stats.total_count > 100 && stats.avg_time > 50.milliseconds
            issues << Issue.new(
              type: :high_frequency_slow_query,
              severity: :high,
              message: "Query executed #{stats.total_count} times with avg time #{stats.avg_time.total_milliseconds.round(2)}ms",
              details: {
                "sql"    => SQLUtils.truncate_sql(sql),
                "count"  => stats.total_count.to_s,
                "avg_ms" => stats.avg_time.total_milliseconds.round(2).to_s,
              }
            )
          end
        end

        issues
      end
    end

    private def track_stats(query : QueryData)
      normalized = query.normalized_sql
      tracker = @query_stats[normalized] ||= StatsTracker.new
      tracker.record(query.execution_time, !query.error.nil?)
    end

    private def cleanup_old_queries
      keep_count = (@config.max_recorded_queries * 0.8).to_i
      @queries = @queries.last(keep_count)
    end

    private def cleanup_slow_queries
      keep_count = (MAX_SLOW_QUERIES * 0.8).to_i
      @slow_queries = @slow_queries.last(keep_count)
      @slow_queries_sorted = nil
    end

    private def log_slow_query(query : QueryData)
      severity = query.execution_time > @config.very_slow_threshold ? "VERY SLOW" : "SLOW"
      formatted_time = format_duration(query.execution_time)
      Log.warn { "#{severity} QUERY (#{formatted_time}): #{SQLUtils.truncate_sql(query.sql)}" }
    end
  end
end
