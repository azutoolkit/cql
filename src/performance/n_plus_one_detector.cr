# N+1 Query Detection component for CQL Performance Tools
# Monitors query patterns to detect inefficient repetitive queries

require "../cql"

module CQL::Performance
  # Exception for N+1 query detection
  class NPlusOneError < Exception; end

  # Represents a detected N+1 query pattern
  struct NPlusOnePattern
    include JSON::Serializable

    getter parent_query : String
    getter repeated_query : String
    getter repetition_count : Int32
    getter detection_time : Time
    getter stack_trace : Array(String)
    getter severity : Severity

    enum Severity
      Low      # 2-5 repetitions
      Medium   # 6-20 repetitions
      High     # 21-50 repetitions
      Critical # 50+ repetitions
    end

    def initialize(@parent_query : String, @repeated_query : String,
                   @repetition_count : Int32, @detection_time : Time = Time.utc,
                   @stack_trace : Array(String) = [] of String)
      @severity = case @repetition_count
                  when 2..5
                    Severity::Low
                  when 6..20
                    Severity::Medium
                  when 21..50
                    Severity::High
                  else
                    Severity::Critical
                  end
    end

    def summary : String
      String.build do |str|
        str << "N+1 Query Detected [#{severity}]:\n"
        str << "Parent Query: #{parent_query[0..100]}#{parent_query.size > 100 ? "..." : ""}\n"
        str << "Repeated Query: #{repeated_query[0..100]}#{repeated_query.size > 100 ? "..." : ""}\n"
        str << "Repetitions: #{repetition_count}\n"
        str << "Detected at: #{detection_time}\n"
        unless stack_trace.empty?
          str << "Stack trace:\n"
          stack_trace.first(5).each { |line| str << "  #{line}\n" }
        end
      end
    end

    def to_json(json : JSON::Builder)
      json.object do
        json.field "parent_query", parent_query
        json.field "repeated_query", repeated_query
        json.field "repetition_count", repetition_count
        json.field "detection_time", detection_time.to_rfc3339
        json.field "severity", severity.to_s.downcase
        json.field "stack_trace", stack_trace
      end
    end
  end

  # Tracks query execution context for N+1 detection
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

    private def normalize_sql(sql : String) : String
      # Normalize SQL by removing parameter values to detect patterns
      sql.gsub(/\$\d+|\?/, "?")
        .gsub(/\b\d+\b/, "?")
        .gsub(/'.+?'/, "'?'")
        .gsub(/\s+/, " ")
        .strip
    end

    def detect_patterns : Array(NPlusOnePattern)
      patterns = [] of NPlusOnePattern
      return patterns if queries.size < 3

      # Group queries by normalized form
      query_groups = {} of String => Array(Int32)
      queries.each_with_index do |query, index|
        query_groups[query] ||= [] of Int32
        query_groups[query] << index
      end

      # Look for repeated queries that follow a parent query
      query_groups.each do |query_sql, indices|
        next if indices.size < 2

        # Check if this is likely an N+1 pattern
        if is_n_plus_one_pattern?(indices)
          parent_sql = find_parent_query(indices.first)
          stack = capture_stack_trace()

          pattern = NPlusOnePattern.new(
            parent_query: parent_sql || "Unknown",
            repeated_query: query_sql,
            repetition_count: indices.size,
            stack_trace: stack
          )
          patterns << pattern
        end
      end

      patterns
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

  # Main N+1 Query Detector
  class NPlusOneDetector
    Log = ::Log.for(self)

    @enabled : Bool
    @threshold : Int32
    @contexts : Hash(Fiber, QueryExecutionContext) = {} of Fiber => QueryExecutionContext
    @detected_patterns : Array(NPlusOnePattern) = [] of NPlusOnePattern
    @relation_loading_stack : Array(String) = [] of String

    def initialize(@enabled : Bool = true, @threshold : Int32 = 2)
    end

    # Enable/disable detection
    def enabled=(value : Bool)
      @enabled = value
    end

    def enabled? : Bool
      @enabled
    end

    # Record a query execution
    def record_query(sql : String)
      return unless @enabled
      return if sql.strip.downcase.starts_with?("explain")

      current_context.add_query(sql)
      check_for_patterns()
    end

    # Mark the start of relation loading
    def start_relation_loading(relation_info : String)
      return unless @enabled

      @relation_loading_stack.push(relation_info)
      current_context.start_iteration(relation_info)
      Log.debug { "Started relation loading: #{relation_info}" }
    end

    # Mark the end of relation loading
    def end_relation_loading
      return unless @enabled
      return if @relation_loading_stack.empty?

      info = @relation_loading_stack.pop
      current_context.end_iteration
      Log.debug { "Ended relation loading: #{info}" }
    end

    # Check for patterns in current context
    def check_for_patterns
      patterns = current_context.detect_patterns
      patterns.each do |pattern|
        next if pattern.repetition_count < @threshold

        @detected_patterns << pattern
        Log.warn { "N+1 Query detected: #{pattern.summary}" }

        # Raise exception for critical patterns in development
        if ENV["CQL_N_PLUS_ONE_STRICT"]? && pattern.severity.critical?
          raise NPlusOneError.new("Critical N+1 query detected: #{pattern.repeated_query}")
        end
      end
    end

    # Get detected patterns
    def detected_patterns : Array(NPlusOnePattern)
      @detected_patterns.dup
    end

    # Clear detected patterns
    def clear_patterns
      @detected_patterns.clear
    end

    # Get current execution context for the fiber
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

    # Generate a report of detected patterns
    def generate_report : String
      return "No N+1 queries detected." if @detected_patterns.empty?

      String.build do |str|
        str << "N+1 Query Detection Report\n"
        str << "========================\n\n"

        severity_counts = @detected_patterns.group_by(&.severity)
        severity_counts.each do |severity, patterns|
          str << "#{severity} Severity: #{patterns.size} patterns\n"
        end
        str << "\nDetailed Patterns:\n\n"

        @detected_patterns.each_with_index do |pattern, i|
          str << "#{i + 1}. #{pattern.summary}\n"
          str << "---\n"
        end
      end
    end
  end

  # Global detector instance
  @@detector : NPlusOneDetector?

  # Get global detector instance
  def self.n_plus_one_detector : NPlusOneDetector
    @@detector ||= NPlusOneDetector.new
  end

  # Set global detector
  def self.n_plus_one_detector=(detector : NPlusOneDetector)
    @@detector = detector
  end

  # Convenience methods for global detector
  def self.record_query(sql : String)
    n_plus_one_detector.record_query(sql)
  end

  def self.start_relation_loading(relation_info : String)
    n_plus_one_detector.start_relation_loading(relation_info)
  end

  def self.end_relation_loading
    n_plus_one_detector.end_relation_loading
  end
end
