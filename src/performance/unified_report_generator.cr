# Unified report generator with format strategies
# Consolidates report generation logic to eliminate duplication

require "json"
require "./utilities"
require "./sql_formatter"

module CQL::Performance
  # Report data structure
  struct PerformanceReport
    getter timestamp : Time = Time.utc
    getter duration : Time::Span
    getter total_queries : Int32
    getter slow_queries : Int32
    getter errors : Int32
    getter issues : Array(Issue)
    getter stats : Hash(String, StatsTracker)
    getter metadata : Hash(String, String)

    def initialize(@duration, @total_queries, @slow_queries, @errors,
                   @issues = [] of Issue, @stats = {} of String => StatsTracker,
                   @metadata = {} of String => String)
    end

    def to_h : Hash(String, JSON::Any)
      {
        "timestamp"     => JSON::Any.new(@timestamp.to_rfc3339),
        "duration_ms"   => JSON::Any.new(@duration.total_milliseconds),
        "total_queries" => JSON::Any.new(@total_queries.to_i64),
        "slow_queries"  => JSON::Any.new(@slow_queries.to_i64),
        "errors"        => JSON::Any.new(@errors.to_i64),
        "issues"        => JSON::Any.new(@issues.map { |i| JSON::Any.new(i.type.to_s) }),
        "stats"         => JSON::Any.new(@stats.transform_values { |v| JSON::Any.new(v.to_h.to_json) }),
        "metadata"      => JSON::Any.new(@metadata.transform_values { |v| JSON::Any.new(v) }),
      }
    end

    def to_json : String
      to_h.to_json
    end
  end

  # Performance issue structure
  struct Issue
    getter type : Symbol
    getter severity : Symbol
    getter message : String
    getter details : Hash(String, String)
    getter timestamp : Time

    def initialize(@type, @severity, @message, @details = {} of String => String,
                   @timestamp = Time.utc)
    end
  end

  # Base report formatter
  abstract class ReportFormatter
    include ColorUtils

    abstract def format(report : PerformanceReport) : String

    # Common formatting helpers
    protected def format_header(title : String) : String
      separator = "=" * 60
      "#{separator}\n#{title}\n#{separator}"
    end

    protected def format_duration(span : Time::Span) : String
      hours = span.total_hours.to_i
      minutes = (span.total_minutes % 60).to_i
      seconds = (span.total_seconds % 60).to_i

      if hours > 0
        "#{hours}h #{minutes}m #{seconds}s"
      elsif minutes > 0
        "#{minutes}m #{seconds}s"
      else
        "#{seconds}s"
      end
    end

    protected def severity_emoji(severity : Symbol) : String
      case severity
      when :critical then "🔥"
      when :high     then "⚠️"
      when :medium   then "⚡"
      when :low      then "ℹ️"
      else                "❓"
      end
    end
  end

  # Text report formatter
  class TextReportFormatter < ReportFormatter
    def format(report : PerformanceReport) : String
      String.build do |str|
        str << format_header("CQL Performance Report")
        str << "\n\n"

        # Overview
        str << "Generated: #{report.timestamp}\n"
        str << "Duration: #{format_duration(report.duration)}\n"
        str << "Total Queries: #{report.total_queries}\n"
        str << "Slow Queries: #{report.slow_queries}\n"
        str << "Errors: #{report.errors}\n\n"

        # Issues
        if report.issues.any?
          str << "Performance Issues:\n"
          str << "-" * 40 << "\n"

          report.issues.group_by(&.severity).each do |severity, issues|
            str << "#{severity.to_s.capitalize}: #{issues.size}\n"
          end
          str << "\n"

          report.issues.each_with_index do |issue, i|
            str << "#{i + 1}. [#{issue.severity.to_s.upcase}] #{issue.type}: #{issue.message}\n"
            issue.details.each do |key, value|
              str << "   #{key}: #{value}\n"
            end
            str << "\n"
          end
        else
          str << "No performance issues detected.\n"
        end
      end
    end
  end

  # JSON report formatter
  class JSONReportFormatter < ReportFormatter
    def format(report : PerformanceReport) : String
      {
        "timestamp"        => report.timestamp.to_rfc3339,
        "duration_seconds" => report.duration.total_seconds,
        "metrics"          => {
          "total_queries" => report.total_queries,
          "slow_queries"  => report.slow_queries,
          "errors"        => report.errors,
        },
        "issues" => report.issues.map { |issue|
          {
            "type"      => issue.type.to_s,
            "severity"  => issue.severity.to_s,
            "message"   => issue.message,
            "details"   => issue.details,
            "timestamp" => issue.timestamp.to_rfc3339,
          }
        },
        "stats"    => report.stats.transform_values(&.to_h),
        "metadata" => report.metadata,
      }.to_json
    end
  end

  # HTML report formatter
  class HTMLReportFormatter < ReportFormatter
    def format(report : PerformanceReport) : String
      String.build do |str|
        str << html_header
        str << html_body(report)
        str << html_footer
      end
    end

    private def html_header : String
      <<-HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>CQL Performance Report</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
          .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
          h1 { color: #333; border-bottom: 3px solid #007acc; padding-bottom: 10px; }
          .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
          .metric-card { background: #f8f9fa; padding: 15px; border-radius: 5px; text-align: center; border-left: 4px solid #007acc; }
          .metric-value { font-size: 2em; font-weight: bold; color: #007acc; }
          .issues { margin-top: 30px; }
          .issue { background: #fff; border: 1px solid #ddd; padding: 15px; margin: 10px 0; border-radius: 5px; }
          .issue-critical { border-left: 4px solid #dc3545; }
          .issue-high { border-left: 4px solid #ffc107; }
          .issue-medium { border-left: 4px solid #fd7e14; }
          .issue-low { border-left: 4px solid #17a2b8; }
          .no-issues { background: #d4edda; color: #155724; padding: 20px; text-align: center; border-radius: 5px; }
        </style>
      </head>
      <body>
        <div class="container">
      HTML
    end

    private def html_body(report : PerformanceReport) : String
      String.build do |str|
        str << "<h1>CQL Performance Report</h1>"
        str << "<p>Generated: #{report.timestamp} | Duration: #{format_duration(report.duration)}</p>"

        # Metrics cards
        str << "<div class='metrics'>"
        str << metric_card("Total Queries", report.total_queries.to_s)
        str << metric_card("Slow Queries", report.slow_queries.to_s)
        str << metric_card("Errors", report.errors.to_s)
        str << metric_card("Health Score", "#{health_score(report)}%")
        str << "</div>"

        # Issues section
        str << "<div class='issues'>"
        str << "<h2>Performance Issues</h2>"

        if report.issues.any?
          report.issues.each do |issue|
            str << "<div class='issue issue-#{issue.severity}'>"
            str << "<h3>#{severity_emoji(issue.severity)} #{issue.type.to_s.gsub('_', ' ').split.map(&.capitalize).join(' ')}</h3>"
            str << "<p>#{issue.message}</p>"
            unless issue.details.empty?
              str << "<ul>"
              issue.details.each do |key, value|
                str << "<li><strong>#{key}:</strong> #{value}</li>"
              end
              str << "</ul>"
            end
            str << "</div>"
          end
        else
          str << "<div class='no-issues'>✅ No performance issues detected</div>"
        end

        str << "</div>"
      end
    end

    private def html_footer : String
      <<-HTML
        </div>
      </body>
      </html>
      HTML
    end

    private def metric_card(label : String, value : String) : String
      <<-HTML
      <div class="metric-card">
        <div class="metric-label">#{label}</div>
        <div class="metric-value">#{value}</div>
      </div>
      HTML
    end

    private def health_score(report : PerformanceReport) : Int32
      score = 100
      score -= report.issues.size * 5
      score -= (report.errors * 10)
      score -= ((report.slow_queries.to_f / report.total_queries * 100).to_i) if report.total_queries > 0
      [score, 0].max
    end
  end

  # Console logger formatter with beautiful output
  class ConsoleReportFormatter < ReportFormatter
    def format(report : PerformanceReport) : String
      String.build do |str|
        str << ("\n" + "═" * 80).colorize(:cyan).to_s
        str << "\n"
        str << "🚀 CQL PERFORMANCE REPORT".colorize(:cyan).bold.to_s
        str << "\n"
        str << ("═" * 80).colorize(:cyan).to_s

        str << "\n\n"
        str << "📊 OVERVIEW".colorize(:blue).bold.to_s
        str << "\n"
        str << ("─" * 20).colorize(:blue).to_s
        str << "\n"
        str << "  ⏰ Generated: #{report.timestamp.to_s.colorize(:white).bold}\n"
        str << "  ⚡ Duration: #{format_duration(report.duration).colorize(:green)}\n"
        str << "  📈 Total Queries: #{report.total_queries.to_s.colorize(:white).bold}\n"
        str << "  🐌 Slow Queries: #{report.slow_queries.to_s.colorize(:yellow)}\n"
        str << "  ❌ Errors: #{report.errors.to_s.colorize(:red)}\n"

        if report.issues.any?
          str << "\n"
          str << "⚠️  PERFORMANCE ISSUES".colorize(:red).bold.to_s
          str << "\n"
          str << ("─" * 25).colorize(:red).to_s
          str << "\n"

          report.issues.group_by(&.severity).each do |severity, issues|
            color = severity_color(severity)
            str << "  #{severity_emoji(severity)} #{severity.to_s.upcase.colorize(color).bold}: #{issues.size.to_s.colorize(color)} issues\n"
          end

          str << "\n"
          str << "🔍 DETAILS".colorize(:yellow).bold.to_s
          str << "\n"
          str << ("─" * 15).colorize(:yellow).to_s
          str << "\n"

          report.issues.each_with_index do |issue, i|
            color = severity_color(issue.severity)
            str << "\n  #{i + 1}. #{severity_emoji(issue.severity)} #{issue.type.to_s.colorize(color).bold}\n"
            str << "     #{"Message:".colorize(:cyan)} #{issue.message}\n"
            issue.details.each do |key, value|
              str << "     #{(key + ":").colorize(:cyan)} #{value}\n"
            end
          end
        else
          str << "\n"
          str << "✅ EXCELLENT PERFORMANCE!".colorize(:green).bold.to_s
          str << "\n"
          str << ("─" * 30).colorize(:green).to_s
          str << "\n"
          str << "  🎉 No performance issues detected\n"
          str << "  🚀 Your queries are running smoothly\n"
        end

        str << "\n"
        str << ("═" * 80).colorize(:cyan).to_s
        str << "\n"
        str << "🔧 Report generated at #{Time.utc.to_s("%H:%M:%S")}".colorize(:cyan).to_s
        str << "\n"
        str << ("═" * 80 + "\n").colorize(:cyan).to_s
      end
    end

    private def severity_color(severity : Symbol) : Symbol
      case severity
      when :critical then :red
      when :high     then :light_red
      when :medium   then :yellow
      when :low      then :blue
      else                :white
      end
    end
  end

  # Unified report generator with format strategies
  class UnifiedReportGenerator
    include TimingUtils

    @formatters : Hash(String, ReportFormatter) = {
      "text"    => TextReportFormatter.new,
      "json"    => JSONReportFormatter.new,
      "html"    => HTMLReportFormatter.new,
      "console" => ConsoleReportFormatter.new,
      "logger"  => ConsoleReportFormatter.new, # Alias for console
    }

    def generate(format : String, report : PerformanceReport) : String
      formatter = @formatters[format.downcase]? || @formatters["text"]
      formatter.format(report)
    end

    def register_formatter(format : String, formatter : ReportFormatter)
      @formatters[format.downcase] = formatter
    end

    def available_formats : Array(String)
      @formatters.keys
    end
  end
end
