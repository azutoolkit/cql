require "../spec_helper"

# A copy of the histogram's RANGE (2^26 µs), kept literal so the spec fails if the range changes: samples of this
# length or more share the overflow bucket.
private RANGE = (1_i64 << 26).microseconds
private MAX   = 2.hours

private def p50_of(*durations : Time::Span) : Time::Span
  histogram = CQL::Performance::LatencyHistogram.new
  durations.each { |duration| histogram.record(duration) }
  histogram.percentile(0.5, durations.size.to_i64, Time::Span.zero, MAX)
end

describe CQL::Performance::LatencyHistogram do
  it "counts durations of its range or more in the overflow bucket" do
    p50_of(RANGE, 1.hour).should eq MAX
    p50_of(70.seconds, 1.hour).should eq MAX
  end

  it "keeps the longest duration below its range in the last regular bucket" do
    p50_of(RANGE - 1.microsecond).should eq RANGE
  end

  it "counts a sub-microsecond duration in the first bucket" do
    p50_of(500.nanoseconds).should eq 1.microsecond
  end

  it "keeps a short duration apart from the overflow bucket" do
    p50_of(3.microseconds, 1.hour).should eq 4.microseconds
  end
end
