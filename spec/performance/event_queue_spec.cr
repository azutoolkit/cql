require "../spec_helper"
require "log/spec"

private def within(span : Time::Span = 1.second, file = __FILE__, line = __LINE__, &block : -> T) : T forall T
  done = Channel(T).new(1)
  spawn { done.send(block.call) }
  select
  when value = done.receive then value
  when timeout(span) then fail("still running after #{span}", file, line)
  end
end

private def stuck_queue_of(first : T, capacity = 8) : CQL::Telemetry::EventQueue(T) forall T
  entered = Channel(Nil).new
  queue = CQL::Telemetry::EventQueue(T).new(capacity) { |_| entered.send(nil); Channel(Nil).new.receive }
  queue.push(first)
  entered.receive
  queue
end

private def stuck_queue(capacity = 8) : CQL::Telemetry::EventQueue(Int32)
  stuck_queue_of(1, capacity)
end

private def query_event : CQL::Telemetry::QueryEvent
  CQL::Telemetry::QueryEvent.new("SELECT 1", 0, nil, 1.millisecond, nil, CQL::Adapter::SQLite, :select, nil, nil)
end

describe CQL::Telemetry::EventQueue do
  it "hands events to the handler in push order, falsy ones included" do
    seen = [] of Bool?
    queue = CQL::Telemetry::EventQueue(Bool?).new(8) { |event| seen << event }
    {true, false, nil, true}.each { |event| queue.push(event).should be_true }
    within { queue.flush }.should be_true
    seen.should eq([true, false, nil, true])
  end

  it "drops instead of blocking when the queue is full" do
    queue = stuck_queue(1)
    queue.push(2).should be_true
    within { queue.push(3) }.should be_false
    queue.dropped.should eq(1)
  end

  describe "#push with a block" do
    it "does not build the item for a closed queue" do
      queue, built = CQL::Telemetry::EventQueue(Int32).new(1) { |_| }, false
      queue.close
      queue.push { built = true; 1 }.should be_false
      built.should be_false
    end

    it "does not build the item for a full queue, and counts the drop" do
      queue, built = stuck_queue(1), false
      queue.push(2).should be_true
      within { queue.push { built = true; 3 } }.should be_false
      {built, queue.dropped}.should eq({false, 1})
    end

    it "builds the item once for a queue with room, and the handler receives it" do
      seen, builds = [] of Int32, 0
      queue = CQL::Telemetry::EventQueue(Int32).new(8) { |event| seen << event }
      queue.push { builds += 1; 7 }.should be_true
      within { queue.flush }.should be_true
      {builds, seen}.should eq({1, [7]})
    end

    it "gives the slot back when the block raises" do
      queue = CQL::Telemetry::EventQueue(Int32).new(2) { |_| }
      2.times { expect_raises(Exception, "boom") { queue.push { raise "boom" } } }
      queue.push(1).should be_true
      queue.dropped.should eq(0)
      queue.close
    end
  end

  it "logs a handler that raises and carries on with the next event" do
    seen = [] of Int32
    queue = CQL::Telemetry::EventQueue(Int32).new(8) { |event| event == 1 ? raise("boom") : seen << event }
    Log.capture("*") do |logs|
      {1, 2}.each { |event| queue.push(event) }
      within { queue.flush }.should be_true
      logs.check("the failure") { |entry| entry.severity >= Log::Severity::Warn }
    end
    seen.should eq([2])
  end

  it "returns false from a flush called inside the handler" do
    flushed = Channel(Bool).new
    queue = uninitialized CQL::Telemetry::EventQueue(Int32)
    queue = CQL::Telemetry::EventQueue(Int32).new(8) { |_| flushed.send(queue.flush) }
    queue.push(1)
    within { flushed.receive }.should be_false
  end

  it "returns false from a flush that times out on a stuck handler" do
    queue = stuck_queue
    within { queue.flush(50.milliseconds) }.should be_false
  end

  it "releases a pending flush when closed while the handler is stuck" do
    queue, flushed = stuck_queue, Channel(Bool).new
    spawn { flushed.send(queue.flush) }
    Fiber.yield
    queue.close
    within { flushed.receive }.should be_false
  end

  it "skips buffered events once closed, and neither a pending flush nor a push waits on them" do
    entered, gate, handled, flushed = Channel(Nil).new(3), Channel(Nil).new(3), Channel(Nil).new(3), Channel(Nil).new
    seen = [] of Int32
    queue = CQL::Telemetry::EventQueue(Int32).new(8) { |event| entered.send(nil); gate.receive; seen << event; handled.send(nil) }
    {1, 2, 3}.each { |event| queue.push(event) }
    spawn { queue.flush; flushed.send(nil) }
    entered.receive
    queue.close
    3.times { gate.send(nil) }
    within { flushed.receive }
    within { queue.flush }.should be_false
    queue.push(4).should be_false
    within { handled.receive }
    seen.should eq([1])
  end

  it "accepts or drops every push, and the handler sees exactly the accepted events" do
    gate, entered, seen = Channel(Nil).new(64), Channel(Nil).new(64), [] of Int32
    queue = CQL::Telemetry::EventQueue(Int32).new(4) { |event| entered.send(nil); gate.receive; seen << event }
    queue.push(0)
    entered.receive
    accepted = (1..10).select { |event| queue.push(event) }
    (accepted.size + queue.dropped).should eq(10)
    accepted.size.should be <= 4
    10.times { gate.send(nil) }
    within { queue.flush }.should be_true
    seen.should eq([0] + accepted)
  end

  it "keeps timed-out flush markers from taking event slots" do
    queue = stuck_queue(4)
    3.times { queue.flush(5.milliseconds).should be_false }
    (1..4).count { |event| queue.push(event) }.should eq(4)
    queue.dropped.should eq(0)
  end

  it "refuses a flush past the pending cap at once, and takes flushes again once the handler moves on" do
    entered, gate = Channel(Nil).new, Channel(Nil).new(1)
    queue = CQL::Telemetry::EventQueue(Int32).new(8) { |_| entered.send(nil); gate.receive }
    queue.push(1)
    entered.receive
    CQL::Telemetry::EventQueue::MAX_PENDING_FLUSHES.times { queue.flush(1.millisecond).should be_false }
    within { queue.flush }.should be_false
    gate.send(nil)
    within { until queue.flush(20.milliseconds); end }
  end

  {0, -1, Int32::MAX}.each do |capacity|
    it "rejects a capacity of #{capacity}" do
      expect_raises(ArgumentError) { CQL::Telemetry::EventQueue(Int32).new(capacity) { |_| } }
    end
  end

  describe "allocation budget" do
    it "allocates nothing pushing with room" do
      event, queue = query_event, CQL::Telemetry::EventQueue(CQL::Telemetry::QueryEvent).new(30_000) { |_| }
      bytes_per_call(20_000) { queue.push(event) }.should be < 1.0
      queue.close
    end

    it "allocates nothing pushing on a full queue" do
      event = query_event
      queue = stuck_queue_of(event, 1)
      queue.push(event).should be_true
      bytes_per_call(20_000) { queue.push(event) }.should be < 1.0
    end

    it "allocates nothing pushing on a closed queue" do
      event, queue = query_event, CQL::Telemetry::EventQueue(CQL::Telemetry::QueryEvent).new(1) { |_| }
      queue.close
      bytes_per_call(20_000) { queue.push(event) }.should be < 1.0
    end
  end
end
