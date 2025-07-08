# Performance Monitor with Dependency Injection
# Uses direct method calls by default, event system is optional

require "db"
require "./utilities"
require "./config"
require "./sql_formatter"
require "./query_profiler"
require "./n_plus_one_detector"
require "./unified_report_generator"

module CQL::Performance
  # Component interfaces for dependency injection
  abstract class QueryProfilerInterface
    abstract def record_query(sql : String, params : Array(DB::Any),
                              execution_time : Time::Span,
                              rows_affected : Int64? = nil,
                              error : String? = nil) : Void
    abstract def statistics
    abstract def slowest_queries(limit : Int32) : Array(QueryData)
    abstract def issues : Array(Issue)
    abstract def clear : Void
  end

  abstract class NPlusOneDetectorInterface
    abstract def record_query(sql : String) : Void
    abstract def start_relation_loading(relation_name : String, parent_model : String) : Void
    abstract def end_relation_loading : Void
    abstract def patterns
    abstract def issues : Array(Issue)
    abstract def clear : Void
  end

  # Monitor with dependency injection
  class Monitor
    include TimingUtils

    Log = ::Log.for(self)

    @config : Config
    @profiler : QueryProfilerInterface?
    @detector : NPlusOneDetectorInterface?
    @sql_formatter : SQLFormatter
    @report_generator : UnifiedReportGenerator
    @start_time : Time = Time.utc
    @context : String? = nil

    def initialize(@config : Config = Config.from_env,
                   @profiler : QueryProfilerInterface? = nil,
                   @detector : NPlusOneDetectorInterface? = nil,
                   @sql_formatter : SQLFormatter? = nil,
                   @report_generator : UnifiedReportGenerator? = nil)
      # Use provided components or create defaults
      @profiler ||= QueryProfiler.new(@config.profiling) if @config.profiling.enabled?
      @detector ||= NPlusOneDetector.new(@config.detection) if @config.detection.enabled?
      @sql_formatter ||= create_sql_formatter
      @report_generator ||= UnifiedReportGenerator.new
    end

    # Main monitoring methods
    def monitor_query(sql : String, params : Array(DB::Any) = [] of DB::Any, &)
      return yield unless enabled?

      # Execute and measure
      result, execution_time = measure_execution { yield }

      # Extract metadata
      rows_affected = extract_rows_affected(result)

      # Record in components
      record_execution(sql, params, execution_time, rows_affected)

      # Log if configured
      log_query(sql, params, execution_time, rows_affected) if @config.logging.enabled?

      result
    rescue ex
      # Record error
      record_execution(sql, params, Time::Span.zero, nil, ex.message)
      raise ex
    end

    # API - just wrap the query
    def track(sql : String, params : Array(DB::Any) = [] of DB::Any, &)
      monitor_query(sql, params) { yield }
    end

    # Relation loading hooks
    def start_relation_loading(relation_name : String, parent_model : String)
      @detector.try(&.start_relation_loading(relation_name, parent_model))
    end

    def end_relation_loading
      @detector.try(&.end_relation_loading)
    end

    # Context management
    def with_context(context : String, &)
      old_context = @context
      @context = context
      yield
    ensure
      @context = old_context
    end

    # Report generation
    def generate_report(format : String? = nil) : String
      format ||= @config.reporting.format

      # Collect data from components
      report = build_performance_report

      # Generate formatted report
      @report_generator.generate(format, report)
    end

    # Component access
    def profiler : QueryProfilerInterface?
      @profiler
    end

    def detector : NPlusOneDetectorInterface?
      @detector
    end

    # Clear all data
    def clear
      @profiler.try(&.clear)
      @detector.try(&.clear)
    end

    # Check if monitoring is enabled
    def enabled? : Bool
      @config.enabled?
    end

    # Configuration
    def configure(&)
      yield @config
      reconfigure_components
    end

    private def record_execution(sql : String, params : Array(DB::Any),
                                 execution_time : Time::Span,
                                 rows_affected : Int64? = nil,
                                 error : String? = nil)
      # Record in profiler
      @profiler.try(&.record_query(sql, params, execution_time, rows_affected, error))

      # Record in N+1 detector
      @detector.try(&.record_query(sql)) unless error
    end

    private def log_query(sql : String, params : Array(DB::Any),
                          execution_time : Time::Span, rows_affected : Int64?)
      output = @sql_formatter.format(sql, params, execution_time, rows_affected, @context)

      # Determine log level based on execution time
      case categorize_duration(execution_time,
        @config.profiling.slow_query_threshold,
        @config.profiling.very_slow_threshold)
      when :very_slow
        Log.error { output }
      when :slow
        Log.warn { output }
      else
        Log.info { output }
      end
    end

    private def extract_rows_affected(result) : Int64?
      return nil unless result.responds_to?(:rows_affected)
      result.rows_affected.to_i64
    rescue
      nil
    end

    private def build_performance_report : PerformanceReport
      duration = Time.utc - @start_time

      # Collect metrics
      profiler_stats = @profiler.try(&.statistics) || {} of String => NamedTuple(
        count: Int32,
        total_ms: Float64,
        avg_ms: Float64,
        min_ms: Float64,
        max_ms: Float64)

      total_queries = profiler_stats.values.sum(&.[:count])
      slow_queries = @profiler.try(&.slowest_queries(1000).size) || 0

      # Collect issues from all components
      all_issues = [] of Issue
      all_issues.concat(@profiler.try(&.issues) || [] of Issue)
      all_issues.concat(@detector.try(&.issues) || [] of Issue)

      # Convert stats to StatsTracker format
      stats = {} of String => StatsTracker

      PerformanceReport.new(
        duration: duration,
        total_queries: total_queries,
        slow_queries: slow_queries,
        errors: 0, # TODO: Track errors
        issues: all_issues,
        stats: stats,
        metadata: {
          "environment"        => ENV["CRYSTAL_ENV"]? || "development",
          "monitoring_enabled" => enabled?.to_s,
        }
      )
    end

    private def create_sql_formatter : SQLFormatter
      SQLFormatter.new(
        colorize_enabled: @config.logging.colorize?,
        pretty_format: @config.logging.pretty_format?,
        max_sql_length: @config.logging.max_sql_length,
        max_param_length: @config.logging.max_param_length
      )
    end

    private def reconfigure_components
      # Update SQL formatter
      @sql_formatter.configure(
        colorize: @config.logging.colorize?,
        pretty: @config.logging.pretty_format?,
        max_sql: @config.logging.max_sql_length,
        max_param: @config.logging.max_param_length
      )

      # Recreate components if needed
      if @config.profiling.enabled? && @profiler.nil?
        @profiler = QueryProfiler.new(@config.profiling)
      elsif !@config.profiling.enabled?
        @profiler = nil
      end

      if @config.detection.enabled? && @detector.nil?
        @detector = NPlusOneDetector.new(@config.detection)
      elsif !@config.detection.enabled?
        @detector = nil
      end
    end
  end

  # Global monitor instance
  @@monitor : Monitor?

  def self.monitor : Monitor
    @@monitor ||= Monitor.new
  end

  def self.monitor=(monitor : Monitor)
    @@monitor = monitor
  end

  # Convenience methods
  def self.track(sql : String, params : Array(DB::Any) = [] of DB::Any, &)
    monitor.track(sql, params) { yield }
  end

  def self.with_context(context : String, &)
    monitor.with_context(context) { yield }
  end

  def self.start_relation_loading(relation : String, model : String)
    monitor.start_relation_loading(relation, model)
  end

  def self.end_relation_loading
    monitor.end_relation_loading
  end

  def self.report(format : String? = nil) : String
    monitor.generate_report(format)
  end

  def self.configure(&)
    monitor.configure { |config| yield config }
  end
end
