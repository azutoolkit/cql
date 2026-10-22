require "../spec_helper"

private def build_schema(name : String)
  schema = CQL::Schema.define(:events_spec, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("#{name}.db")) do
    table :items do
      primary :id, Int64
      column :name, String
    end
  end
  # sqlite files persist between runs
  schema.exec("DROP TABLE IF EXISTS items")
  schema
end

describe CQL::Events do
  before_each { CQL::Events.clear }
  after_each { CQL::Events.clear }

  it "reports no subscribers by default" do
    CQL::Events.subscribed?(CQL::Events::QUERY).should be_false
  end

  it "stops delivering after unsubscribe" do
    count = 0
    sub = CQL::Events.on_query { |_| count += 1 }
    CQL::Events.emit(CQL::Events::QUERY, CQL::Events::QueryEvent.new("SELECT 1", [] of DB::Any, 1.0))
    CQL::Events.unsubscribe(sub)
    CQL::Events.emit(CQL::Events::QUERY, CQL::Events::QueryEvent.new("SELECT 1", [] of DB::Any, 1.0))
    count.should eq 1
    CQL::Events.subscribed?(CQL::Events::QUERY).should be_false
  end

  it "isolates failing subscribers" do
    seen = 0
    CQL::Events.on_query { |_| raise "boom" }
    CQL::Events.on_query { |_| seen += 1 }
    CQL::Events.emit(CQL::Events::QUERY, CQL::Events::QueryEvent.new("SELECT 1", [] of DB::Any, 1.0))
    seen.should eq 1
  end

  it "emits cql.connect, cql.query and rows for real statements" do
    connects = [] of CQL::Events::ConnectEvent
    queries = [] of CQL::Events::QueryEvent
    CQL::Events.on_connect { |e| connects << e }
    CQL::Events.on_query { |e| queries << e }

    schema = build_schema("events_basic")
    schema.build
    schema.exec("INSERT INTO items (name) VALUES ('a'), ('b')")
    schema.query.from(:items).select(:name).all(String)

    connects.size.should eq 1
    queries.map(&.sql).any?(&.starts_with?("INSERT")).should be_true
    select_event = queries.find! { |q| q.sql.starts_with?("SELECT") }
    select_event.rows.should eq 2
    select_event.error?.should be_false
  end

  it "emits query events with an error message when SQL fails" do
    queries = [] of CQL::Events::QueryEvent
    CQL::Events.on_query { |e| queries << e }
    schema = build_schema("events_error")
    schema.build
    expect_raises(Exception) { schema.exec("SELECT * FROM nope") }
    queries.last.error?.should be_true
  end

  it "emits transaction commit and rollback" do
    states = [] of CQL::Events::TransactionState
    CQL::Events.on_transaction { |e| states << e.state }
    schema = build_schema("events_tx")
    schema.build

    schema.transaction { |_tx| }
    schema.transaction { |_tx| raise DB::Rollback.new }
    expect_raises(Exception, "bad") { schema.transaction { |_tx| raise "bad" } }

    states.should eq [
      CQL::Events::TransactionState::Begin, CQL::Events::TransactionState::Commit,
      CQL::Events::TransactionState::Begin, CQL::Events::TransactionState::Rollback,
      CQL::Events::TransactionState::Begin, CQL::Events::TransactionState::Rollback,
    ]
  end

  it "exposes pool stats and read-only raw queries" do
    schema = build_schema("events_pool")
    schema.build
    schema.exec("INSERT INTO items (name) VALUES ('x')")
    schema.pool_stats.max.should be >= 0
    cols, rows = schema.raw_readonly("SELECT id, name FROM items")
    cols.should eq ["id", "name"]
    rows.should eq [["1", "x"]]
  end
end
