require "../spec_helper"
require "../../src/performance/unified_report_generator"

# Helper to create a basic performance report for testing
private def build_test_report(
  duration = 1.minute,
  total_queries = 100,
  slow_queries = 5,
  errors = 2,
  issues = [] of CQL::Performance::Issue,
  metadata = {} of String => String
) : CQL::Performance::PerformanceReport
  CQL::Performance::PerformanceReport.new(
    duration: duration,
    total_queries: total_queries,
    slow_queries: slow_queries,
    errors: errors,
    issues: issues,
    metadata: metadata,
  )
end

private def build_test_issue(
  type = :slow_query,
  severity = :high,
  message = "Query exceeded threshold",
  details = {"table" => "users"} of String => String
) : CQL::Performance::Issue
  CQL::Performance::Issue.new(
    type: type,
    severity: severity,
    message: message,
    details: details,
  )
end

describe CQL::Performance::TextReportFormatter do
  it "output contains the report header" do
    report = build_test_report
    formatter = CQL::Performance::TextReportFormatter.new
    output = formatter.format(report)
    output.should contain("CQL Performance Report")
  end

  it "output contains overview metrics" do
    report = build_test_report(total_queries: 100, slow_queries: 5, errors: 2)
    formatter = CQL::Performance::TextReportFormatter.new
    output = formatter.format(report)
    output.should contain("Total Queries: 100")
    output.should contain("Slow Queries: 5")
    output.should contain("Errors: 2")
  end

  it "output contains duration" do
    report = build_test_report(duration: 1.minute)
    formatter = CQL::Performance::TextReportFormatter.new
    output = formatter.format(report)
    output.should contain("Duration: 1m 0s")
  end

  it "output contains no-issues message when no issues" do
    report = build_test_report(issues: [] of CQL::Performance::Issue)
    formatter = CQL::Performance::TextReportFormatter.new
    output = formatter.format(report)
    output.should contain("No performance issues detected")
  end

  it "output contains issue details when issues exist" do
    issue = build_test_issue
    report = build_test_report(issues: [issue])
    formatter = CQL::Performance::TextReportFormatter.new
    output = formatter.format(report)
    output.should contain("Performance Issues:")
    output.should contain("Query exceeded threshold")
    output.should contain("table: users")
  end

  it "output contains the generated timestamp" do
    report = build_test_report
    formatter = CQL::Performance::TextReportFormatter.new
    output = formatter.format(report)
    output.should contain("Generated:")
  end
end

describe CQL::Performance::JSONReportFormatter do
  it "output is valid JSON" do
    report = build_test_report
    formatter = CQL::Performance::JSONReportFormatter.new
    output = formatter.format(report)
    parsed = JSON.parse(output)
    parsed.should_not be_nil
  end

  it "output contains expected top-level keys" do
    report = build_test_report
    formatter = CQL::Performance::JSONReportFormatter.new
    output = formatter.format(report)
    parsed = JSON.parse(output)
    parsed["timestamp"].should_not be_nil
    parsed["duration_seconds"].should_not be_nil
    parsed["metrics"].should_not be_nil
    parsed["issues"].should_not be_nil
    parsed["stats"].should_not be_nil
    parsed["metadata"].should_not be_nil
  end

  it "output contains correct metric values" do
    report = build_test_report(total_queries: 100, slow_queries: 5, errors: 2)
    formatter = CQL::Performance::JSONReportFormatter.new
    output = formatter.format(report)
    parsed = JSON.parse(output)
    parsed["metrics"]["total_queries"].as_i.should eq(100)
    parsed["metrics"]["slow_queries"].as_i.should eq(5)
    parsed["metrics"]["errors"].as_i.should eq(2)
  end

  it "output contains issues when present" do
    issue = build_test_issue(type: :slow_query, severity: :high, message: "Too slow")
    report = build_test_report(issues: [issue])
    formatter = CQL::Performance::JSONReportFormatter.new
    output = formatter.format(report)
    parsed = JSON.parse(output)
    parsed["issues"].as_a.size.should eq(1)
    parsed["issues"][0]["type"].as_s.should eq("slow_query")
    parsed["issues"][0]["severity"].as_s.should eq("high")
    parsed["issues"][0]["message"].as_s.should eq("Too slow")
  end

  it "output contains empty issues array when no issues" do
    report = build_test_report
    formatter = CQL::Performance::JSONReportFormatter.new
    output = formatter.format(report)
    parsed = JSON.parse(output)
    parsed["issues"].as_a.should be_empty
  end

  it "output contains duration in seconds" do
    report = build_test_report(duration: 1.minute)
    formatter = CQL::Performance::JSONReportFormatter.new
    output = formatter.format(report)
    parsed = JSON.parse(output)
    parsed["duration_seconds"].as_f.should eq(60.0)
  end
end

describe CQL::Performance::HTMLReportFormatter do
  it "output contains DOCTYPE declaration" do
    report = build_test_report
    formatter = CQL::Performance::HTMLReportFormatter.new
    output = formatter.format(report)
    output.should contain("<!DOCTYPE html>")
  end

  it "output contains html, head, and body tags" do
    report = build_test_report
    formatter = CQL::Performance::HTMLReportFormatter.new
    output = formatter.format(report)
    output.should contain("<html>")
    output.should contain("</html>")
    output.should contain("<head>")
    output.should contain("</head>")
    output.should contain("<body>")
    output.should contain("</body>")
  end

  it "output contains the report title" do
    report = build_test_report
    formatter = CQL::Performance::HTMLReportFormatter.new
    output = formatter.format(report)
    output.should contain("<title>CQL Performance Report</title>")
    output.should contain("<h1>CQL Performance Report</h1>")
  end

  it "output contains metric cards" do
    report = build_test_report(total_queries: 100, slow_queries: 5, errors: 2)
    formatter = CQL::Performance::HTMLReportFormatter.new
    output = formatter.format(report)
    output.should contain("Total Queries")
    output.should contain("100")
    output.should contain("Slow Queries")
    output.should contain("5")
    output.should contain("Errors")
    output.should contain("2")
    output.should contain("Health Score")
  end

  it "output contains style section" do
    report = build_test_report
    formatter = CQL::Performance::HTMLReportFormatter.new
    output = formatter.format(report)
    output.should contain("<style>")
    output.should contain("</style>")
  end

  it "output contains no-issues message when no issues" do
    report = build_test_report
    formatter = CQL::Performance::HTMLReportFormatter.new
    output = formatter.format(report)
    output.should contain("No performance issues detected")
  end

  it "output contains issue details when issues exist" do
    issue = build_test_issue(message: "Query too slow")
    report = build_test_report(issues: [issue])
    formatter = CQL::Performance::HTMLReportFormatter.new
    output = formatter.format(report)
    output.should contain("Query too slow")
    output.should contain("issue-high")
  end

  it "output contains metrics div" do
    report = build_test_report
    formatter = CQL::Performance::HTMLReportFormatter.new
    output = formatter.format(report)
    output.should contain("class='metrics'")
    output.should contain("metric-card")
  end
end

describe CQL::Performance::ConsoleReportFormatter do
  it "returns a non-empty string" do
    report = build_test_report
    formatter = CQL::Performance::ConsoleReportFormatter.new
    output = formatter.format(report)
    output.should_not be_empty
  end

  it "output contains overview section" do
    report = build_test_report(total_queries: 100)
    formatter = CQL::Performance::ConsoleReportFormatter.new
    output = formatter.format(report)
    output.should contain("OVERVIEW")
    output.should contain("100")
  end

  it "output contains performance report header" do
    report = build_test_report
    formatter = CQL::Performance::ConsoleReportFormatter.new
    output = formatter.format(report)
    output.should contain("PERFORMANCE REPORT")
  end

  it "output contains excellent performance message when no issues" do
    report = build_test_report(issues: [] of CQL::Performance::Issue)
    formatter = CQL::Performance::ConsoleReportFormatter.new
    output = formatter.format(report)
    output.should contain("EXCELLENT PERFORMANCE")
  end

  it "output contains issue details when issues exist" do
    issue = build_test_issue(message: "Slow query detected")
    report = build_test_report(issues: [issue])
    formatter = CQL::Performance::ConsoleReportFormatter.new
    output = formatter.format(report)
    output.should contain("PERFORMANCE ISSUES")
    output.should contain("Slow query detected")
    output.should contain("DETAILS")
  end
end

describe CQL::Performance::PerformanceReport do
  describe "#to_h" do
    it "returns a hash with expected keys" do
      report = build_test_report(total_queries: 100, slow_queries: 5, errors: 2)
      hash = report.to_h
      hash.has_key?("timestamp").should be_true
      hash.has_key?("duration_ms").should be_true
      hash.has_key?("total_queries").should be_true
      hash.has_key?("slow_queries").should be_true
      hash.has_key?("errors").should be_true
      hash.has_key?("issues").should be_true
      hash.has_key?("stats").should be_true
      hash.has_key?("metadata").should be_true
    end

    it "returns correct numeric values" do
      report = build_test_report(total_queries: 100, slow_queries: 5, errors: 2)
      hash = report.to_h
      hash["total_queries"].as_i.should eq(100)
      hash["slow_queries"].as_i.should eq(5)
      hash["errors"].as_i.should eq(2)
    end

    it "returns duration in milliseconds" do
      report = build_test_report(duration: 1.minute)
      hash = report.to_h
      hash["duration_ms"].as_f.should eq(60_000.0)
    end

    it "returns timestamp as RFC3339 string" do
      report = build_test_report
      hash = report.to_h
      hash["timestamp"].as_s.should_not be_empty
      # Verify it looks like an RFC3339 timestamp
      hash["timestamp"].as_s.should match(/\d{4}-\d{2}-\d{2}T/)
    end

    it "returns empty issues array when no issues" do
      report = build_test_report
      hash = report.to_h
      hash["issues"].as_a.should be_empty
    end

    it "returns metadata" do
      report = build_test_report(metadata: {"env" => "test"})
      hash = report.to_h
      # metadata is a hash wrapped in JSON::Any
      hash["metadata"].should_not be_nil
    end
  end

  describe "#to_json" do
    it "returns valid JSON string" do
      report = build_test_report(total_queries: 50, slow_queries: 3, errors: 1)
      json_str = report.to_json
      parsed = JSON.parse(json_str)
      parsed["total_queries"].as_i.should eq(50)
      parsed["slow_queries"].as_i.should eq(3)
      parsed["errors"].as_i.should eq(1)
    end

    it "returns a non-empty JSON string" do
      report = build_test_report
      json_str = report.to_json
      json_str.should_not be_empty
      json_str.should start_with("{")
      json_str.should end_with("}")
    end
  end
end

describe CQL::Performance::UnifiedReportGenerator do
  describe "#generate" do
    it "generates a text report" do
      generator = CQL::Performance::UnifiedReportGenerator.new
      report = build_test_report
      output = generator.generate("text", report)
      output.should contain("CQL Performance Report")
      output.should contain("Total Queries:")
    end

    it "generates a JSON report" do
      generator = CQL::Performance::UnifiedReportGenerator.new
      report = build_test_report
      output = generator.generate("json", report)
      parsed = JSON.parse(output)
      parsed["metrics"].should_not be_nil
    end

    it "generates an HTML report" do
      generator = CQL::Performance::UnifiedReportGenerator.new
      report = build_test_report
      output = generator.generate("html", report)
      output.should contain("<!DOCTYPE html>")
      output.should contain("<h1>CQL Performance Report</h1>")
    end

    it "generates a console report" do
      generator = CQL::Performance::UnifiedReportGenerator.new
      report = build_test_report
      output = generator.generate("console", report)
      output.should_not be_empty
      output.should contain("PERFORMANCE REPORT")
    end

    it "falls back to text format for unknown format" do
      generator = CQL::Performance::UnifiedReportGenerator.new
      report = build_test_report
      output = generator.generate("unknown_format", report)
      output.should contain("CQL Performance Report")
      output.should contain("Total Queries:")
    end

    it "is case-insensitive for format names" do
      generator = CQL::Performance::UnifiedReportGenerator.new
      report = build_test_report
      output = generator.generate("JSON", report)
      parsed = JSON.parse(output)
      parsed["metrics"].should_not be_nil
    end

    it "supports logger as alias for console" do
      generator = CQL::Performance::UnifiedReportGenerator.new
      report = build_test_report
      output = generator.generate("logger", report)
      output.should_not be_empty
      output.should contain("PERFORMANCE REPORT")
    end
  end

  describe "#register_formatter" do
    it "registers a custom formatter" do
      generator = CQL::Performance::UnifiedReportGenerator.new
      custom_formatter = CQL::Performance::TextReportFormatter.new
      generator.register_formatter("custom", custom_formatter)
      generator.available_formats.should contain("custom")
    end

    it "uses a registered custom formatter for generation" do
      generator = CQL::Performance::UnifiedReportGenerator.new
      custom_formatter = CQL::Performance::TextReportFormatter.new
      generator.register_formatter("my_format", custom_formatter)
      report = build_test_report
      output = generator.generate("my_format", report)
      output.should contain("CQL Performance Report")
    end

    it "is case-insensitive when registering" do
      generator = CQL::Performance::UnifiedReportGenerator.new
      custom_formatter = CQL::Performance::TextReportFormatter.new
      generator.register_formatter("MyFormat", custom_formatter)
      generator.available_formats.should contain("myformat")
    end
  end

  describe "#available_formats" do
    it "returns all built-in formats" do
      generator = CQL::Performance::UnifiedReportGenerator.new
      formats = generator.available_formats
      formats.should contain("text")
      formats.should contain("json")
      formats.should contain("html")
      formats.should contain("console")
      formats.should contain("logger")
    end

    it "includes custom formatters after registration" do
      generator = CQL::Performance::UnifiedReportGenerator.new
      initial_count = generator.available_formats.size
      generator.register_formatter("csv", CQL::Performance::TextReportFormatter.new)
      generator.available_formats.size.should eq(initial_count + 1)
      generator.available_formats.should contain("csv")
    end
  end
end
