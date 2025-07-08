# Performance Metrics - Unified metrics collection
# Captures all metrics and lists from all performance modules

require "json"
require "./utilities"
require "./config"
require "./query_profiler"
require "./n_plus_one_detector"
require "./unified_report_generator"

module CQL::Performance
  # Comprehensive performance metrics collection
  # Provides unified access to all performance data across modules
  class PerformanceMetrics
    include TimingUtils

    # Helper method to convert values to JSON::Any recursively
    def self.to_json_any(value) : JSON::Any
      case value
      when String, Int32, Int64, Float64, Bool, Nil
        JSON::Any.new(value)
      when Array
        JSON::Any.new(value.map { |v| to_json_any(v) })
      when Hash
        JSON::Any.new(value.transform_values { |v| to_json_any(v) })
      when Time
        JSON::Any.new(value.to_rfc3339)
      when Time::Span
        JSON::Any.new(value.total_milliseconds)
      else
        JSON::Any.new(value.to_s)
      end
    end

    # Query performance metrics
    struct QueryMetrics
      getter total_queries : Int64 = 0
      getter slow_queries : Int64 = 0
      getter very_slow_queries : Int64 = 0
      getter error_queries : Int64 = 0
      getter total_execution_time : Time::Span = Time::Span.zero
      getter avg_execution_time : Time::Span = Time::Span.zero
      getter min_execution_time : Time::Span = Time::Span.zero
      getter max_execution_time : Time::Span = Time::Span.zero
      getter error_rate : Float64 = 0.0
      getter queries_per_second : Float64 = 0.0
      getter slow_query_rate : Float64 = 0.0

      def initialize(@total_queries, @slow_queries, @very_slow_queries, @error_queries,
                     @total_execution_time, @avg_execution_time, @min_execution_time,
                     @max_execution_time, @error_rate, @queries_per_second, @slow_query_rate)
      end

      def to_h : Hash(String, JSON::Any)
        {
          "total_queries"        => JSON::Any.new(@total_queries),
          "slow_queries"         => JSON::Any.new(@slow_queries),
          "very_slow_queries"    => JSON::Any.new(@very_slow_queries),
          "error_queries"        => JSON::Any.new(@error_queries),
          "total_execution_time_ms" => JSON::Any.new(@total_execution_time.total_milliseconds),
          "avg_execution_time_ms"   => JSON::Any.new(@avg_execution_time.total_milliseconds),
          "min_execution_time_ms"   => JSON::Any.new(@min_execution_time == Time::Span::MAX ? 0.0 : @min_execution_time.total_milliseconds),
          "max_execution_time_ms"   => JSON::Any.new(@max_execution_time.total_milliseconds),
          "error_rate_percent"      => JSON::Any.new(@error_rate),
          "queries_per_second"      => JSON::Any.new(@queries_per_second),
          "slow_query_rate_percent" => JSON::Any.new(@slow_query_rate),
        }
      end
    end

    # N+1 detection metrics
    struct NPlusOneMetrics
      getter total_patterns : Int32 = 0
      getter critical_patterns : Int32 = 0
      getter high_patterns : Int32 = 0
      getter medium_patterns : Int32 = 0
      getter low_patterns : Int32 = 0
      getter total_repetitions : Int64 = 0
      getter avg_repetitions_per_pattern : Float64 = 0.0
      getter max_repetitions : Int32 = 0
      getter detection_rate : Float64 = 0.0

      def initialize(@total_patterns, @critical_patterns, @high_patterns, @medium_patterns,
                     @low_patterns, @total_repetitions, @avg_repetitions_per_pattern,
                     @max_repetitions, @detection_rate)
      end

      def to_h : Hash(String, JSON::Any)
        {
          "total_patterns"              => JSON::Any.new(@total_patterns),
          "critical_patterns"           => JSON::Any.new(@critical_patterns),
          "high_patterns"               => JSON::Any.new(@high_patterns),
          "medium_patterns"             => JSON::Any.new(@medium_patterns),
          "low_patterns"                => JSON::Any.new(@low_patterns),
          "total_repetitions"           => JSON::Any.new(@total_repetitions),
          "avg_repetitions_per_pattern" => JSON::Any.new(@avg_repetitions_per_pattern),
          "max_repetitions"             => JSON::Any.new(@max_repetitions),
          "detection_rate_percent"      => JSON::Any.new(@detection_rate),
        }
      end
    end

    # Cache performance metrics
    struct CacheMetrics
      getter cache_hits : Int64 = 0
      getter cache_misses : Int64 = 0
      getter cache_size : Int32 = 0
      getter max_cache_size : Int32 = 0
      getter hit_rate : Float64 = 0.0
      getter miss_rate : Float64 = 0.0
      getter evictions : Int64 = 0

      def initialize(@cache_hits, @cache_misses, @cache_size, @max_cache_size,
                     @hit_rate, @miss_rate, @evictions)
      end

      def to_h : Hash(String, JSON::Any)
        {
          "cache_hits"        => JSON::Any.new(@cache_hits),
          "cache_misses"      => JSON::Any.new(@cache_misses),
          "cache_size"        => JSON::Any.new(@cache_size),
          "max_cache_size"    => JSON::Any.new(@max_cache_size),
          "hit_rate_percent"  => JSON::Any.new(@hit_rate),
          "miss_rate_percent" => JSON::Any.new(@miss_rate),
          "evictions"         => JSON::Any.new(@evictions),
        }
      end
    end

    # System performance metrics
    struct SystemMetrics
      getter uptime : Time::Span = Time::Span.zero
      getter memory_usage_mb : Float64 = 0.0
      getter cpu_usage_percent : Float64 = 0.0
      getter active_connections : Int32 = 0
      getter max_connections : Int32 = 0
      getter connection_pool_utilization : Float64 = 0.0

      def initialize(@uptime, @memory_usage_mb, @cpu_usage_percent, @active_connections,
                     @max_connections, @connection_pool_utilization)
      end

      def to_h : Hash(String, JSON::Any)
        {
          "uptime_seconds"              => JSON::Any.new(@uptime.total_seconds),
          "memory_usage_mb"             => JSON::Any.new(@memory_usage_mb),
          "cpu_usage_percent"           => JSON::Any.new(@cpu_usage_percent),
          "active_connections"          => JSON::Any.new(@active_connections),
          "max_connections"             => JSON::Any.new(@max_connections),
          "connection_pool_utilization_percent" => JSON::Any.new(@connection_pool_utilization),
        }
      end
    end

    # Performance health metrics
    struct HealthMetrics
      getter overall_health_score : Int32 = 100
      getter query_health_score : Int32 = 100
      getter n_plus_one_health_score : Int32 = 100
      getter cache_health_score : Int32 = 100
      getter system_health_score : Int32 = 100
      getter critical_issues : Int32 = 0
      getter high_issues : Int32 = 0
      getter medium_issues : Int32 = 0
      getter low_issues : Int32 = 0
      getter total_issues : Int32 = 0

      def initialize(@overall_health_score, @query_health_score, @n_plus_one_health_score,
                     @cache_health_score, @system_health_score, @critical_issues,
                     @high_issues, @medium_issues, @low_issues, @total_issues)
      end

      def to_h : Hash(String, JSON::Any)
        {
          "overall_health_score"     => JSON::Any.new(@overall_health_score),
          "query_health_score"       => JSON::Any.new(@query_health_score),
          "n_plus_one_health_score"  => JSON::Any.new(@n_plus_one_health_score),
          "cache_health_score"       => JSON::Any.new(@cache_health_score),
          "system_health_score"      => JSON::Any.new(@system_health_score),
          "critical_issues"          => JSON::Any.new(@critical_issues),
          "high_issues"              => JSON::Any.new(@high_issues),
          "medium_issues"            => JSON::Any.new(@medium_issues),
          "low_issues"               => JSON::Any.new(@low_issues),
          "total_issues"             => JSON::Any.new(@total_issues),
        }
      end
    end

    # Top queries by various criteria
    struct TopQueries
      getter slowest_queries : Array(QueryData)
      getter most_frequent_queries : Array(NamedTuple(sql: String, count: Int64, avg_time: Time::Span))
      getter highest_error_queries : Array(NamedTuple(sql: String, errors: Int64, error_rate: Float64))
      getter most_expensive_queries : Array(NamedTuple(sql: String, total_time: Time::Span, count: Int64))

      def initialize(@slowest_queries, @most_frequent_queries, @highest_error_queries, @most_expensive_queries)
      end

      def to_h : Hash(String, JSON::Any)
        {
          "slowest_queries" => JSON::Any.new(@slowest_queries.map { |q| PerformanceMetrics.to_json_any(q.to_h) }),
          "most_frequent_queries" => JSON::Any.new(@most_frequent_queries.map { |q| PerformanceMetrics.to_json_any(q) }),
          "highest_error_queries" => JSON::Any.new(@highest_error_queries.map { |q| PerformanceMetrics.to_json_any(q) }),
          "most_expensive_queries" => JSON::Any.new(@most_expensive_queries.map { |q| PerformanceMetrics.to_json_any(q) }),
        }
      end
    end

    # Performance patterns and trends
    struct PerformancePatterns
      getter n_plus_one_patterns : Array(NPlusOnePattern)
      getter query_patterns : Array(NamedTuple(pattern: String, count: Int64, avg_time: Time::Span))
      getter time_distribution : Hash(String, Int64) # fast/slow/very_slow counts
      getter error_patterns : Array(NamedTuple(error_type: String, count: Int64, percentage: Float64))

      def initialize(@n_plus_one_patterns, @query_patterns, @time_distribution, @error_patterns)
      end

      def to_h : Hash(String, JSON::Any)
        {
          "n_plus_one_patterns" => JSON::Any.new(@n_plus_one_patterns.map { |p| PerformanceMetrics.to_json_any(p.to_h) }),
          "query_patterns" => JSON::Any.new(@query_patterns.map { |p| PerformanceMetrics.to_json_any(p) }),
          "time_distribution" => PerformanceMetrics.to_json_any(@time_distribution),
          "error_patterns" => JSON::Any.new(@error_patterns.map { |p| PerformanceMetrics.to_json_any(p) }),
        }
      end
    end

    # Main metrics collection
    getter query_metrics : QueryMetrics
    getter n_plus_one_metrics : NPlusOneMetrics
    getter cache_metrics : CacheMetrics
    getter system_metrics : SystemMetrics
    getter health_metrics : HealthMetrics
    getter top_queries : TopQueries
    getter patterns : PerformancePatterns
    getter issues : Array(Issue)
    getter timestamp : Time = Time.utc
    getter collection_duration : Time::Span = Time::Span.zero

    def initialize(
      @query_metrics : QueryMetrics,
      @n_plus_one_metrics : NPlusOneMetrics,
      @cache_metrics : CacheMetrics,
      @system_metrics : SystemMetrics,
      @health_metrics : HealthMetrics,
      @top_queries : TopQueries,
      @patterns : PerformancePatterns,
      @issues : Array(Issue),
      @collection_duration : Time::Span = Time::Span.zero
    )
    end

    # Create metrics from performance components
    def self.from_components(
      profiler : QueryProfilerInterface? = nil,
      detector : NPlusOneDetectorInterface? = nil,
      cache : Cache? = nil,
      start_time : Time? = nil,
      config : Config? = nil
    ) : self
      start_time ||= Time.utc
      collection_duration = Time.utc - start_time

      # Query metrics
      query_metrics = build_query_metrics(profiler, collection_duration)

      # N+1 metrics
      n_plus_one_metrics = build_n_plus_one_metrics(detector)

      # Cache metrics
      cache_metrics = build_cache_metrics(cache)

      # System metrics
      system_metrics = build_system_metrics(start_time)

      # Health metrics
      health_metrics = build_health_metrics(profiler, detector, cache)

      # Top queries
      top_queries = build_top_queries(profiler)

      # Patterns
      patterns = build_performance_patterns(profiler, detector)

      # Issues
      issues = collect_issues(profiler, detector)

      new(
        query_metrics,
        n_plus_one_metrics,
        cache_metrics,
        system_metrics,
        health_metrics,
        top_queries,
        patterns,
        issues,
        collection_duration
      )
    end

    # Export all metrics as a comprehensive hash
    def to_h : Hash(String, JSON::Any)
      {
        "timestamp" => JSON::Any.new(@timestamp.to_rfc3339),
        "collection_duration_seconds" => JSON::Any.new(@collection_duration.total_seconds),
        "query_metrics" => JSON::Any.new(@query_metrics.to_h),
        "n_plus_one_metrics" => JSON::Any.new(@n_plus_one_metrics.to_h),
        "cache_metrics" => JSON::Any.new(@cache_metrics.to_h),
        "system_metrics" => JSON::Any.new(@system_metrics.to_h),
        "health_metrics" => JSON::Any.new(@health_metrics.to_h),
        "top_queries" => JSON::Any.new(@top_queries.to_h),
        "patterns" => JSON::Any.new(@patterns.to_h),
        "issues" => JSON::Any.new(@issues.map { |i| PerformanceMetrics.to_json_any(i.to_h) }),
      }
    end

    # Export as JSON
    def to_json : String
      to_h.to_json
    end

    # Get summary metrics for quick overview
    def summary : Hash(String, String | Int32 | Int64 | Float64)
      {
        "total_queries" => @query_metrics.total_queries,
        "slow_queries" => @query_metrics.slow_queries,
        "error_rate_percent" => @query_metrics.error_rate,
        "avg_query_time_ms" => @query_metrics.avg_execution_time.total_milliseconds,
        "n_plus_one_patterns" => @n_plus_one_metrics.total_patterns,
        "health_score" => @health_metrics.overall_health_score.to_s,
        "total_issues" => @health_metrics.total_issues,
        "uptime_seconds" => @system_metrics.uptime.total_seconds,
      }
    end

    # Check if performance is healthy
    def healthy? : Bool
      @health_metrics.overall_health_score >= 80
    end

    # Get critical issues only
    def critical_issues : Array(Issue)
      @issues.select(&.severity.== :critical)
    end

    # Get high priority issues
    def high_priority_issues : Array(Issue)
      @issues.select { |issue| [:critical, :high].includes?(issue.severity) }
    end

    # Get issues by type
    def issues_by_type(type : Symbol) : Array(Issue)
      @issues.select(&.type.== type)
    end

    # Get issues by severity
    def issues_by_severity(severity : Symbol) : Array(Issue)
      @issues.select(&.severity.== severity)
    end

    # Get slowest queries with details
    def slowest_queries(limit : Int32 = 10) : Array(QueryData)
      @top_queries.slowest_queries.first(limit)
    end

    # Get most frequent queries
    def most_frequent_queries(limit : Int32 = 10) : Array(NamedTuple(sql: String, count: Int64, avg_time: Time::Span))
      @top_queries.most_frequent_queries.first(limit)
    end

    # Get N+1 patterns by severity
    def n_plus_one_patterns_by_severity(severity : Symbol) : Array(NPlusOnePattern)
      @patterns.n_plus_one_patterns.select do |pattern|
        case severity
        when :critical then pattern.repetition_count > 50
        when :high     then pattern.repetition_count > 20
        when :medium   then pattern.repetition_count > 5
        when :low      then pattern.repetition_count > 2
        else                false
        end
      end
    end

    private def self.build_query_metrics(profiler : QueryProfilerInterface?, duration : Time::Span) : QueryMetrics
      unless profiler
        return QueryMetrics.new(
          0_i64, 0_i64, 0_i64, 0_i64,
          Time::Span.zero, Time::Span.zero, Time::Span.zero, Time::Span.zero,
          0.0, 0.0, 0.0
        )
      end

      stats = profiler.statistics
      total_queries = stats.values.sum(&.[:count]).to_i64
      total_time = stats.values.sum(&.[:total_ms]).milliseconds
      avg_time = total_queries > 0 ? total_time / total_queries : Time::Span.zero
      min_time = stats.values.min_of?(&.[:min_ms]) || 0.0
      max_time = stats.values.max_of?(&.[:max_ms]) || 0.0

      # Count slow queries
      slow_queries = profiler.slowest_queries(1000).size.to_i64
      very_slow_queries = profiler.slowest_queries(1000).select { |q| q.execution_time > 1.second }.size.to_i64

      # Calculate rates
      error_rate = 0.0 # TODO: Track errors properly
      queries_per_second = duration.total_seconds > 0 ? total_queries.to_f64 / duration.total_seconds : 0.0
      slow_query_rate = total_queries > 0 ? (slow_queries.to_f64 / total_queries) * 100 : 0.0

      QueryMetrics.new(
        total_queries,
        slow_queries,
        very_slow_queries,
        0_i64, # error_queries
        total_time,
        avg_time,
        min_time.milliseconds,
        max_time.milliseconds,
        error_rate,
        queries_per_second,
        slow_query_rate
      )
    end

    private def self.build_n_plus_one_metrics(detector : NPlusOneDetectorInterface?) : NPlusOneMetrics
      unless detector
        return NPlusOneMetrics.new(0, 0, 0, 0, 0, 0_i64, 0.0, 0, 0.0)
      end

      patterns = detector.patterns
      total_patterns = patterns.size
      total_repetitions = patterns.sum(&.repetition_count).to_i64
      avg_repetitions = total_patterns > 0 ? total_repetitions.to_f64 / total_patterns : 0.0
      max_repetitions = patterns.max_of?(&.repetition_count) || 0

      # Count by severity
      critical_patterns = patterns.count { |p| p.repetition_count > 50 }
      high_patterns = patterns.count { |p| p.repetition_count > 20 && p.repetition_count <= 50 }
      medium_patterns = patterns.count { |p| p.repetition_count > 5 && p.repetition_count <= 20 }
      low_patterns = patterns.count { |p| p.repetition_count > 2 && p.repetition_count <= 5 }

      # Detection rate (placeholder)
      detection_rate = 0.0

      NPlusOneMetrics.new(
        total_patterns,
        critical_patterns,
        high_patterns,
        medium_patterns,
        low_patterns,
        total_repetitions,
        avg_repetitions,
        max_repetitions,
        detection_rate
      )
    end

    private def self.build_cache_metrics(cache : Cache?) : CacheMetrics
      unless cache
        return CacheMetrics.new(0_i64, 0_i64, 0, 0, 0.0, 0.0, 0_i64)
      end

      # Placeholder values - would need cache to expose these metrics
      CacheMetrics.new(
        0_i64, # cache_hits
        0_i64, # cache_misses
        cache.size,
        1000,  # max_cache_size
        0.0,   # hit_rate
        0.0,   # miss_rate
        0_i64  # evictions
      )
    end

    private def self.build_system_metrics(start_time : Time) : SystemMetrics
      uptime = Time.utc - start_time

      # Placeholder values - would need system monitoring
      SystemMetrics.new(
        uptime,
        0.0,   # memory_usage_mb
        0.0,   # cpu_usage_percent
        0,     # active_connections
        100,   # max_connections
        0.0    # connection_pool_utilization
      )
    end

    private def self.build_health_metrics(profiler : QueryProfilerInterface?, detector : NPlusOneDetectorInterface?, cache : Cache?) : HealthMetrics
      # Collect issues
      issues = collect_issues(profiler, detector)
      critical_issues = issues.count(&.severity.== :critical)
      high_issues = issues.count(&.severity.== :high)
      medium_issues = issues.count(&.severity.== :medium)
      low_issues = issues.count(&.severity.== :low)
      total_issues = issues.size

      # Calculate health scores
      query_health_score = calculate_query_health_score(profiler)
      n_plus_one_health_score = calculate_n_plus_one_health_score(detector)
      cache_health_score = calculate_cache_health_score(cache)
      system_health_score = 100 # Placeholder

      # Overall health score
      overall_health_score = ([
        query_health_score,
        n_plus_one_health_score,
        cache_health_score,
        system_health_score
      ].sum / 4).to_i

      HealthMetrics.new(
        overall_health_score,
        query_health_score,
        n_plus_one_health_score,
        cache_health_score,
        system_health_score,
        critical_issues,
        high_issues,
        medium_issues,
        low_issues,
        total_issues
      )
    end

    private def self.build_top_queries(profiler : QueryProfilerInterface?) : TopQueries
      unless profiler
        return TopQueries.new(
          [] of QueryData,
          [] of NamedTuple(sql: String, count: Int64, avg_time: Time::Span),
          [] of NamedTuple(sql: String, errors: Int64, error_rate: Float64),
          [] of NamedTuple(sql: String, total_time: Time::Span, count: Int64)
        )
      end

      # Slowest queries
      slowest_queries = profiler.slowest_queries(10)

      # Most frequent queries
      stats = profiler.statistics
      most_frequent = stats.map do |sql, stat|
        {
          sql: sql,
          count: stat[:count].to_i64,
          avg_time: stat[:avg_ms].milliseconds
        }
      end.sort_by(&.[:count]).reverse!.first(10)

      # Highest error queries (placeholder)
      highest_error_queries = [] of NamedTuple(sql: String, errors: Int64, error_rate: Float64)

      # Most expensive queries (total time)
      most_expensive = stats.map do |sql, stat|
        {
          sql: sql,
          total_time: stat[:total_ms].milliseconds,
          count: stat[:count].to_i64
        }
      end.sort_by(&.[:total_time]).reverse!.first(10)

      TopQueries.new(slowest_queries, most_frequent, highest_error_queries, most_expensive)
    end

    private def self.build_performance_patterns(profiler : QueryProfilerInterface?, detector : NPlusOneDetectorInterface?) : PerformancePatterns
      # N+1 patterns
      n_plus_one_patterns = detector.try(&.patterns) || [] of NPlusOnePattern

      # Query patterns
      query_patterns = [] of NamedTuple(pattern: String, count: Int64, avg_time: Time::Span)
      if profiler
        stats = profiler.statistics
        query_patterns = stats.map do |sql, stat|
          {
            pattern: sql,
            count: stat[:count].to_i64,
            avg_time: stat[:avg_ms].milliseconds
          }
        end.sort_by(&.[:count]).reverse!.first(20)
      end

      # Time distribution
      time_distribution = {
        "fast" => 0_i64,
        "slow" => 0_i64,
        "very_slow" => 0_i64
      }

      # Error patterns (placeholder)
      error_patterns = [] of NamedTuple(error_type: String, count: Int64, percentage: Float64)

      PerformancePatterns.new(n_plus_one_patterns, query_patterns, time_distribution, error_patterns)
    end

    private def self.collect_issues(profiler : QueryProfilerInterface?, detector : NPlusOneDetectorInterface?) : Array(Issue)
      issues = [] of Issue
      issues.concat(profiler.try(&.issues) || [] of Issue)
      issues.concat(detector.try(&.issues) || [] of Issue)
      issues
    end

    private def self.calculate_query_health_score(profiler : QueryProfilerInterface?) : Int32
      return 100 unless profiler

      stats = profiler.statistics
      return 100 if stats.empty?

      total_queries = stats.values.sum(&.[:count])
      slow_queries = profiler.slowest_queries(1000).size
      very_slow_queries = profiler.slowest_queries(1000).select { |q| q.execution_time > 1.second }.size

      score = 100
      score -= (slow_queries.to_f / total_queries * 20).to_i if total_queries > 0
      score -= (very_slow_queries.to_f / total_queries * 40).to_i if total_queries > 0
      [score, 0].max
    end

    private def self.calculate_n_plus_one_health_score(detector : NPlusOneDetectorInterface?) : Int32
      return 100 unless detector

      patterns = detector.patterns
      return 100 if patterns.empty?

      critical_patterns = patterns.count { |p| p.repetition_count > 50 }
      high_patterns = patterns.count { |p| p.repetition_count > 20 }

      score = 100
      score -= critical_patterns * 30
      score -= high_patterns * 15
      [score, 0].max
    end

    private def self.calculate_cache_health_score(cache : Cache?) : Int32
      return 100 unless cache

      # Placeholder - would need cache hit/miss metrics
      100
    end
  end

  # Extension methods for QueryData to support to_h
  struct QueryData
    def to_h : Hash(String, JSON::Any)
      {
        "sql" => JSON::Any.new(@sql),
        "params" => PerformanceMetrics.to_json_any(@params),
        "execution_time_ms" => JSON::Any.new(@execution_time.total_milliseconds),
        "timestamp" => JSON::Any.new(@timestamp.to_rfc3339),
        "rows_affected" => JSON::Any.new(@rows_affected || 0_i64),
        "error" => JSON::Any.new(@error || ""),
        "normalized_sql" => JSON::Any.new(normalized_sql),
      }
    end
  end

  # Extension methods for NPlusOnePattern to support to_h
  struct NPlusOnePattern
    def to_h : Hash(String, JSON::Any)
      {
        "parent_query" => JSON::Any.new(@parent_query),
        "repeated_query" => JSON::Any.new(@repeated_query),
        "repetition_count" => JSON::Any.new(@repetition_count),
        "timestamp" => JSON::Any.new(@timestamp.to_rfc3339),
      }
    end
  end

  # Extension methods for Issue to support to_h
  struct Issue
    def to_h : Hash(String, JSON::Any)
      {
        "type" => JSON::Any.new(@type.to_s),
        "severity" => JSON::Any.new(@severity.to_s),
        "message" => JSON::Any.new(@message),
        "details" => PerformanceMetrics.to_json_any(@details),
        "timestamp" => JSON::Any.new(@timestamp.to_rfc3339),
      }
    end
  end
end
