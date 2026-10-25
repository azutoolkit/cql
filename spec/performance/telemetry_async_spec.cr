require "../spec_helper"

private def within(span : Time::Span = 2.seconds, file = __FILE__, line = __LINE__, &block : -> T) : T forall T
  done = Channel(T).new(1)
  spawn { done.send(block.call) }
  select
  when value = done.receive then value
  when timeout(span) then fail("still running after #{span}", file, line)
  end
end

describe "async telemetry subscribers" do
  seen = [] of CQL::Telemetry::QueryEvent
  gate = Channel(Nil).new
  statement = -> { UserDB.query.from(:users).select(:name).all(as: String) }
  flush = -> { within { CQL::Telemetry.flush } }

  before_each do
    CQL::Telemetry.reset!
    CQL::Telemetry.async_queue_capacity = 4096
    UserDB.users.create!
    seen.clear
    gate = Channel(Nil).new
  end

  after_each do
    gate.close
    CQL::Telemetry.reset!
    UserDB.users.drop!
  end

  it "delivers every event to an async subscriber once flushed, while a sync one stays inline" do
    inline = 0
    CQL::Telemetry.subscribe("sync") { |_| inline += 1 }
    CQL::Telemetry.subscribe("async", async: true) { |event| seen << event }
    20.times { |index| statement.call; inline.should eq(index + 1) }

    flush.call.should be_true
    seen.size.should eq(20)
  end

  it "drops events instead of blocking a statement when the queue is full" do
    CQL::Telemetry.async_queue_capacity = 1
    handled = 0
    CQL::Telemetry.subscribe("stuck", async: true) { |_| handled += 1; gate.receive? }
    within { 10.times { statement.call } }
    CQL::Telemetry.dropped_events.should be > 0

    gate.close
    flush.call.should be_true
    (handled + CQL::Telemetry.dropped_events).should eq(10)
  end

  it "isolates a raising async subscriber from queries and other async subscribers" do
    CQL::Telemetry.subscribe("broken", async: true) { |_| raise "subscriber bug" }
    CQL::Telemetry.subscribe("healthy", async: true) { |event| seen << event }
    5.times { statement.call.should be_empty }

    flush.call.should be_true
    seen.size.should eq(5)
  end

  it "makes a name subscribed again as sync a sync subscriber only" do
    calls = [] of Symbol
    CQL::Telemetry.subscribe("x", async: true) { |_| calls << :async }
    CQL::Telemetry.subscribe("x") { |_| calls << :sync }
    statement.call
    calls.should eq([:sync])

    flush.call
    calls.should eq([:sync])
  end

  it "closes the queue on reset! and gives the next async subscriber a fresh one" do
    CQL::Telemetry.async_queue_capacity = 1
    CQL::Telemetry.subscribe("stuck", async: true) { |_| gate.receive? }
    10.times { statement.call }
    CQL::Telemetry.dropped_events.should be > 0
    CQL::Telemetry.reset!
    CQL::Telemetry.dropped_events.should eq(0)
    flush.call

    CQL::Telemetry.subscribe("fresh", async: true) { |event| seen << event }
    statement.call
    flush.call.should be_true
    seen.size.should eq(1)
  end
end
