require "../interfaces"

module CQL::Performance::Reports
  # Set up logging for this module
  Log = ::Log.for(self)

  # Logger Report Generator - Beautiful console output for developers
  class LoggerReportGenerator < ReportGenerator
    def format : String
      "logger"
    end

    def generate(data : ReportData) : String
      log_beautiful_report(data)
      "" # Return empty string since we're logging to console
    end

    private def log_beautiful_report(data : ReportData) : Void
      # Header with fancy styling
      puts colorize("\n" + "═" * 80, :cyan)
      puts colorize("🚀 CQL PERFORMANCE MONITORING REPORT", :cyan, :bold)
      puts colorize("═" * 80, :cyan)

      # Metadata section
      puts colorize("\n📊 OVERVIEW", :blue, :bold)
      puts colorize("─" * 20, :blue)
      puts "  ⏰ Generated: #{colorize(data.metadata["generated_at"]? || Time.utc.to_s, :white, :bold)}"
      puts "  ⚡ Uptime: #{colorize(data.metadata["uptime"]? || "N/A", :green)}"
      puts "  🔍 Monitoring: #{colorize(data.metadata["monitoring_enabled"]? || "N/A", :yellow)}"

      # Issues summary with visual indicators
      if data.issues.any?
        puts colorize("\n⚠️  PERFORMANCE ISSUES DETECTED", :red, :bold)
        puts colorize("─" * 35, :red)

        # Group by severity with emoji indicators
        by_severity = data.issues.group_by(&.severity)

        by_severity.each do |severity, issues|
          emoji, color = severity_style(severity)
          count = issues.size
          puts "  #{emoji} #{colorize(severity.to_s.upcase, color, :bold)}: #{colorize(count.to_s, color, :bold)} #{count == 1 ? "issue" : "issues"}"
        end

        # Detailed issues with beautiful formatting
        puts colorize("\n🔍 ISSUE DETAILS", :yellow, :bold)
        puts colorize("─" * 20, :yellow)

        data.issues.each_with_index do |issue, i|
          emoji, color = severity_style(issue.severity)

          puts "\n  #{colorize("#{i + 1}.", :white)} #{emoji} #{colorize(issue.type.gsub("_", " ").split.map(&.capitalize).join(" "), color, :bold)}"
          puts "     #{colorize("Severity:", :cyan)} #{colorize(issue.severity.to_s, color)}"
          puts "     #{colorize("Message:", :cyan)} #{wrap_text(issue.message, 60, "     ")}"
          puts "     #{colorize("Summary:", :cyan)} #{wrap_text(issue.summary, 60, "     ")}"
          puts "     #{colorize("Detected:", :cyan)} #{colorize(format_time(issue.detected_at), :white)}"
        end

        # Performance recommendations
        puts colorize("\n💡 RECOMMENDATIONS", :green, :bold)
        puts colorize("─" * 25, :green)
        generate_recommendations(data.issues)
      else
        # Success case with celebration
        puts colorize("\n✅ EXCELLENT PERFORMANCE!", :green, :bold)
        puts colorize("─" * 30, :green)
        puts "  🎉 No performance issues detected"
        puts "  🚀 Your application is running smoothly"
        puts "  💪 Keep up the great work!"
      end

      # Events summary if available
      if data.events.any?
        puts colorize("\n📈 EVENTS SUMMARY", :magenta, :bold)
        puts colorize("─" * 20, :magenta)
        puts "  📝 Total Events: #{colorize(data.events.size.to_s, :white, :bold)}"

        # Group events by type
        by_type = data.events.group_by(&.class.name.split("::").last)
        by_type.each do |type, events|
          puts "  🔸 #{type}: #{colorize(events.size.to_s, :cyan)}"
        end
      end

      # Footer
      puts colorize("\n" + "═" * 80, :cyan)
      puts colorize("🔧 CQL Performance Monitoring • #{Time.utc.to_s("%H:%M:%S")}", :cyan)
      puts colorize("═" * 80 + "\n", :cyan)
    end

    private def severity_style(severity : PerformanceIssue::Severity) : Tuple(String, Symbol)
      case severity
      when .critical?
        {"🔥", :red}
      when .high?
        {"⚠️", :light_red}
      when .medium?
        {"⚡", :yellow}
      when .low?
        {"ℹ️", :blue}
      else
        {"❓", :white}
      end
    end

    private def colorize(text : String, color : Symbol, style : Symbol? = nil) : String
      result = case color
               when :red
                 "\e[31m#{text}\e[0m"
               when :light_red
                 "\e[91m#{text}\e[0m"
               when :green
                 "\e[32m#{text}\e[0m"
               when :yellow
                 "\e[33m#{text}\e[0m"
               when :blue
                 "\e[34m#{text}\e[0m"
               when :magenta
                 "\e[35m#{text}\e[0m"
               when :cyan
                 "\e[36m#{text}\e[0m"
               when :white
                 "\e[97m#{text}\e[0m"
               else
                 text
               end

      # Apply bold styling if requested
      if style == :bold
        result = "\e[1m#{result}"
      end

      result
    end

    private def wrap_text(text : String, width : Int32, indent : String = "") : String
      words = text.split(" ")
      lines = [] of String
      current_line = ""

      words.each do |word|
        if current_line.empty?
          current_line = word
        elsif (current_line + " " + word).size <= width
          current_line += " " + word
        else
          lines << current_line
          current_line = word
        end
      end

      lines << current_line unless current_line.empty?

      if lines.size == 1
        lines.first
      else
        lines.first + "\n" + lines[1..].map { |line| "#{indent}#{line}" }.join("\n")
      end
    end

    private def format_time(time : Time) : String
      time.to_s("%Y-%m-%d %H:%M:%S UTC")
    end

    private def generate_recommendations(issues : Array(PerformanceIssue)) : Void
      recommendations = Set(String).new

      issues.each do |issue|
        case issue.type.downcase
        when "n_plus_one", "n+1"
          recommendations << "🔄 Consider using eager loading with .includes() to reduce N+1 queries"
          recommendations << "📊 Use .preload() for specific associations that are always accessed"
        when "slow_query"
          recommendations << "🗃️  Add database indexes for frequently queried columns"
          recommendations << "⚡ Consider query optimization or caching for slow operations"
          recommendations << "📈 Use EXPLAIN ANALYZE to understand query execution plans"
        when "missing_index"
          recommendations << "🏷️  Add indexes on columns used in WHERE, JOIN, and ORDER BY clauses"
        when "large_result_set"
          recommendations << "📄 Implement pagination for large result sets"
          recommendations << "🎯 Use more specific WHERE conditions to limit results"
        when "connection_pool"
          recommendations << "🏊 Review and optimize database connection pool settings"
        else
          recommendations << "📚 Review the CQL performance documentation for optimization tips"
        end
      end

      recommendations.each_with_index do |rec, i|
        puts "  #{i + 1}. #{rec}"
      end

      if recommendations.empty?
        puts "  📖 Check the CQL documentation for general performance best practices"
      end
    end
  end
end
