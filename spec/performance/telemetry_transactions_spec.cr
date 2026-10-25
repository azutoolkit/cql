require "../spec_helper"

describe "CQL::Telemetry transactions" do
  schema = spec_sqlite_schema("telemetry_transactions.db")
  events = [] of CQL::Telemetry::TransactionEvent

  before_each do
    CQL::Telemetry.reset!
    events.clear
    CQL::Telemetry.subscribe_transactions("spec") { |event| events << event }
  end

  after_each { CQL::Telemetry.reset! }

  it "reports Begin then Commit with one id" do
    schema.transaction { |_tx| }

    events.map(&.state).should eq([CQL::Telemetry::TransactionState::Begin, CQL::Telemetry::TransactionState::Commit])
    events.map(&.id).uniq!.size.should eq(1)
    events[0].duration.should eq(Time::Span.zero)
    events[1].duration.should be >= Time::Span.zero
    events.map(&.error).should eq([nil, nil])
    events.map(&.nested).should eq([false, false])
    events.map(&.adapter).uniq!.should eq([CQL::Adapter::SQLite])
  end

  it "reports Rollback with the error and re-raises it" do
    expect_raises(Exception, "boom") { schema.transaction { |_tx| raise "boom" } }

    events.map(&.state).should eq([CQL::Telemetry::TransactionState::Begin, CQL::Telemetry::TransactionState::Rollback])
    events[1].error.not_nil!.message.should eq("boom")
  end

  it "publishes Begin before the pool checkout and counts the wait in the duration" do
    busy = spec_sqlite_schema("telemetry_tx_busy.db", "?initial_pool_size=0&max_pool_size=1&checkout_timeout=5")
    done = Channel(Nil).new
    busy.with_connection do |_connection|
      spawn { busy.transaction { |_tx| }; done.send(nil) }
      Fiber.yield
      events.map(&.state).should eq([CQL::Telemetry::TransactionState::Begin])
    end
    done.receive

    events.map(&.state).should eq([CQL::Telemetry::TransactionState::Begin, CQL::Telemetry::TransactionState::Commit])
  end

  it "reports a failed checkout as Rollback" do
    busy = spec_sqlite_schema("telemetry_tx_timeout.db", "?initial_pool_size=0&max_pool_size=1&checkout_timeout=0.05")
    busy.with_connection do |_connection|
      expect_raises(DB::PoolTimeout) { busy.transaction { |_tx| } }
    end

    events.map(&.state).should eq([CQL::Telemetry::TransactionState::Begin, CQL::Telemetry::TransactionState::Rollback])
    events.last.error.should be_a(DB::PoolTimeout)
  end

  it "reports DB::Rollback as a swallowed Rollback" do
    schema.transaction { |_tx| raise DB::Rollback.new }

    events.map(&.state).should eq([CQL::Telemetry::TransactionState::Begin, CQL::Telemetry::TransactionState::Rollback])
    events[1].error.should be_a(DB::Rollback)
  end

  it "reports a manual tx.rollback followed by a normal return as Commit (known limit)" do
    schema.transaction(&.rollback)

    events.last.state.should eq(CQL::Telemetry::TransactionState::Commit)
  end

  it "gives each transaction a larger id" do
    2.times { schema.transaction { |_tx| } }

    events.map(&.id).should eq([events[0].id, events[0].id, events[0].id + 1, events[0].id + 1])
  end

  it "marks a transaction opened inside another as nested" do
    schema.transaction { |_tx| schema.transaction { |_inner| } }

    events.map(&.nested).should eq([false, true, true, false])
    events.map(&.state).should eq([
      CQL::Telemetry::TransactionState::Begin, CQL::Telemetry::TransactionState::Begin,
      CQL::Telemetry::TransactionState::Commit, CQL::Telemetry::TransactionState::Commit,
    ])
  end

  it "emits nothing for the existing-transaction overload" do
    emitted_inside = -1
    schema.transaction do |tx|
      events.clear
      schema.transaction(tx) { |_same| }
      emitted_inside = events.size
    end

    emitted_inside.should eq(0)
  end

  it "keeps the transaction working when a subscriber raises" do
    CQL::Telemetry.subscribe_transactions("bad") { |_event| raise "subscriber down" }
    ran = false

    schema.transaction { |_tx| ran = true }

    ran.should be_true
    events.last.state.should eq(CQL::Telemetry::TransactionState::Commit)
  end

  it "replaces a subscriber of the same name and can unsubscribe" do
    other = [] of CQL::Telemetry::TransactionEvent
    CQL::Telemetry.subscribe_transactions("spec") { |event| other << event }
    schema.transaction { |_tx| }
    events.should be_empty
    other.size.should eq(2)

    CQL::Telemetry.unsubscribe_transactions("spec")
    schema.transaction { |_tx| }
    other.size.should eq(2)
  end

  it "reports subscribed? for query and transaction subscribers and clears both on reset!" do
    CQL::Telemetry.subscribe("queries") { |_event| }
    CQL::Telemetry.subscribed?("spec").should be_true
    CQL::Telemetry.subscribed?("queries").should be_true
    CQL::Telemetry.subscribed?("nobody").should be_false

    CQL::Telemetry.reset!
    CQL::Telemetry.subscribed?("spec").should be_false
    CQL::Telemetry.subscribed?("queries").should be_false
    schema.transaction { |_tx| }
    events.should be_empty
  end

  it "does not draw transaction ids without subscribers" do
    CQL::Telemetry.reset!
    before = CQL::Telemetry.next_transaction_id

    schema.transaction { |_tx| }

    CQL::Telemetry.next_transaction_id.should eq(before + 1)
  end
end

describe "CQL::Schema#pool_stats" do
  it "is all zeros before the first query when the pool starts empty" do
    schema = spec_sqlite_schema("pool_stats_empty.db", "?initial_pool_size=0")

    schema.pool_stats.should eq(CQL::PoolStats.new(0, 0, 0, 0))
  end

  it "counts the connection opened by a query as idle again afterwards" do
    schema = spec_sqlite_schema("pool_stats_query.db", "?initial_pool_size=0&max_pool_size=4")
    schema.exec("SELECT 1")

    stats = schema.pool_stats
    stats.open.should eq(1)
    stats.idle.should eq(1)
    stats.in_flight.should eq(0)
    stats.max.should eq(4)
  end

  it "counts a connection held by a transaction as in flight" do
    schema = spec_sqlite_schema("pool_stats_tx.db")

    schema.transaction { |_tx| schema.pool_stats.in_flight.should eq(1) }

    schema.pool_stats.in_flight.should eq(0)
  end
end
