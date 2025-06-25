# Refactored N+1 Query Detector using Event-Driven Architecture
# Follows Single Responsibility Principle and implements EventListener

require "../interfaces"
require "../event_system"

module CQL::Performance::Detectors
  # N+1 Performance Issue
  struct NPlusOneIssue < PerformanceIssue
    include JSON::Serializable

    getter parent_query : String
    getter repeated_query : String
    getter repetition_count : Int32
    getter stack_trace : Array(String)

    def initialize(@parent_query : String, @repeated_query : String, @repetition_count : Int32,
                   @stack_trace : Array(String) = [] of String, detected_at : Time = Time.utc)
      severity = case @repetition_count
                 when 2..5
                   Severity::Low
                 when 6..20
                   Severity::Medium
                 when 21..50
                   Severity::High
                 else
                   Severity::Critical
                 end

      super("n_plus_one", severity, "N+1 query pattern detected", detected_at)
    end

    def summary : String
      String.build do |str|
        str << "N+1 Query Detected [#{severity}]:\n"
        str << "Parent Query: #{parent_query[0..100]}#{parent_query.size > 100 ? "..." : ""}\n"
        str << "Repeated Query: #{repeated_query[0..100]}#{repeated_query.size > 100 ? "..." : ""}\n"
        str << "Repetitions: #{repetition_count}\n"
        str << "Detected at: #{detected_at}\n"
        unless stack_trace.empty?
          str << "Stack trace:\n"
          stack_trace.first(5).each { |line| str << "  #{line}\n" }
        end
      end
    end

    def to_json(json : JSON::Builder)
      json.object do
        json.field "type", type
        json.field "severity", severity.to_s.downcase
        json.field "message", message
        json.field "detected_at", detected_at.to_rfc3339
        json.field "parent_query", parent_query
        json.field "repeated_query", repeated_query
        json.field "repetition_count", repetition_count
        json.field "stack_trace", stack_trace
      end
    end
  end

  # Query execution context for pattern detection
  private class QueryExecutionContext
    getter queries : Array(String) = [] of String
    getter execution_times : Array(Time) = [] of Time
    getter current_iteration : String? = nil
    property parent_query : String? = nil

    def add_query(sql : String)
      @queries << normalize_sql(sql)
      @execution_times << Time.utc
    end

    def start_iteration(context : String)
      @current_iteration = context
    end

    def end_iteration
      @current_iteration = nil
    end

    def detect_patterns(threshold : Int32 = 2) : Array(NPlusOneIssue)
      patterns = [] of NPlusOneIssue
      return patterns if queries.size < 3

      # Group queries by normalized form
      query_groups = {} of String => Array(Int32)
      queries.each_with_index do |query, index|
        query_groups[query] ||= [] of Int32
        query_groups[query] << index
      end

      # Look for repeated queries that follow a parent query
      query_groups.each do |query_sql, indices|
        next if indices.size < threshold

        # Check if this is likely an N+1 pattern
        if is_n_plus_one_pattern?(indices)
          parent_sql = find_parent_query(indices.first)
          stack = capture_stack_trace()

          issue = NPlusOneIssue.new(
            parent_query: parent_sql || "Unknown",
            repeated_query: query_sql,
            repetition_count: indices.size,
            stack_trace: stack
          )
          patterns << issue
        end
      end

      patterns
    end

    private def normalize_sql(sql : String) : String
      # Normalize SQL by removing parameter values to detect patterns
      sql.gsub(/\$\d+|\?/, "?")
        .gsub(/\b\d+\b/, "?")
        .gsub(/'.+?'/, "'?'")
        .gsub(/\s+/, " ")
        .strip
    end

    private def is_n_plus_one_pattern?(indices : Array(Int32)) : Bool
      return false if indices.size < 2

      # Check if queries are clustered together (indicating loop iteration)
      indices.each_cons(2) do |pair|
        return true if (pair[1] - pair[0]) <= 3 # Queries within 3 positions
      end

      false
    end

    private def find_parent_query(repeated_index : Int32) : String?
      # Look for the query that likely triggered the repeated queries
      return nil if repeated_index == 0

      queries[repeated_index - 1]?
    end

    private def capture_stack_trace : Array(String)
      # Capture current call stack for debugging using caller method
      caller.first(10)
    end
  end

  # Configuration for N+1 Detection
  struct NPlusOneConfig
    property enabled : Bool = true
    property threshold : Int32 = 2
    property strict_mode : Bool = false
    property ignore_patterns : Array(String) = [] of String

    def initialize
    end
  end

  # N+1 Query Detector implementing EventListener and PerformanceDetector
  class NPlusOneDetector < EventListener
    Log = ::Log.for(self)

    @config : NPlusOneConfig
    @contexts : Hash(Fiber, QueryExecutionContext) = {} of Fiber => QueryExecutionContext
    @detected_issues : Array(NPlusOneIssue) = [] of NPlusOneIssue
    @relation_loading_stack : Array(String) = [] of String

    def initialize(@config : NPlusOneConfig = NPlusOneConfig.new)
    end

    # EventListener implementation
    def handle_event(event : MonitoringEvent) : Void
      case event
      when QueryExecutionEvent
        handle_query_event(event)
      when RelationLoadingEvent
        handle_relation_event(event)
      end
    end

    # PerformanceDetector implementation
    def process_event(event : MonitoringEvent) : Array(PerformanceIssue)
      handle_event(event)

      # Check for new patterns after each event
      new_patterns = check_for_patterns()
      new_patterns.map(&.as(PerformanceIssue))
    end

    def get_issues : Array(PerformanceIssue)
      @detected_issues.map(&.as(PerformanceIssue))
    end

    def clear_issues : Void
      @detected_issues.clear
      @contexts.clear
    end

    # Configuration management
    def configure(& : NPlusOneConfig ->)
      yield @config
    end

    def enabled=(value : Bool)
      @config.enabled = value
    end

    def enabled? : Bool
      @config.enabled
    end

    # Generate report
    def generate_report : String
      return "No N+1 queries detected." if @detected_issues.empty?

      String.build do |str|
        str << "N+1 Query Detection Report\n"
        str << "========================\n\n"

        severity_counts = @detected_issues.group_by(&.severity)
        severity_counts.each do |severity, patterns|
          str << "#{severity} Severity: #{patterns.size} patterns\n"
        end
        str << "\nDetailed Patterns:\n\n"

        @detected_issues.each_with_index do |issue, i|
          str << "#{i + 1}. #{issue.summary}\n"
          str << "---\n"
        end
      end
    end

    private def handle_query_event(event : QueryExecutionEvent)
      return unless @config.enabled
      return if should_ignore_query?(event.sql)

      current_context.add_query(event.sql)
    end

    private def handle_relation_event(event : RelationLoadingEvent)
      return unless @config.enabled

      case event.loading_type
      when RelationLoadingEvent::LoadingType::Started
        relation_info = "#{event.parent_model}.#{event.relation_name}"
        @relation_loading_stack.push(relation_info)
        current_context.start_iteration(relation_info)
        Log.debug { "Started relation loading: #{relation_info}" }
      when RelationLoadingEvent::LoadingType::Ended
        return if @relation_loading_stack.empty?

        info = @relation_loading_stack.pop
        current_context.end_iteration
        Log.debug { "Ended relation loading: #{info}" }
      end
    end

    private def should_ignore_query?(sql : String) : Bool
      normalized = sql.strip.downcase
      return true if normalized.starts_with?("explain")

      @config.ignore_patterns.any? { |pattern| normalized.includes?(pattern.downcase) }
    end

    private def check_for_patterns : Array(NPlusOneIssue)
      new_patterns = current_context.detect_patterns(@config.threshold)

      new_patterns.each do |pattern|
        @detected_issues << pattern
        Log.warn { "N+1 Query detected: #{pattern.summary}" }

        # Raise exception in strict mode for critical patterns
        if @config.strict_mode && pattern.severity.critical?
          raise NPlusOneError.new("Critical N+1 query detected: #{pattern.repeated_query}")
        end
      end

      new_patterns
    end

    private def current_context : QueryExecutionContext
      fiber = Fiber.current
      @contexts[fiber] ||= QueryExecutionContext.new
    end

    # Clean up finished fiber contexts
    def cleanup_contexts
      active_fibers = [] of Fiber
      # Note: In real implementation, you'd need to track active fibers
      # This is a simplified version
      @contexts.select! { |fiber, _| active_fibers.includes?(fiber) }
    end
  end

  # Exception for N+1 query detection
  class NPlusOneError < Exception; end
end
