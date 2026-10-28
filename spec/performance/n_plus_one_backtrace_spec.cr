require "../spec_helper"

describe "optional N+1 call-site diagnostics" do
  it "captures the first detected call site and preserves it as the count grows" do
    config = CQL::Performance::Config::Detection.new
    config.capture_backtrace = true
    detector = CQL::Performance::NPlusOneDetector.new(config)
    detector.record_query("SELECT * FROM parents")
    2.times { detector.record_query("SELECT * FROM children WHERE parent_id = ?") }
    trace = detector.patterns.first.backtrace
    trace.should_not be_nil
    trace.to_s.should contain "n_plus_one_backtrace_spec.cr"
    detector.record_query("SELECT * FROM children WHERE parent_id = ?")
    detector.patterns.first.backtrace.should be trace
  end

  it "does not capture stacks by default" do
    detector = CQL::Performance::NPlusOneDetector.new
    detector.record_query("SELECT * FROM parents")
    3.times { detector.record_query("SELECT * FROM children WHERE parent_id = ?") }
    detector.patterns.first.backtrace.should be_nil
  end
end
