# Unified SQL formatter and colorizer
# Consolidates all SQL formatting logic in one place

require "colorize"
require "./utilities"

module CQL::Performance
  # Centralized SQL formatter with colorization support
  class SQLFormatter
    include TimingUtils
    include ColorUtils

    # SQL keywords by category for colorization
    SQL_KEYWORDS = {
      dml:       %w[SELECT INSERT UPDATE DELETE FROM INTO SET VALUES WHERE],
      ddl:       %w[CREATE ALTER DROP TABLE INDEX VIEW],
      joins:     %w[INNER LEFT RIGHT FULL CROSS JOIN OUTER ON],
      clauses:   %w[ORDER BY GROUP HAVING LIMIT OFFSET DISTINCT AS],
      operators: %w[AND OR NOT IN EXISTS BETWEEN LIKE ILIKE IS NULL],
      functions: %w[COUNT SUM AVG MIN MAX COALESCE NULLIF CASE WHEN THEN ELSE END],
      types:     %w[INTEGER INT BIGINT VARCHAR TEXT BOOLEAN DATE TIMESTAMP JSON UUID],
    }

    @colorize_enabled : Bool
    @pretty_format : Bool
    @max_sql_length : Int32
    @max_param_length : Int32

    def initialize(@colorize_enabled : Bool = true, @pretty_format : Bool = true,
                   @max_sql_length : Int32 = 500, @max_param_length : Int32 = 50)
      # Respect NO_COLOR environment variable
      @colorize_enabled = false if ENV["NO_COLOR"]?
    end

    # Format SQL with optional colorization and pretty printing
    def format(sql : String, params : Array(DB::Any) = [] of DB::Any,
               execution_time : Time::Span? = nil, rows_affected : Int64? = nil,
               context : String? = nil) : String
      formatted_sql = @pretty_format ? pretty_format_sql(sql) : sql
      formatted_sql = truncate_sql(formatted_sql, @max_sql_length)

      if @colorize_enabled && Colorize.enabled?
        formatted_sql = colorize_sql(formatted_sql)
      end

      # Build complete output with metadata
      build_output(formatted_sql, params, execution_time, rows_affected, context)
    end

    # Format just the SQL without metadata
    def format_sql_only(sql : String) : String
      formatted = @pretty_format ? pretty_format_sql(sql) : sql
      @colorize_enabled && Colorize.enabled? ? colorize_sql(formatted) : formatted
    end

    # Format parameters array
    def format_params(params : Array(DB::Any)) : String
      return "[]" if params.empty?

      formatted = params.map do |param|
        str = param.to_s
        str.size > @max_param_length ? "#{str[0...@max_param_length]}..." : str
      end

      result = "[#{formatted.join(", ")}]"

      if @colorize_enabled && Colorize.enabled?
        result.colorize(:blue).to_s
      else
        result
      end
    end

    # Configure formatter
    def configure(colorize : Bool? = nil, pretty : Bool? = nil,
                  max_sql : Int32? = nil, max_param : Int32? = nil)
      @colorize_enabled = colorize unless colorize.nil?
      @pretty_format = pretty unless pretty.nil?
      @max_sql_length = max_sql unless max_sql.nil?
      @max_param_length = max_param unless max_param.nil?
    end

    private def pretty_format_sql(sql : String) : String
      # Normalize whitespace
      normalized = sql.gsub(/\s+/, " ").strip

      # Add strategic line breaks
      formatted = normalized
        .gsub(/\b(SELECT|INSERT INTO|UPDATE|DELETE FROM)\b/i, "\n\\1")
        .gsub(/\b(FROM|SET|VALUES)\b/i, "\n  \\1")
        .gsub(/\b(WHERE|HAVING)\b/i, "\n  \\1")
        .gsub(/\b(AND|OR)\b/i, "\n    \\1")
        .gsub(/\b(ORDER BY|GROUP BY)\b/i, "\n  \\1")
        .gsub(/\b(INNER JOIN|LEFT JOIN|RIGHT JOIN|FULL JOIN|CROSS JOIN|JOIN)\b/i, "\n  \\1")
        .gsub(/\b(LIMIT|OFFSET)\b/i, "\n  \\1")
        .strip

      formatted
    end

    private def colorize_sql(sql : String) : String
      tokens = tokenize_sql(sql)

      tokens.map do |token|
        colorize_token(token)
      end.join("")
    end

    private def tokenize_sql(sql : String) : Array(String)
      tokens = [] of String
      current = ""
      in_string = false
      string_char = nil

      sql.each_char_with_index do |char, _|
        if !in_string && (char == '\'' || char == '"')
          tokens << current unless current.empty?
          current = char.to_s
          in_string = true
          string_char = char
        elsif in_string && char == string_char
          current += char
          tokens << current
          current = ""
          in_string = false
          string_char = nil
        elsif in_string
          current += char
        elsif char.whitespace?
          tokens << current unless current.empty?
          tokens << char.to_s
          current = ""
        else
          current += char
        end
      end

      tokens << current unless current.empty?
      tokens
    end

    private def colorize_token(token : String) : String
      return token if token.empty? || token.whitespace?

      upper = token.upcase

      # String literals
      if token.starts_with?("'") || token.starts_with?('"')
        return token.colorize(:cyan).to_s
      end

      # Check keyword categories
      if SQL_KEYWORDS[:dml].includes?(upper)
        token.colorize(:blue).bold.to_s
      elsif SQL_KEYWORDS[:joins].includes?(upper)
        token.colorize(:magenta).bold.to_s
      elsif SQL_KEYWORDS[:functions].includes?(upper)
        token.colorize(:cyan).bold.to_s
      elsif SQL_KEYWORDS[:types].includes?(upper)
        token.colorize(:yellow).to_s
      elsif SQL_KEYWORDS[:operators].includes?(upper) || SQL_KEYWORDS[:clauses].includes?(upper)
        token.colorize(:blue).to_s
      elsif token.matches?(/^\d+$/)
        token.colorize(:yellow).bright.to_s
      elsif token == "?"
        token.colorize(:green).bright.to_s
      else
        token
      end
    end

    private def truncate_sql(sql : String, max_length : Int32) : String
      return sql if sql.size <= max_length

      # Try to truncate at a sensible boundary
      truncated = sql[0...max_length]

      # Find last complete word
      last_space = truncated.rindex(' ')
      if last_space && last_space > max_length - 20
        truncated = truncated[0...last_space]
      end

      "#{truncated}..."
    end

    private def build_output(sql : String, params : Array(DB::Any),
                             execution_time : Time::Span?, rows_affected : Int64?,
                             context : String?) : String
      lines = [] of String

      # Header line with performance indicator
      header_parts = [] of String

      if execution_time
        indicator = performance_indicator(execution_time)
        time_str = colorize_duration(execution_time)
        header_parts << "#{indicator} SQL (#{time_str})"
      else
        header_parts << "SQL"
      end

      header_parts << "[#{rows_affected} rows]" if rows_affected
      header_parts << "{#{context}}" if context

      header = header_parts.join(" ")
      lines << (@colorize_enabled ? header.colorize(:cyan).bold.to_s : header)

      # SQL body
      sql.split('\n').each do |line|
        lines << "  #{line}" unless line.strip.empty?
      end

      # Parameters
      unless params.empty?
        params_line = "📊 Parameters: #{format_params(params)}"
        lines << (@colorize_enabled ? params_line : params_line)
      end

      lines.join("\n")
    end

    private def performance_indicator(duration : Time::Span) : String
      case categorize_duration(duration)
      when :very_slow
        "🐌"
      when :slow
        "⚠️"
      else
        "✅"
      end
    end
  end

  # Global SQL formatter instance
  @@sql_formatter : SQLFormatter?

  def self.sql_formatter : SQLFormatter
    @@sql_formatter ||= SQLFormatter.new
  end

  def self.sql_formatter=(formatter : SQLFormatter)
    @@sql_formatter = formatter
  end
end
