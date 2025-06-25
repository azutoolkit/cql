require "../interfaces"

module CQL::Performance::Reports
  # HTML Report Generator
  class HtmlReportGenerator < ReportGenerator
    def format : String
      "html"
    end

    def generate(data : ReportData) : String
      String.build do |str|
        str << "<!DOCTYPE html><html><head><title>CQL Performance Report</title>"
        str << generate_css_styles
        str << "</head><body>"

        str << "<h1>CQL Comprehensive Performance Report</h1>"
        str << "<div class='metadata'>"
        str << "<p><strong>Generated:</strong> #{data.metadata["generated_at"]? || Time.utc}</p>"
        str << "<p><strong>Uptime:</strong> #{data.metadata["uptime"]? || "N/A"}</p>"
        str << "<p><strong>Monitoring:</strong> #{data.metadata["monitoring_enabled"]? || "N/A"}</p>"
        str << "</div>"

        if data.issues.any?
          generate_issues_section(str, data.issues)
        else
          str << "<div class='no-issues'>No performance issues detected.</div>"
        end

        str << "</body></html>"
      end
    end

    private def generate_css_styles : String
      <<-CSS
      <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        h1 { color: #333; border-bottom: 2px solid #007acc; padding-bottom: 10px; }
        .metadata { background: white; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .issues-summary { display: flex; gap: 15px; margin-bottom: 20px; }
        .severity-box { background: white; padding: 15px; border-radius: 5px; text-align: center; min-width: 100px; }
        .severity-critical { border-left: 4px solid #d32f2f; }
        .severity-high { border-left: 4px solid #f57c00; }
        .severity-medium { border-left: 4px solid #fbc02d; }
        .severity-low { border-left: 4px solid #388e3c; }
        .issue-item { background: white; margin-bottom: 10px; padding: 15px; border-radius: 5px; border-left: 4px solid #ccc; }
        .issue-critical { border-left-color: #d32f2f; }
        .issue-high { border-left-color: #f57c00; }
        .issue-medium { border-left-color: #fbc02d; }
        .issue-low { border-left-color: #388e3c; }
        .no-issues { background: #e8f5e8; color: #2e7d32; padding: 20px; text-align: center; border-radius: 5px; }
      </style>
      CSS
    end

    private def generate_issues_section(str, issues : Array(PerformanceIssue))
      # Summary boxes
      by_severity = issues.group_by(&.severity)
      str << "<h2>Performance Issues Summary</h2>"
      str << "<div class='issues-summary'>"

      PerformanceIssue::Severity.values.each do |severity|
        count = by_severity[severity]?.try(&.size) || 0
        str << "<div class='severity-box severity-#{severity.to_s.downcase}'>"
        str << "<h3>#{count}</h3><p>#{severity}</p></div>"
      end
      str << "</div>"

      # Detailed issues
      str << "<h2>Detailed Issues</h2>"
      issues.each do |issue|
        str << "<div class='issue-item issue-#{issue.severity.to_s.downcase}'>"
        str << "<h4>#{issue.type.gsub("_", " ").capitalize}</h4>"
        str << "<p><strong>Severity:</strong> #{issue.severity}</p>"
        str << "<p><strong>Message:</strong> #{issue.message}</p>"
        str << "<p><strong>Summary:</strong> #{issue.summary}</p>"
        str << "<p><strong>Detected:</strong> #{issue.detected_at}</p>"
        str << "</div>"
      end
    end
  end
end
