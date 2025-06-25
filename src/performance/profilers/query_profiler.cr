# Refactored Query Profiler using Event-Driven Architecture
# Follows Single Responsibility Principle and implements EventListener

require "../interfaces"
require "../event_system"
require "json"

module CQL::Performance::Profilers
  # Query execution record
  struct QueryExecution
    include JSON::Serializable

    getter sql : String
    getter params : Array(DB::Any)
    getter execution_time : Time::Span
    getter timestamp : Time
    getter context : String?
    getter endpoint : String?
    getter user_id : String?
    getter rows_affected : Int64?
    getter memory_usage : Int64?

    def initialize(@sql : String, @params : Array(DB::Any), @execution_time : Time::Span,
                   @timestamp : Time = Time.utc, @context : String? = nil,
                   @endpoint : String? = nil, @user_id : String? = nil,
                   @rows_affected : Int64? = nil, @memory_usage : Int64? = nil)
    end

    def slow?(threshold : Time::Span = 100.milliseconds) : Bool
      @execution_time > threshold
    end

    def normalized_sql : String
      # Remove parameters and normalize whitespace for grouping
      @sql.gsub(/\$\d+|\?/, "?")
        .gsub(/\b\d+\b/, "?")
        .gsub(/'.+?'/, "'?'")
        .gsub(/\s+/, " ")
        .strip
    end

    def to_json(json : JSON::Builder)
      json.object do
        json.field "sql", sql
        json.field "params", params.map(&.to_s)
        json.field "execution_time_ms", execution_time.total_milliseconds
        json.field "timestamp", timestamp.to_rfc3339
        json.field "context", context
        json.field "endpoint", endpoint
        json.field "user_id", user_id
        json.field "rows_affected", rows_affected
        json.field "memory_usage", memory_usage
        json.field "slow", slow?
      end
    end
  end

  # Query performance statistics
  struct QueryStats
    include JSON::Serializable

    getter normalized_sql : String
    getter execution_count : Int32
    getter total_time : Time::Span
    getter min_time : Time::Span
    getter max_time : Time::Span
    getter avg_time : Time::Span
    getter last_executed : Time
    getter contexts : Set(String)

    def initialize(@normalized_sql : String)
      @execution_count = 0
      @total_time = Time::Span.zero
      @min_time = Time::Span::MAX
      @max_time = Time::Span.zero
      @avg_time = Time::Span.zero
      @last_executed = Time.utc
      @contexts = Set(String).new
    end

    def add_execution(execution : QueryExecution)
      @execution_count += 1
      @total_time += execution.execution_time
      @min_time = [@min_time, execution.execution_time].min
      @max_time = [@max_time, execution.execution_time].max
      @avg_time = @total_time / @execution_count
      @last_executed = execution.timestamp
      if ctx = execution.context
        @contexts << ctx
      end
    end

    def performance_score : Float64
      # Calculate a performance score (lower is better)
      base_score = avg_time.total_milliseconds
      frequency_penalty = Math.log10(@execution_count + 1) * 10
      max_time_penalty = (@max_time.total_milliseconds - avg_time.total_milliseconds) * 0.1

      base_score + frequency_penalty + max_time_penalty
    end

    def to_json(json : JSON::Builder)
      json.object do
        json.field "normalized_sql", normalized_sql
        json.field "execution_count", execution_count
        json.field "total_time_ms", total_time.total_milliseconds
        json.field "min_time_ms", min_time.total_milliseconds
        json.field "max_time_ms", max_time.total_milliseconds
        json.field "avg_time_ms", avg_time.total_milliseconds
        json.field "last_executed", last_executed.to_rfc3339
        json.field "performance_score", performance_score
        json.field "contexts", contexts.to_a
      end
    end
  end

  # Configuration for the query profiler
  struct ProfilerConfig
    property enabled : Bool = true
    property slow_query_threshold : Time::Span = 100.milliseconds
    property very_slow_threshold : Time::Span = 1.second
    property log_all_queries : Bool = false
    property log_slow_queries : Bool = true
    property max_recorded_queries : Int32 = 10_000
    property enable_memory_tracking : Bool = false
    property endpoints_to_track : Array(String) = [] of String
    property queries_to_ignore : Array(String) = ["COMMIT", "BEGIN", "ROLLBACK"]

    def initialize
    end
  end

  # Slow Query Performance Issue
  struct SlowQueryIssue < PerformanceIssue
    include JSON::Serializable

    getter execution : QueryExecution

    def initialize(@execution : QueryExecution, threshold : Time::Span)
      severity = if execution.execution_time > 5.seconds
                   Severity::Critical
                 elsif execution.execution_time > 1.second
                   Severity::High
                 elsif execution.execution_time > 500.milliseconds
                   Severity::Medium
                 else
                   Severity::Low
                 end

      super("slow_query", severity, "Slow query detected", execution.timestamp)
    end

    def summary : String
      "Slow Query (#{execution.execution_time.total_milliseconds.round(2)}ms): #{execution.sql[0..100]}..."
    end

    def to_json(json : JSON::Builder)
      json.object do
        json.field "type", type
        json.field "severity", severity.to_s.downcase
        json.field "message", message
        json.field "detected_at", detected_at.to_rfc3339
        json.field "execution_time_ms", execution.execution_time.total_milliseconds
        json.field "sql", execution.sql
        json.field "params", execution.params.map(&.to_s)
      end
    end
  end

  # Event-driven Query Profiler
  class QueryProfiler < EventListener
    Log = ::Log.for(self)

    @config : ProfilerConfig
    @executions : Array(QueryExecution) = [] of QueryExecution
    @stats : Hash(String, QueryStats) = {} of String => QueryStats
    @endpoint_stats : Hash(String, Array(QueryExecution)) = {} of String => Array(QueryExecution)
    @slow_queries : Array(QueryExecution) = [] of QueryExecution
    @detected_issues : Array(SlowQueryIssue) = [] of SlowQueryIssue
    @start_time : Time

    def initialize(@config : ProfilerConfig = ProfilerConfig.new)
      @start_time = Time.utc
    end

    # EventListener implementation
    def handle_event(event : MonitoringEvent) : Void
      case event
      when QueryExecutionEvent
        handle_query_execution(event)
      end
    end

    # PerformanceDetector-like methods
    def process_event(event : MonitoringEvent) : Array(PerformanceIssue)
      handle_event(event)

      issues = [] of PerformanceIssue
      if event.is_a?(QueryExecutionEvent)
        # Check for slow query issues
        execution = create_execution_from_event(event)
        if execution.slow?(@config.slow_query_threshold)
          issue = SlowQueryIssue.new(execution, @config.slow_query_threshold)
          @detected_issues << issue
          issues << issue.as(PerformanceIssue)
        end
      end

      issues
    end

    def get_issues : Array(PerformanceIssue)
      @detected_issues.map(&.as(PerformanceIssue))
    end

    def clear_issues : Void
      @detected_issues.clear
    end

    # Performance statistics
    def statistics : Hash(String, QueryStats)
      @stats.dup
    end

    def slow_queries(limit : Int32 = 50) : Array(QueryExecution)
      @slow_queries.sort_by!(&.execution_time.total_milliseconds).reverse[0...limit]
    end

    def slowest_queries(limit : Int32 = 10) : Array(QueryStats)
      @stats.values.sort_by!(&.performance_score).reverse[0...limit]
    end

    def queries_by_endpoint(endpoint : String) : Array(QueryExecution)
      @endpoint_stats[endpoint]? || [] of QueryExecution
    end

    def endpoint_summary : Hash(String, NamedTuple(count: Int32, total_time: Float64, avg_time: Float64))
      summary = {} of String => NamedTuple(count: Int32, total_time: Float64, avg_time: Float64)

      @endpoint_stats.each do |endpoint, executions|
        count = executions.size
        total_time = executions.sum(&.execution_time.total_milliseconds)
        avg_time = count > 0 ? total_time / count : 0.0

        summary[endpoint] = {count: count, total_time: total_time, avg_time: avg_time}
      end

      summary
    end

    # Configuration management
    def configure(& : ProfilerConfig ->)
      yield @config
    end

    def clear_data
      @executions.clear
      @stats.clear
      @endpoint_stats.clear
      @slow_queries.clear
      @detected_issues.clear
      @start_time = Time.utc
    end

    def config : ProfilerConfig
      @config
    end

    # Report generation - delegated to separate classes following SRP
    def generate_report(format : String = "text") : String
      case format.downcase
      when "json"
        generate_json_report
      when "html"
        generate_html_report
      else
        generate_text_report
      end
    end

    private def handle_query_execution(event : QueryExecutionEvent)
      return unless @config.enabled
      return if should_ignore_query?(event.sql)

      execution = create_execution_from_event(event)

      # Record execution
      add_execution(execution)
      update_stats(execution)
      track_endpoint(execution) if execution.endpoint
      check_slow_query(execution)

      # Cleanup if we have too many records
      cleanup_old_records() if @executions.size > @config.max_recorded_queries
    end

    private def create_execution_from_event(event : QueryExecutionEvent) : QueryExecution
      memory_usage = @config.enable_memory_tracking ? current_memory_usage : nil

      QueryExecution.new(
        sql: event.sql,
        params: event.params,
        execution_time: event.execution_time,
        timestamp: event.timestamp,
        context: event.context,
        rows_affected: event.rows_affected,
        memory_usage: memory_usage
      )
    end

    private def should_ignore_query?(sql : String) : Bool
      normalized = sql.strip.upcase
      @config.queries_to_ignore.any? { |pattern| normalized.starts_with?(pattern) } ||
        normalized.starts_with?("EXPLAIN")
    end

    private def current_memory_usage : Int64
      # Platform-specific memory usage tracking
      {% if flag?(:linux) %}
        if File.exists?("/proc/self/status")
          File.read("/proc/self/status").lines.each do |line|
            if line.starts_with?("VmRSS:")
              return line.split[1].to_i64 * 1024 # Convert KB to bytes
            end
          end
        end
      {% end %}
      0_i64
    end

    private def add_execution(execution : QueryExecution)
      @executions << execution

      # Log if configured
      if @config.log_all_queries
        Log.info { "Query executed: #{execution.sql[0..100]}... (#{execution.execution_time.total_milliseconds.round(2)}ms)" }
      end
    end

    private def update_stats(execution : QueryExecution)
      normalized = execution.normalized_sql
      stats = @stats[normalized] ||= QueryStats.new(normalized)
      stats.add_execution(execution)
    end

    private def track_endpoint(execution : QueryExecution)
      return unless endpoint = execution.endpoint

      @endpoint_stats[endpoint] ||= [] of QueryExecution
      @endpoint_stats[endpoint] << execution
    end

    private def check_slow_query(execution : QueryExecution)
      if execution.slow?(@config.slow_query_threshold)
        @slow_queries << execution

        if @config.log_slow_queries
          severity = execution.execution_time > @config.very_slow_threshold ? "VERY SLOW" : "SLOW"
          Log.warn { "#{severity} QUERY (#{execution.execution_time.total_milliseconds.round(2)}ms): #{execution.sql}" }
        end
      end
    end

    private def cleanup_old_records
      # Keep only the most recent queries
      keep_count = (@config.max_recorded_queries * 0.8).to_i
      @executions = @executions.last(keep_count)
      @slow_queries = @slow_queries.last(keep_count)
    end

    private def generate_text_report : String
      uptime = Time.utc - @start_time

      String.build do |str|
        str << "CQL Query Performance Report\n"
        str << "===========================\n\n"
        str << "Report generated: #{Time.utc}\n"
        str << "Profiler uptime: #{uptime.total_seconds.round(2)} seconds\n"
        str << "Total queries: #{@executions.size}\n"
        str << "Unique patterns: #{@stats.size}\n"
        str << "Slow queries: #{@slow_queries.size}\n\n"

        # Top slowest queries
        str << "Top 10 Slowest Query Patterns:\n"
        str << "------------------------------\n"
        slowest_queries(10).each_with_index do |stats, i|
          str << "#{i + 1}. #{stats.normalized_sql[0..80]}...\n"
          str << "   Executions: #{stats.execution_count}, "
          str << "Avg: #{stats.avg_time.total_milliseconds.round(2)}ms, "
          str << "Max: #{stats.max_time.total_milliseconds.round(2)}ms\n\n"
        end

        # Endpoint summary
        unless @endpoint_stats.empty?
          str << "Endpoint Performance Summary:\n"
          str << "----------------------------\n"
          endpoint_summary.each do |endpoint, summary|
            str << "#{endpoint}: #{summary[:count]} queries, "
            str << "#{summary[:avg_time].round(2)}ms avg\n"
          end
          str << "\n"
        end

        # Recent slow queries
        recent_slow = @slow_queries.last(5)
        unless recent_slow.empty?
          str << "Recent Slow Queries:\n"
          str << "-------------------\n"
          recent_slow.each do |execution|
            str << "#{execution.execution_time.total_milliseconds.round(2)}ms: "
            str << "#{execution.sql[0..100]}...\n"
          end
        end
      end
    end

    private def generate_json_report : String
      {
        "report_generated"        => Time.utc.to_rfc3339,
        "profiler_uptime_seconds" => (Time.utc - @start_time).total_seconds,
        "total_queries"           => @executions.size,
        "unique_patterns"         => @stats.size,
        "slow_queries_count"      => @slow_queries.size,
        "slowest_patterns"        => slowest_queries(10),
        "endpoint_summary"        => endpoint_summary,
        "recent_slow_queries"     => @slow_queries.last(10),
      }.to_json
    end

    private def generate_html_report : String
      uptime = Time.utc - @start_time

      String.build do |str|
        str << "<!DOCTYPE html><html><head><title>CQL Performance Report</title>"
        str << "<style>body{font-family:Arial,sans-serif;margin:20px;}"
        str << "table{border-collapse:collapse;width:100%;margin:20px 0;}"
        str << "th,td{border:1px solid #ddd;padding:8px;text-align:left;}"
        str << "th{background-color:#f2f2f2;}.slow{color:#d32f2f;}.warning{color:#f57c00;}"
        str << "</style></head><body>"
        str << "<h1>CQL Query Performance Report</h1>"
        str << "<p>Generated: #{Time.utc} | Uptime: #{uptime.total_seconds.round(2)}s</p>"
        str << "<p>Total Queries: #{@executions.size} | Unique Patterns: #{@stats.size} | Slow Queries: #{@slow_queries.size}</p>"

        str << "<h2>Top 10 Slowest Query Patterns</h2><table>"
        str << "<tr><th>Query</th><th>Executions</th><th>Avg Time (ms)</th><th>Max Time (ms)</th></tr>"
        slowest_queries(10).each do |stats|
          css_class = stats.avg_time > @config.very_slow_threshold ? "slow" : stats.avg_time > @config.slow_query_threshold ? "warning" : ""
          str << "<tr class='#{css_class}'>"
          str << "<td>#{stats.normalized_sql[0..100]}...</td>"
          str << "<td>#{stats.execution_count}</td>"
          str << "<td>#{stats.avg_time.total_milliseconds.round(2)}</td>"
          str << "<td>#{stats.max_time.total_milliseconds.round(2)}</td></tr>"
        end
        str << "</table>"

        str << "</body></html>"
      end
    end
  end
end
