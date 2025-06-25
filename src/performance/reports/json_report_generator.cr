require "../interfaces"

module CQL::Performance::Reports
  # JSON Report Generator
  class JsonReportGenerator < ReportGenerator
    def format : String
      "json"
    end

    def generate(data : ReportData) : String
      {
        "report_type"  => "comprehensive",
        "generated_at" => data.metadata["generated_at"]? || Time.utc.to_s,
        "metadata"     => data.metadata,
        "issues"       => {
          "count"       => data.issues.size,
          "by_severity" => data.issues.group_by(&.severity.to_s),
          "details"     => data.issues.map { |issue|
            {
              "type"        => issue.type,
              "severity"    => issue.severity.to_s,
              "message"     => issue.message,
              "summary"     => issue.summary,
              "detected_at" => issue.detected_at.to_rfc3339,
            }
          },
        },
        "events_count" => data.events.size,
      }.to_json
    end
  end
end
