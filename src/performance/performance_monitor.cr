# Refactored Performance Monitor using Facade Pattern and Dependency Injection
# Orchestrates all performance monitoring components following SOLID principles

require "./interfaces"
require "./event_system"
require "./analyzers/query_plan_analyzer"
require "./detectors/n_plus_one_detector"
require "./profilers/query_profiler"
require "./reports/report_generators"

module CQL::Performance
  Log = ::Log.for(self)

  # Configuration for the performance monitor
  struct PerformanceConfig
    property? plan_analysis_enabled : Bool = true
    property? n_plus_one_detection_enabled : Bool = true
    property? query_profiling_enabled : Bool = true
    property? auto_analyze_slow_queries : Bool = true
    property? context_tracking_enabled : Bool = true
    property? endpoint_tracking_enabled : Bool = false
    property? async_processing : Bool = false
    property current_endpoint : String? = nil
    property current_user_id : String? = nil

    def initialize
    end
  end

  # Metrics summary data structure
  struct PerformanceMetrics
    getter total_queries : Int32
    getter slow_queries : Int32
    getter n_plus_one_patterns : Int32
    getter avg_query_time : Float64
    getter? monitoring_enabled : Bool
    getter uptime : Time::Span

    def initialize(@total_queries : Int32, @slow_queries : Int32, @n_plus_one_patterns : Int32,
                   @avg_query_time : Float64, @monitoring_enabled : Bool, @uptime : Time::Span)
    end
  end

  # Main Performance Monitor using Facade Pattern
  class PerformanceMonitor
    Log = ::Log.for(self)

    @config : PerformanceConfig
    @event_bus : EventPublisher
    @query_analyzer : Analyzers::StrategyBasedQueryAnalyzer?
    @n_plus_one_detector : Detectors::NPlusOneDetector
    @query_profiler : Profilers::QueryProfiler
    @schema : Schema?
    @start_time : Time

    def initialize(@config : PerformanceConfig = PerformanceConfig.new)
      @start_time = Time.utc

      # Initialize event system
      @event_bus = if @config.async_processing?
                     AsyncEventBus.new
                   else
                     EventBus.new
                   end

      # Initialize components
      @n_plus_one_detector = create_n_plus_one_detector
      @query_profiler = create_query_profiler

      # Subscribe components to events
      @event_bus.subscribe(@n_plus_one_detector)
      @event_bus.subscribe(@query_profiler)
    end

    # Initialize with schema for plan analysis
    def initialize_with_schema(schema : Schema, config : PerformanceConfig = PerformanceConfig.new)
      initialize(config)
      @schema = schema
      @query_analyzer = Analyzers::StrategyBasedQueryAnalyzer.new(schema) if @config.plan_analysis_enabled?
    end

    # Alternative constructor with dependency injection
    def self.create_with_dependencies(event_bus : EventPublisher,
                                      query_analyzer : Analyzers::StrategyBasedQueryAnalyzer?,
                                      n_plus_one_detector : Detectors::NPlusOneDetector,
                                      query_profiler : Profilers::QueryProfiler,
                                      config : PerformanceConfig = PerformanceConfig.new)
      monitor = allocate
      monitor.initialize_with_dependencies(event_bus, query_analyzer, n_plus_one_detector, query_profiler, config)
      monitor
    end

    # For dependency injection
    protected def initialize_with_dependencies(@event_bus : EventPublisher,
                                               @query_analyzer : Analyzers::StrategyBasedQueryAnalyzer?,
                                               @n_plus_one_detector : Detectors::NPlusOneDetector,
                                               @query_profiler : Profilers::QueryProfiler,
                                               @config : PerformanceConfig)
      @start_time = Time.utc
      @schema = nil

      @event_bus.subscribe(@n_plus_one_detector)
      @event_bus.subscribe(@query_profiler)
    end

    # Main monitoring hooks
    def before_query(sql : String, params : Array(DB::Any) = [] of DB::Any) : Void
      return unless enabled?

      Log.debug { "Performance monitoring before query: #{sql[0..50]}..." }

      # No specific actions needed before query in event-driven architecture
      # The actual processing happens in after_query
    end

    def after_query(sql : String, params : Array(DB::Any), execution_time : Time::Span,
                    rows_affected : Int64? = nil) : Void
      return unless enabled?

      context = build_context()

      # Create and publish query execution event
      event = QueryExecutionEvent.new(
        sql: sql,
        params: params,
        execution_time: execution_time,
        rows_affected: rows_affected,
        timestamp: Time.utc,
        context: context
      )

      @event_bus.publish(event)

      # Auto-analyze slow queries if enabled
      if @config.auto_analyze_slow_queries? && @query_analyzer &&
         execution_time > 100.milliseconds # threshold
        analyze_slow_query(sql, params, execution_time)
      end

      Log.debug { "Performance monitoring after query: #{execution_time.total_milliseconds.round(2)}ms" }
    end

    # Relation loading tracking
    def start_relation_loading(relation_name : String, parent_model : String) : Void
      return unless @config.n_plus_one_detection_enabled?

      event = RelationLoadingEvent.new(
        relation_name: relation_name,
        parent_model: parent_model,
        loading_type: RelationLoadingEvent::LoadingType::Started,
        context: build_context()
      )

      @event_bus.publish(event)
    end

    def end_relation_loading : Void
      return unless @config.n_plus_one_detection_enabled?

      # We need to track which relation loading ended, but for simplicity
      # we'll create a generic event. In a real implementation, you'd track the stack.
      event = RelationLoadingEvent.new(
        relation_name: "unknown",
        parent_model: "unknown",
        loading_type: RelationLoadingEvent::LoadingType::Ended,
        context: build_context()
      )

      @event_bus.publish(event)
    end

    # Context management
    def set_context(endpoint : String? = nil, user_id : String? = nil) : Void
      @config.current_endpoint = endpoint
      @config.current_user_id = user_id
    end

    # Query plan analysis
    def analyze_query_plan(sql : String, params : Array(DB::Any) = [] of DB::Any) : Analyzers::QueryPlanResult?
      return nil unless @query_analyzer && @config.plan_analysis_enabled?

      @query_analyzer.try(&.analyze(sql, params).as?(Analyzers::QueryPlanResult))
    end

    def analyze_query_plan_with_execution(sql : String, params : Array(DB::Any) = [] of DB::Any) : Analyzers::QueryPlanResult?
      return nil unless @query_analyzer && @config.plan_analysis_enabled?

      @query_analyzer.try(&.analyze_with_execution(sql, params))
    end

    # Report generation using Strategy Pattern
    def generate_comprehensive_report(format : String = "text") : String
      generator = Reports::ReportGeneratorFactory.create(format)

      report_data = ReportData.new(
        events: [] of MonitoringEvent, # Could collect from event bus if needed
        issues: collect_all_issues(),
        metadata: {
          "generated_at"       => Time.utc.to_s,
          "uptime"             => (Time.utc - @start_time).to_s,
          "monitoring_enabled" => enabled?.to_s,
        }
      )

      generator.generate(report_data)
    end

    def n_plus_one_report : String
      @n_plus_one_detector.generate_report
    end

    def profiling_report(format : String = "text") : String
      @query_profiler.generate_report(format)
    end

    # Performance metrics
    def metrics_summary : PerformanceMetrics
      stats = @query_profiler.statistics
      total_queries = stats.values.sum(&.execution_count)
      slow_queries = @query_profiler.slow_queries.size
      n_plus_one_patterns = @n_plus_one_detector.issues.size
      avg_query_time = stats.empty? ? 0.0 : stats.values.sum(&.avg_time.total_milliseconds) / stats.size

      PerformanceMetrics.new(
        total_queries: total_queries,
        slow_queries: slow_queries,
        n_plus_one_patterns: n_plus_one_patterns,
        avg_query_time: avg_query_time,
        monitoring_enabled: enabled?,
        uptime: Time.utc - @start_time
      )
    end

    # Data management
    def clear_data : Void
      @n_plus_one_detector.clear_issues
      @query_profiler.clear_data
    end

    # Configuration management
    def configure(& : PerformanceConfig ->) : Void
      yield @config

      # Update component configurations
      @n_plus_one_detector.enabled = @config.n_plus_one_detection_enabled?

      @query_profiler.configure do |profiler_config|
        profiler_config.enabled = @config.query_profiling_enabled?
      end
    end

    def config : PerformanceConfig
      @config
    end

    def enabled? : Bool
      @config.plan_analysis_enabled? || @config.n_plus_one_detection_enabled? || @config.query_profiling_enabled?
    end

    # Component access (for advanced usage)
    def event_bus : EventPublisher
      @event_bus
    end

    def query_analyzer : Analyzers::StrategyBasedQueryAnalyzer?
      @query_analyzer
    end

    def n_plus_one_detector : Detectors::NPlusOneDetector
      @n_plus_one_detector
    end

    def query_profiler : Profilers::QueryProfiler
      @query_profiler
    end

    private def create_n_plus_one_detector : Detectors::NPlusOneDetector
      config = Detectors::NPlusOneConfig.new
      config.enabled = @config.n_plus_one_detection_enabled?
      config.strict_mode = ENV["CQL_N_PLUS_ONE_STRICT"]? ? true : false

      Detectors::NPlusOneDetector.new(config)
    end

    private def create_query_profiler : Profilers::QueryProfiler
      config = Profilers::ProfilerConfig.new
      config.enabled = @config.query_profiling_enabled?
      config.log_slow_queries = true
      config.enable_memory_tracking = false

      Profilers::QueryProfiler.new(config)
    end

    private def analyze_slow_query(sql : String, params : Array(DB::Any), execution_time : Time::Span) : Void
      Log.info { "Auto-analyzing slow query (#{execution_time.total_milliseconds.round(2)}ms)" }

      if plan = @query_analyzer.try(&.analyze_with_execution(sql, params))
        if plan.has_issues?
          Log.warn { "Slow query has performance issues: #{plan.warnings.join(", ")}" }
        end
      end
    end

    private def build_context : String?
      return nil unless @config.context_tracking_enabled?

      context_parts = [] of String
      context_parts << "endpoint:#{@config.current_endpoint}" if @config.current_endpoint
      context_parts << "user:#{@config.current_user_id}" if @config.current_user_id

      context_parts.empty? ? nil : context_parts.join("|")
    end

    private def collect_all_issues : Array(PerformanceIssue)
      issues = [] of PerformanceIssue
      issues.concat(@n_plus_one_detector.issues)
      issues.concat(@query_profiler.issues)
      issues
    end
  end

  # Global monitor instance (Singleton pattern)
  @@monitor : PerformanceMonitor?

  def self.monitor : PerformanceMonitor
    @@monitor ||= PerformanceMonitor.new
  end

  def self.monitor=(monitor : PerformanceMonitor)
    @@monitor = monitor
  end

  def self.initialize_monitor(schema : Schema, config : PerformanceConfig = PerformanceConfig.new)
    monitor = PerformanceMonitor.new(config)
    monitor.initialize_with_schema(schema, config)
    @@monitor = monitor
  end

  # Convenience methods for global monitor
  def self.before_query(sql : String, params : Array(DB::Any) = [] of DB::Any)
    monitor.before_query(sql, params)
  end

  def self.after_query(sql : String, params : Array(DB::Any), execution_time : Time::Span, rows_affected : Int64? = nil)
    monitor.after_query(sql, params, execution_time, rows_affected)
  end

  def self.set_context(endpoint : String? = nil, user_id : String? = nil)
    monitor.set_context(endpoint, user_id)
  end

  def self.start_relation_loading(relation_name : String, parent_model : String)
    monitor.start_relation_loading(relation_name, parent_model)
  end

  def self.end_relation_loading
    monitor.end_relation_loading
  end

  # Benchmark a block of code with performance monitoring
  #
  # **Example**
  # ```
  # result = CQL::Performance.benchmark("SELECT * FROM users", [] of DB::Any) do
  #   # execute SQL logic here
  #   conn.exec(sql)
  # end
  # ```
  def self.benchmark(sql : String, params : Array(DB::Any) = [] of DB::Any, &)
    # Performance monitoring hook - before query
    start_time = Time.monotonic
    begin
      before_query(sql, params)
    rescue ex
      Log.debug { "Performance monitoring error (before): #{ex.message}" }
    end

    # Execute the block
    result = yield

    # Performance monitoring hook - after query
    execution_time = Time.monotonic - start_time
    begin
      rows_affected = if result.responds_to?(:rows_affected)
                        result.rows_affected.to_i64
                      else
                        nil
                      end
      after_query(sql, params, execution_time, rows_affected)
    rescue ex
      Log.debug { "Performance monitoring error (after): #{ex.message}" }
    end

    result
  end
end
