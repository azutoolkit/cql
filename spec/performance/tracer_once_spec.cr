require "../spec_helper"

private class RepeatingTracer < CQL::Telemetry::Tracer
  def in_span(operation : Symbol, sql : String, &)
    2.times do
      yield
    rescue
      # An integration may swallow errors; CQL must still refuse the repeat.
    end
  end
end

describe "tracer execution contract" do
  it "refuses a second invocation even when the tracer swallows the error" do
    CQL::Telemetry.tracer = RepeatingTracer.new
    writes = 0
    expect_raises(CQL::Error, /more than once/) do
      CQL::Telemetry.in_span(:insert, "INSERT") { writes += 1 }
    end
    writes.should eq 1
  ensure
    CQL::Telemetry.reset!
  end
end
