# Performance Monitor with Dependency Injection
# Uses direct method calls by default, event system is optional

require "db"
require "./utilities"
require "./config"
require "./sql_formatter"
require "./query_profiler"
require "./n_plus_one_detector"
require "./unified_report_generator"
require "./performance_metrics"
require "./interfaces"
require "../cache/cache_store"

module CQL::Performance
  # Monitor with dependency injection
  class Monitor
    include TimingUtils

    Log = ::Log.for(self)

    private OVERHEAD_SAMPLE_INTERVAL = 64
    private FREE_CHECKOUT            = 1.microsecond

    private alias Statement = {CQL::Telemetry::QueryEvent, Array(DB::Any)}

    # Shared by every queued statement without params, so none holds an array its caller may reuse; never mutated.
    private EMPTY_PARAMS = [] of DB::Any

    @config : Config
    @queue : CQL::Telemetry::EventQueue(Statement)?
    @profiler : QueryProfilerInterface?
    @detector : NPlusOneDetectorInterface?
    @sql_formatter : SQLFormatter
    @report_generator : UnifiedReportGenerator
    @start_time : Time = Time.utc
    @error_count : Atomic(Int32) = Atomic(Int32).new(0)
    @observed_statements : Atomic(Int64) = Atomic(Int64).new(0)
    @sampled_overhead_ns : Atomic(Int64) = Atomic(Int64).new(0)
    @overhead_samples : Atomic(Int64) = Atomic(Int64).new(0)
    @pool_wait : StatsTracker = StatsTracker.new
    @free_checkouts : Atomic(Int64) = Atomic(Int64).new(0)
    @closed_queue_drops : Atomic(Int64) = Atomic(Int64).new(0)

    def initialize(
      config : Config = Config.from_env,
      profiler : QueryProfilerInterface? = nil,
      detector : NPlusOneDetectorInterface? = nil,
      sql_formatter : SQLFormatter? = nil,
      report_generator : UnifiedReportGenerator? = nil,
    )
      @config = config
      @profiler = profiler || (config.profiling.enabled? ? QueryProfiler.new(config.profiling).as(QueryProfilerInterface) : nil)
      @detector = detector || (config.detection.enabled? ? NPlusOneDetector.new(config.detection).as(NPlusOneDetectorInterface) : nil)
      @sql_formatter = sql_formatter || create_sql_formatter
      @report_generator = report_generator || UnifiedReportGenerator.new
      @queue = build_queue if config.monitoring.async?
    end

    # Main monitoring methods
    def monitor_query(sql : String, params : Array(DB::Any) = [] of DB::Any, &)
      return yield unless enabled?

      started = Time.instant
      begin
        result = yield
      rescue ex
        record_statement(sql, params, Time.instant - started, nil, ex)
        raise ex
      end
      record_statement(sql, params, Time.instant - started, (result.rows_affected if result.is_a?(DB::ExecResult)), nil)
      result
    end

    # Records a statement `CQL::Execution.run` has already timed, on the async queue's fiber when monitoring is async.
    def record(event : CQL::Telemetry::QueryEvent, params : Array(DB::Any)) : Nil
      if queue = @queue
        queue.push({event, event.params || (params.empty? ? EMPTY_PARAMS : params.map(&.dup))})
      else
        record_event(event, params)
      end
    end

    # True once every statement recorded before it was handled, at once when recording is synchronous; false on timeout.
    def flush(timeout : Time::Span? = nil) : Bool
      queue = @queue
      queue.nil? || queue.flush(timeout)
    end

    # Stops the async queue, skipping the statements it still holds; `record` is synchronous afterwards.
    def close : Nil
      if queue = @queue
        queue.close
        @closed_queue_drops.add(queue.dropped)
      end
      @queue = nil
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
      CQL::Telemetry.with_context(context) { yield }
    end

    # Report generation
    def generate_report(format : String? = nil) : String
      format ||= @config.reporting.format

      # Collect data from components
      report = build_performance_report

      # Generate formatted report
      @report_generator.generate(format, report)
    end

    # Get comprehensive performance metrics
    def metrics : PerformanceMetrics
      # Try to get cache instance if available
      cache_instance = get_cache_instance

      PerformanceMetrics.from_components(
        profiler: @profiler,
        detector: @detector,
        cache: cache_instance,
        start_time: @start_time,
        config: @config,
        error_count: @error_count.get,
        monitor: counters
      )
    end

    # What the monitor itself observed since it was built or last cleared; `overhead` is estimated from one statement in 64
    # and `pool_wait` counts a wait under 1 µs (a free connection) as zero.
    def counters : MonitorCounters
      observed = @observed_statements.get
      dropped = @closed_queue_drops.get + (@queue.try(&.dropped) || 0_i64)
      MonitorCounters.new(observed, estimated_overhead(observed), pool_wait_percentiles, dropped)
    end

    # Get metrics summary
    def metrics_summary : Hash(String, String | Int64 | Float64)
      metrics.summary
    end

    # Check if performance is healthy
    def healthy? : Bool
      metrics.healthy?
    end

    # Get critical issues
    def critical_issues : Array(Issue)
      metrics.critical_issues
    end

    # Get high priority issues
    def high_priority_issues : Array(Issue)
      metrics.high_priority_issues
    end

    # Component access
    def profiler : QueryProfilerInterface?
      @profiler
    end

    def detector : NPlusOneDetectorInterface?
      @detector
    end

    def error_count : Int32
      @error_count.get
    end

    # Clear all data
    def clear
      restart_queue
      @profiler.try(&.clear)
      @detector.try(&.clear)
      @error_count.set(0)
      @observed_statements.set(0)
      @sampled_overhead_ns.set(0)
      @overhead_samples.set(0)
      @pool_wait.reset
      @free_checkouts.set(0)
      @closed_queue_drops.set(0)
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

    # Drops the statements still queued, and the queue's drop count, by starting a new queue.
    private def restart_queue : Nil
      return unless @queue
      close
      @queue = build_queue
    end

    private def build_queue : CQL::Telemetry::EventQueue(Statement)
      CQL::Telemetry::EventQueue(Statement).new(@config.monitoring.async_queue_capacity) do |(event, params)|
        if context = event.context
          CQL::Telemetry.with_context(context) { record_event(event, params) }
        else
          record_event(event, params)
        end
      end
    end

    private def record_event(event : CQL::Telemetry::QueryEvent, params : Array(DB::Any)) : Nil
      record_statement(event.sql, params, event.duration, event.rows_affected, event.error, event.pool_wait)
    end

    private def record_statement(sql : String, params : Array(DB::Any), duration : Time::Span,
                                 rows_affected : Int64?, error : Exception?, pool_wait : Time::Span? = nil) : Nil
      index = @observed_statements.add(1)
      return record_safely(sql, params, duration, rows_affected, error, pool_wait) unless index % OVERHEAD_SAMPLE_INTERVAL == 0

      started = Time.instant
      record_safely(sql, params, duration, rows_affected, error, pool_wait)
      @sampled_overhead_ns.add((Time.instant - started).total_nanoseconds.to_i64)
      @overhead_samples.add(1)
    end

    private def estimated_overhead(observed : Int64) : Time::Span
      samples = @overhead_samples.get
      return Time::Span.zero if samples == 0
      (@sampled_overhead_ns.get.to_f64 / samples * observed).nanoseconds
    end

    private def record_pool_wait(wait : Time::Span) : Nil
      wait < FREE_CHECKOUT ? @free_checkouts.add(1) : @pool_wait.record(wait)
    end

    private def pool_wait_percentiles : LatencyPercentiles
      free = @free_checkouts.get
      waited = @pool_wait.total_count
      return LatencyPercentiles.zero if free + waited == 0

      LatencyPercentiles.new(pool_wait_quantile(0.5, free, waited), pool_wait_quantile(0.95, free, waited),
        pool_wait_quantile(0.99, free, waited))
    end

    # Free checkouts take the lowest ranks, so the quantile falls in the recorded waits only past them.
    private def pool_wait_quantile(q : Float64, free : Int64, waited : Int64) : Time::Span
      rank = (q * (free + waited)).ceil.to_i64
      return Time::Span.zero if rank <= free
      @pool_wait.percentile((rank - free).to_f64 / waited)
    end

    private def record_safely(sql : String, params : Array(DB::Any), duration : Time::Span,
                              rows_affected : Int64?, error : Exception?, pool_wait : Time::Span?) : Nil
      record_pool_wait(pool_wait) if pool_wait
      if error
        @error_count.add(1)
        record_execution(sql, params, duration, nil, error.message.to_s)
        Log.error { failure_message(error, sql, params) } if @config.logging.enabled?
      else
        record_execution(sql, params, duration, rows_affected)
        log_query(sql, params, duration, rows_affected) if @config.logging.enabled?
      end
    rescue ex
      Log.error(exception: ex) { "performance monitor failed to record a statement" }
    end

    private def record_execution(sql : String, params : Array(DB::Any),
                                 execution_time : Time::Span,
                                 rows_affected : Int64? = nil,
                                 error : String? = nil)
      profiler = @profiler
      detector = @detector unless error
      return unless profiler || detector

      error = error.try { |message| @sql_formatter.loggable_error(message) }
      normalized_sql = SQLUtils.normalize_sql(sql)
      profiler.try(&.record_query(sql, params, execution_time, rows_affected, error, normalized_sql: normalized_sql))
      detector.try(&.record_query(sql, normalized_sql: normalized_sql))
    end

    # Logs at a level chosen by duration; the message is formatted only if that level is emitted.
    private def log_query(sql : String, params : Array(DB::Any),
                          execution_time : Time::Span, rows_affected : Int64?)
      case categorize_duration(execution_time,
        @config.profiling.slow_query_threshold,
        @config.profiling.very_slow_threshold)
      when :very_slow
        Log.error { format_query(sql, params, execution_time, rows_affected) }
      when :slow
        Log.warn { format_query(sql, params, execution_time, rows_affected) }
      else
        Log.info { format_query(sql, params, execution_time, rows_affected) }
      end
    end

    private def format_query(sql : String, params : Array(DB::Any),
                             execution_time : Time::Span, rows_affected : Int64?) : String
      @sql_formatter.format(sql, params, execution_time, rows_affected, CQL::Telemetry.current_context)
    end

    private def failure_message(ex : Exception, sql : String, params : Array(DB::Any)) : String
      message = "Query failed: #{@sql_formatter.loggable_error(ex.message.to_s)}\nSQL: #{sql}"
      formatted_params = @sql_formatter.loggable_params(params)
      formatted_params ? "#{message}\nParams: #{formatted_params}" : message
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

      # Get stats trackers from profiler
      stats = @profiler.try(&.stats_trackers) || {} of String => StatsTracker

      PerformanceReport.new(
        duration: duration,
        total_queries: total_queries,
        slow_queries: slow_queries,
        errors: @error_count.get,
        issues: all_issues,
        stats: stats,
        latency: @profiler.try(&.latency_percentiles) || LatencyPercentiles.zero,
        metadata: {
          "environment"        => ENV["CRYSTAL_ENV"]? || "development",
          "monitoring_enabled" => enabled?.to_s,
          "error_count"        => @error_count.get.to_s,
        }
      )
    end

    private def create_sql_formatter : SQLFormatter
      SQLFormatter.new(
        colorize_enabled: @config.logging.colorize?,
        pretty_format: @config.logging.pretty_format?,
        max_sql_length: @config.logging.max_sql_length,
        max_param_length: @config.logging.max_param_length,
        include_params: @config.logging.include_params?
      )
    end

    private def get_cache_instance : CQL::Cache::CacheInterface?
      # Try to get cache instance from the cache system

      # Check if cache is available and configured
      if CQL::Cache::CacheStore.config
        CQL::Cache::CacheStore.instance
      end
    rescue
      nil
    end

    private def reconfigure_components
      # Update SQL formatter
      @sql_formatter.configure(
        colorize: @config.logging.colorize?,
        pretty: @config.logging.pretty_format?,
        max_sql: @config.logging.max_sql_length,
        max_param: @config.logging.max_param_length,
        include_params: @config.logging.include_params?
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

      @config.monitoring.async? ? (@queue ||= build_queue) : close
    end
  end

  # Global monitor instance
  @@monitor : Monitor?

  def self.monitor : Monitor
    @@monitor ||= Monitor.new
  end

  # Replacing the global monitor closes the old one, whose later statements are recorded inline.
  def self.monitor=(monitor : Monitor)
    previous = @@monitor
    @@monitor = monitor
    previous.close if previous && !previous.same?(monitor)
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
