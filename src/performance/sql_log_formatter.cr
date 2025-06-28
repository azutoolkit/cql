# Beautiful SQL Log Formatter for CQL
# Features:
# - Beautiful colorized SQL output
# - Async pipeline with batch processing
# - Environment-aware (development/manual enable)
# - Background error reporting
# - Performance-focused design

require "log"
require "./interfaces"
require "./event_system"
require "json"
require "colorize"

module CQL::Performance
  # Configuration for the SQL log formatter
  struct SQLLogConfig
    property? enabled : Bool = false
    property? auto_enable_in_development : Bool = true
    property? colorize_output : Bool = true
    property? include_parameters : Bool = true
    property? include_execution_time : Bool = true
    property? include_stack_trace : Bool = false
    property? include_row_count : Bool = true
    property? pretty_format : Bool = true
    property batch_size : Int32 = 50
    property batch_timeout : Time::Span = 2.seconds
    property slow_query_threshold : Time::Span = 100.milliseconds
    property very_slow_threshold : Time::Span = 1.second
    property max_sql_length : Int32 = 2000
    property max_param_length : Int32 = 500
    property? async_processing : Bool = true
    property? background_error_reporting : Bool = true
    property error_report_interval : Time::Span = 30.seconds

    def initialize
      # Auto-enable in development
      if @auto_enable_in_development && (ENV["CRYSTAL_ENV"]? == "development" || ENV["CRYSTAL_ENV"]?.nil?)
        @enabled = true
      end

      # Ensure Colorize is enabled when we want colorized output
      if @colorize_output && !Colorize.enabled?
        Colorize.enabled = true
      end
    end

    def should_log? : Bool
      @enabled
    end
  end

  # Enhanced SQL execution record for logging
  struct SQLLogEntry
    include JSON::Serializable

    getter sql : String
    getter params : Array(String)
    getter execution_time : Time::Span
    getter timestamp : Time
    getter context : String?
    getter rows_affected : Int64?
    getter error : String?
    getter stack_trace : Array(String)?
    getter formatted_sql : String
    getter log_level : ::Log::Severity

    def initialize(@sql : String, params : Array(DB::Any), @execution_time : Time::Span,
                   @timestamp : Time = Time.utc, @context : String? = nil,
                   @rows_affected : Int64? = nil, @error : String? = nil,
                   @stack_trace : Array(String)? = nil, config : SQLLogConfig = SQLLogConfig.new)
      @params = params.map(&.to_s)
      @formatted_sql = format_sql(@sql, config)
      @log_level = determine_log_level(config)
    end

    def slow? : Bool
      execution_time > 100.milliseconds
    end

    def very_slow? : Bool
      execution_time > 1.second
    end

    def has_error? : Bool
      !@error.nil?
    end

    def performance_indicator : String
      if has_error?
        "❌"
      elsif very_slow?
        "🐌"
      elsif slow?
        "⚠️"
      else
        "✅"
      end
    end

    def execution_time_color : Symbol
      if has_error?
        :red
      elsif very_slow?
        :magenta
      elsif slow?
        :yellow
      else
        :green
      end
    end

    private def format_sql(sql : String, config : SQLLogConfig) : String
      return sql unless config.pretty_format?

      # Multiline SQL formatting for better readability
      normalized_sql = sql
        .gsub(/\s+/, " ")  # Normalize whitespace first
        .strip             # Remove leading/trailing whitespace

      # Add line breaks for better readability
      formatted_result = normalized_sql
        .gsub(/\b(SELECT|INSERT INTO|UPDATE|DELETE FROM)\b/i, "\n\\1")
        .gsub(/\b(FROM)\b/i, "\n  \\1")
        .gsub(/\b(WHERE)\b/i, "\n  \\1")
        .gsub(/\b(AND|OR)\b/i, "\n    \\1")
        .gsub(/\b(ORDER BY|GROUP BY|HAVING)\b/i, "\n  \\1")
        .gsub(/\b(INNER JOIN|LEFT JOIN|RIGHT JOIN|FULL JOIN|CROSS JOIN|JOIN)\b/i, "\n  \\1")
        .gsub(/\b(LIMIT|OFFSET)\b/i, "\n  \\1")
        .gsub(/\b(SET)\b/i, "\n  \\1")
        .gsub(/\b(VALUES)\b/i, "\n  \\1")
        .strip # Remove leading newline

      # Truncate if too long
      if formatted_result.size > config.max_sql_length
        truncated_sql = formatted_result[0..config.max_sql_length] + "..."
        formatted_result = truncated_sql
      end

      formatted_result
    end

    private def determine_log_level(config : SQLLogConfig) : ::Log::Severity
      if has_error?
        ::Log::Severity::Error
      elsif execution_time > config.very_slow_threshold
        ::Log::Severity::Warn
      elsif execution_time > config.slow_query_threshold
        ::Log::Severity::Info
      else
        ::Log::Severity::Debug
      end
    end

    def to_beautiful_string(config : SQLLogConfig) : String
      lines = [] of String

      # Compact header with performance indicator
      header_parts = [performance_indicator]
      header_parts << "SQL"
      header_parts << format_execution_time(config)

      if rows_affected
        header_parts << "(#{rows_affected} rows)"
      end

      if context
        header_parts << "[#{context}]"
      end

      header = header_parts.join(" ")
      lines << (config.colorize_output? && Colorize.enabled? ? header.colorize.fore(:cyan).bold.to_s : header)

      # SQL with syntax highlighting - multiline format (compact)
      if config.colorize_output? && Colorize.enabled?
        highlighted_sql = highlight_sql(formatted_sql)
        # Add SQL lines with minimal spacing
        sql_lines = highlighted_sql.split('\n')
        sql_lines.each do |line|
          lines << "  #{line}" unless line.strip.empty?
        end
      else
        # Non-colorized multiline SQL
        sql_lines = formatted_sql.split('\n')
        sql_lines.each do |line|
          lines << "  #{line}" unless line.strip.empty?
        end
      end

      # Parameters (only if present)
      if config.include_parameters? && !params.empty?
        param_line = "📊 Parameters: #{format_parameters(config)}\n"
        lines << (config.colorize_output? && Colorize.enabled? ? param_line.colorize.fore(:blue).to_s : param_line)
      end

      # Error information (only if present)
      if has_error? && error
        error_line = "❌ Error: #{error}"
        lines << (config.colorize_output? && Colorize.enabled? ? error_line.colorize.fore(:red).bold.to_s : error_line)

        if config.include_stack_trace? && (st = stack_trace)
          lines << (config.colorize_output? && Colorize.enabled? ? "📍 Stack Trace:".colorize.fore(:red).to_s : "📍 Stack Trace:")
          st.first(3).each do |line|
            stack_line = "  #{line}"
            lines << (config.colorize_output? && Colorize.enabled? ? stack_line.colorize.fore(:red).to_s : stack_line)
          end
        end
      end

      lines.join("\n")
    end

    private def format_execution_time(config : SQLLogConfig) : String
      time_ms = execution_time.total_milliseconds.round(2)
      time_str = "#{time_ms}ms"

      return time_str unless config.colorize_output? && Colorize.enabled?

      time_str.colorize.fore(execution_time_color).bold.to_s
    end

    private def format_parameters(config : SQLLogConfig) : String
      if params.empty?
        return "none"
      end

      formatted_params = params.map do |param|
        if param.size > config.max_param_length
          "#{param[0..config.max_param_length]}..."
        else
          param
        end
      end

      "[#{formatted_params.join(", ")}]"
    end

    private def highlight_sql(sql : String) : String
      # Return original if colorize is disabled
      return sql unless Colorize.enabled?

      # Split SQL into tokens for better highlighting
      tokens = [] of String
      current_token = ""
      in_string = false
      string_char = nil

      i = 0
      while i < sql.size
        char = sql[i]

        # Handle string literals
        if !in_string && (char == '\'' || char == '"')
          # Save current token if any
          tokens << current_token unless current_token.empty?
          current_token = char.to_s
          in_string = true
          string_char = char
        elsif in_string && char == string_char
          current_token += char
          tokens << highlight_string_literal(current_token)
          current_token = ""
          in_string = false
          string_char = nil
        elsif in_string
          current_token += char
        elsif char.whitespace?
          # End of token
          tokens << highlight_token(current_token) unless current_token.empty?
          tokens << char.to_s
          current_token = ""
        else
          current_token += char
        end

        i += 1
      end

      # Handle remaining token
      if in_string
        tokens << highlight_string_literal(current_token)
      else
        tokens << highlight_token(current_token) unless current_token.empty?
      end

      tokens.join("")
    end

    private def highlight_token(token : String) : String
      return token if token.empty?

      # SQL Keywords - Blue and Bold
      if token.upcase.matches?(/^(SELECT|FROM|WHERE|AND|OR|ORDER|BY|GROUP|HAVING|LIMIT|OFFSET|DISTINCT|AS|ON|IN|EXISTS|NOT|NULL|IS|BETWEEN|LIKE|ILIKE)$/)
        return token.colorize.fore(:blue).bold.to_s
      end

      # DML Keywords - Green and Bold
      if token.upcase.matches?(/^(INSERT|INTO|UPDATE|DELETE|SET|VALUES|REPLACE)$/)
        return token.colorize.fore(:green).bold.to_s
      end

      # JOIN Keywords - Magenta and Bold
      if token.upcase.matches?(/^(INNER|LEFT|RIGHT|FULL|CROSS|JOIN|OUTER)$/)
        return token.colorize.fore(:magenta).bold.to_s
      end

      # Aggregate Functions - Cyan and Bold
      if token.upcase.matches?(/^(COUNT|SUM|AVG|MIN|MAX|COALESCE|NULLIF|CASE|WHEN|THEN|ELSE|END)$/)
        return token.colorize.fore(:cyan).bold.to_s
      end

      # Data Types - Yellow
      if token.upcase.matches?(/^(INTEGER|INT|BIGINT|SMALLINT|TINYINT|FLOAT|DOUBLE|DECIMAL|NUMERIC|VARCHAR|TEXT|CHAR|BOOLEAN|BOOL|DATE|DATETIME|TIMESTAMP|TIME|JSON|JSONB|UUID|BLOB)$/)
        return token.colorize.fore(:yellow).to_s
      end

      # Numbers - Bright Yellow
      if token.matches?(/^\d+$/)
        return token.colorize.fore(:yellow).bright.to_s
      end

      # Parameters - Bright Green
      if token == "?"
        return token.colorize.fore(:green).bright.to_s
      end

      # Default - no coloring
      token
    end

    private def highlight_string_literal(literal : String) : String
      literal.colorize.fore(:cyan).to_s
    end
  end

  # Batch processor for SQL log entries
  class SQLLogBatch
    getter entries : Array(SQLLogEntry) = [] of SQLLogEntry
    getter created_at : Time = Time.utc
    getter? complete : Bool = false

    def initialize(@max_size : Int32, @timeout : Time::Span)
    end

    def add(entry : SQLLogEntry) : Bool
      return false if @complete

      @entries << entry

      if @entries.size >= @max_size || (Time.utc - @created_at) > @timeout
        @complete = true
      end

      true
    end

    def should_flush? : Bool
      @complete || (Time.utc - @created_at) > @timeout
    end

    def size : Int32
      @entries.size
    end

    def empty? : Bool
      @entries.empty?
    end
  end

  # Error reporter for background error reporting
  class SQLLogErrorReporter
    Log = ::Log.for(self)

    @errors : Array(String) = [] of String
    @error_counts : Hash(String, Int32) = {} of String => Int32
    @last_report : Time = Time.utc
    @mutex : Mutex = Mutex.new

    def initialize(@report_interval : Time::Span = 30.seconds)
    end

    def report_error(error : String) : Void
      @mutex.synchronize do
        @errors << error
        @error_counts[error] = (@error_counts[error]? || 0) + 1
      end
    end

    def should_report? : Bool
      (Time.utc - @last_report) > @report_interval && !@errors.empty?
    end

    def generate_report : String
      errors_to_report = [] of String
      counts = {} of String => Int32

      @mutex.synchronize do
        errors_to_report = @errors.dup
        counts = @error_counts.dup
        @errors.clear
        @error_counts.clear
        @last_report = Time.utc
      end

      return "" if errors_to_report.empty?

      report = String.build do |str|
        str << "🚨 SQL Logger Error Report\n"
        str << "═" * 50 << "\n"
        str << "Report Period: #{@report_interval}\n"
        str << "Total Errors: #{errors_to_report.size}\n"
        str << "Unique Errors: #{counts.size}\n\n"

        counts.each do |error, count|
          str << "• #{error} (#{count} times)\n"
        end

        str << "═" * 50
      end

      report
    end

    def flush_report : Void
      return unless should_report?

      report = generate_report
      Log.error { report } unless report.empty?
    end
  end

  # Beautiful SQL Log Formatter - Main class
  class SQLLogFormatter < EventListener
    Log = ::Log.for(self)

    @config : SQLLogConfig
    @current_batch : SQLLogBatch?
    @batch_queue : Channel(SQLLogBatch) = Channel(SQLLogBatch).new(100)
    @error_reporter : SQLLogErrorReporter
    @processing : Bool = false
    @stats : {processed: Int64, errors: Int64, batches: Int64} = {processed: 0_i64, errors: 0_i64, batches: 0_i64}
    @start_time : Time = Time.utc

    def initialize(@config : SQLLogConfig = SQLLogConfig.new)
      @error_reporter = SQLLogErrorReporter.new(@config.error_report_interval)

      # Ensure Colorize is enabled when we want colorized output
      if @config.colorize_output? && !Colorize.enabled?
        Colorize.enabled = true
      end

      start_async_processing if @config.async_processing?
    end

    # EventListener implementation
    def handle_event(event : MonitoringEvent) : Void
      case event
      when QueryExecutionEvent
        handle_query_event(event)
      end
    end

    # Manual logging method for direct use
    def log_sql(sql : String, params : Array(DB::Any) = [] of DB::Any,
                execution_time : Time::Span = Time::Span.zero,
                context : String? = nil, rows_affected : Int64? = nil,
                error : String? = nil) : Void
      return unless @config.should_log?

      begin
        entry = SQLLogEntry.new(
          sql: sql,
          params: params,
          execution_time: execution_time,
          context: context,
          rows_affected: rows_affected,
          error: error,
          config: @config
        )

        if @config.async_processing?
          add_to_batch(entry)
        else
          log_entry_immediately(entry)
        end

        @stats = {processed: @stats[:processed] + 1, errors: @stats[:errors], batches: @stats[:batches]}
      rescue ex : Exception
        handle_error("Failed to log SQL: #{ex.message}")
      end
    end

    # Configuration management
    def configure(& : SQLLogConfig ->)
      yield @config
    end

    def enabled? : Bool
      @config.should_log?
    end

    def stats : Hash(String, Int64)
      uptime = (Time.utc - @start_time).total_seconds.to_i64
      {
        "processed"      => @stats[:processed],
        "errors"         => @stats[:errors],
        "batches"        => @stats[:batches],
        "uptime_seconds" => uptime,
      }
    end

    def shutdown : Void
      @processing = false
      flush_current_batch
      @batch_queue.close rescue nil
      @error_reporter.flush_report
    end

    private def handle_query_event(event : QueryExecutionEvent) : Void
      log_sql(
        sql: event.sql,
        params: event.params,
        execution_time: event.execution_time,
        context: event.context,
        rows_affected: event.rows_affected
      )
    end

    private def add_to_batch(entry : SQLLogEntry) : Void
      # Create new batch if needed
      unless @current_batch && @current_batch.not_nil!.add(entry)
        flush_current_batch
        @current_batch = SQLLogBatch.new(@config.batch_size, @config.batch_timeout)
        @current_batch.not_nil!.add(entry)
      end

      # Check if batch should be flushed
      if @current_batch.not_nil!.should_flush?
        flush_current_batch
      end
    end

    private def flush_current_batch : Void
      return unless @current_batch && !@current_batch.not_nil!.empty?

      begin
        @batch_queue.send(@current_batch.not_nil!)
        @stats = {processed: @stats[:processed], errors: @stats[:errors], batches: @stats[:batches] + 1}
      rescue ex : Channel::ClosedError
        # Queue is closed, log immediately
        @current_batch.not_nil!.entries.each { |entry| log_entry_immediately(entry) }
      end

      @current_batch = nil
    end

    private def log_entry_immediately(entry : SQLLogEntry) : Void
      case entry.log_level
      when .error?
        Log.error { entry.to_beautiful_string(@config) }
      when .warn?
        Log.warn { entry.to_beautiful_string(@config) }
      when .info?
        Log.info { entry.to_beautiful_string(@config) }
      else
        Log.debug { entry.to_beautiful_string(@config) }
      end
    end

    private def start_async_processing : Void
      @processing = true

      spawn(name: "sql-log-processor") do
        process_batches
      end

      spawn(name: "sql-log-error-reporter") do
        error_reporting_loop
      end
    end

    private def process_batches : Void
      while @processing
        begin
          batch = @batch_queue.receive
          process_batch(batch)
        rescue ex : Channel::ClosedError
          break
        rescue ex : Exception
          handle_error("Batch processing error: #{ex.message}")
        end
      end
    end

    private def process_batch(batch : SQLLogBatch) : Void
      batch.entries.each do |entry|
        begin
          log_entry_immediately(entry)
        rescue ex : Exception
          handle_error("Failed to log entry: #{ex.message}")
        end
      end
    end

    private def error_reporting_loop : Void
      while @processing
        sleep(5.seconds) # Check every 5 seconds
        @error_reporter.flush_report
      end
    end

    private def handle_error(error : String) : Void
      @stats = {processed: @stats[:processed], errors: @stats[:errors] + 1, batches: @stats[:batches]}

      if @config.background_error_reporting?
        @error_reporter.report_error(error)
      else
        Log.error { "SQL Logger Error: #{error}" }
      end
    end

    # Periodic batch flushing
    private def start_flush_timer : Void
      spawn(name: "sql-log-flush-timer") do
        while @processing
          sleep(@config.batch_timeout)
          flush_current_batch if @current_batch
        end
      end
    end
  end

  # Global SQL log formatter instance
  @@sql_logger : SQLLogFormatter?

  # Get global SQL logger instance
  def self.sql_logger : SQLLogFormatter
    @@sql_logger ||= SQLLogFormatter.new
  end

  # Set global SQL logger
  def self.sql_logger=(logger : SQLLogFormatter)
    @@sql_logger = logger
  end

  # Convenience method for logging SQL
  def self.log_sql(sql : String, params : Array(DB::Any) = [] of DB::Any,
                   execution_time : Time::Span = Time::Span.zero,
                   context : String? = nil, rows_affected : Int64? = nil,
                   error : String? = nil)
    sql_logger.log_sql(sql, params, execution_time, context, rows_affected, error)
  end

  # Enable SQL logging with configuration
  def self.enable_sql_logging(& : SQLLogConfig ->)
    config = SQLLogConfig.new
    yield config
    logger = SQLLogFormatter.new(config)
    self.sql_logger = logger
  end

  # Enable colorization for TTY output only
  def self.enable_tty_colors!
    Colorize.on_tty_only!
  end

  # Force enable colorization (ignores NO_COLOR and TTY detection)
  def self.force_enable_colors!
    Colorize.enabled = true
  end
end

