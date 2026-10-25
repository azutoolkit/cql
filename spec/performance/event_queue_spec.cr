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

private def stuck_queue(capacity = 8) : CQL::Telemetry::EventQueue(Int32)
  entered = Channel(Nil).new
  queue = CQL::Telemetry::EventQueue(Int32).new(capacity) { |_| entered.send(nil); Channel(Nil).new.receive }
  queue.push(1)
  entered.receive
  queue
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
    entered, gate, flushed, seen = Channel(Nil).new(3), Channel(Nil).new(3), Channel(Nil).new, [] of Int32
    queue = CQL::Telemetry::EventQueue(Int32).new(8) { |event| entered.send(nil); gate.receive; seen << event }
    {1, 2, 3}.each { |event| queue.push(event) }
    spawn { queue.flush; flushed.send(nil) }
    entered.receive
    queue.close
    3.times { gate.send(nil) }
    within { flushed.receive }
    within { queue.flush }.should be_false
    queue.push(4).should be_false
    seen.should eq([1])
  end
end
