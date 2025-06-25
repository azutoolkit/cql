require "../interfaces"

module CQL::Performance::Reports
  # Text Report Generator
  class TextReportGenerator < ReportGenerator
    def format : String
      "text"
    end

    def generate(data : ReportData) : String
      String.build do |str|
        str << "CQL Comprehensive Performance Report\n"
        str << "===================================\n\n"
        str << "Generated: #{data.metadata["generated_at"]? || Time.utc}\n"
        str << "Uptime: #{data.metadata["uptime"]? || "N/A"}\n"
        str << "Monitoring Enabled: #{data.metadata["monitoring_enabled"]? || "N/A"}\n\n"

        # Issues summary
        if data.issues.any?
          str << "Performance Issues Summary:\n"
          str << "---------------------------\n"

          by_severity = data.issues.group_by(&.severity)
          by_severity.each do |severity, issues|
            str << "#{severity}: #{issues.size}\n"
          end
          str << "\n"

          # Detailed issues
          str << "Detailed Issues:\n"
          str << "---------------\n"
          data.issues.each_with_index do |issue, i|
            str << "#{i + 1}. #{issue.summary}\n"
            str << "   Type: #{issue.type}\n"
            str << "   Severity: #{issue.severity}\n"
            str << "   Detected: #{issue.detected_at}\n\n"
          end
        else
          str << "No performance issues detected.\n"
        end
      end
    end
  end
end
