require "../spec_helper"

# SQLite standing in for MySQL, which sets the level before BEGIN: like SET TRANSACTION there, `PRAGMA synchronous`
# is refused inside a transaction and holds per connection.
private class BeforeBeginSqliteDialect < Expression::SqliteDialect
  def isolation_before_begin? : Bool
    true
  end

  def isolation_level_sql(level : CQL::IsolationLevel) : String?
    "PRAGMA synchronous = OFF"
  end
end

private class BeforeBeginSqliteSchema < CQL::Schema
  def dialect
    BeforeBeginSqliteDialect.new
  end
end

# A source of the application's own, overriding `transaction`.
private class CountingSource < CQL::DatabaseSource
  getter transactions = 0

  def transaction(& : DB::Transaction -> _)
    @transactions += 1
    super { |transaction| yield transaction }
  end
end

describe "CQL::Schema#transaction(isolation:)" do
  schema = CQL::Schema.define(:tx_options, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("transaction_options.db")) do
    table :tx_option_rows do
      primary :id, Int32
      column :label, String
    end
  end
  committed_labels = -> { DB.open(schema.uri, &.query_all("SELECT label FROM tx_option_rows", as: String)) }

  before_each do
    schema.build
    schema.exec("DELETE FROM tx_option_rows")
  end

  it "commits a serializable transaction on SQLite, which is always serializable" do
    schema.transaction(isolation: :serializable) { schema.exec("INSERT INTO tx_option_rows (label) VALUES ('A')") }
    committed_labels.call.should eq ["A"]
  end

  it "refuses a level SQLite cannot honour before a transaction begins" do
    events = [] of CQL::Telemetry::TransactionEvent
    CQL::Telemetry.subscribe_transactions("tx_options_spec") { |event| events << event }
    expect_raises(CQL::DialectError, /SQLite.*read.?committed/i) do
      schema.transaction(isolation: :read_committed) { raise "the block ran" }
    end
    events.should be_empty
  ensure
    CQL::Telemetry.unsubscribe_transactions("tx_options_spec")
  end

  it "refuses isolation: on a nested transaction (a savepoint), leaving the outer one to commit" do
    schema.transaction do
      schema.exec("INSERT INTO tx_option_rows (label) VALUES ('outer')")
      expect_raises(ArgumentError) { schema.transaction(isolation: :serializable) { } }
    end
    committed_labels.call.should eq ["outer"]
  end

  it "gives PostgreSQL and CockroachDB the level as the transaction's first statement" do
    [CQL::Adapter::Postgres, CQL::Adapter::CockroachDB].each do |adapter|
      adapter.dialect.isolation_level_sql(CQL::IsolationLevel::Serializable).should eq "SET TRANSACTION ISOLATION LEVEL SERIALIZABLE"
      adapter.dialect.isolation_level_sql(CQL::IsolationLevel::ReadCommitted).should eq "SET TRANSACTION ISOLATION LEVEL READ COMMITTED"
    end
  end

  it "runs a before-BEGIN dialect's statement on the transaction's connection before BEGIN, and commits the work" do
    # Two idle connections: a statement run on a checkout of its own would leave the transaction's connection at 2 (FULL).
    before_begin = BeforeBeginSqliteSchema.new(:tx_before_begin, "#{schema.uri}?initial_pool_size=2&max_idle_pool_size=2", CQL::Adapter::SQLite)
    before_begin.transaction(isolation: :serializable) do |tx|
      before_begin.exec("INSERT INTO tx_option_rows (label) VALUES ('B')")
      tx.connection.scalar("PRAGMA synchronous").should eq 0
    end
    committed_labels.call.should eq ["B"]
  ensure
    before_begin.try &.close
  end

  it "refuses a misspelled level, naming the valid ones" do
    expect_raises(ArgumentError, /:serialisable.*:read_uncommitted.*:serializable/) { schema.transaction(isolation: :serialisable) { } }
  end

  it "opens a transaction without isolation: through a custom source's own transaction" do
    source = CountingSource.new(DB.open(schema.uri))
    counted = CQL::Schema.new(:tx_options_counted, schema.uri, CQL::Adapter::SQLite, source: source)
    counted.transaction { counted.exec("INSERT INTO tx_option_rows (label) VALUES ('counted')") }
    source.transactions.should eq 1
    committed_labels.call.should eq ["counted"]
  ensure
    counted.try &.close
  end

  it "closes a connection whose BEGIN failed after the before-BEGIN statement, so no borrower inherits what it left" do
    source = CQL::DatabaseSource.new(DB.open("#{schema.uri}?max_pool_size=1"))
    source.using_connection(&.begin_transaction) # left open, so crystal-db refuses the next BEGIN on this connection
    expect_raises(DB::Error, /existing transaction/) { source.transaction("SELECT 1") { raise "the block ran" } }
    source.transaction(&.connection.scalar("SELECT 1")).should eq 1
  ensure
    source.try &.close
  end

  it "keeps CQL::Postgres::IsolationLevel as an alias of CQL::IsolationLevel" do
    CQL::Postgres::IsolationLevel::Serializable.should eq CQL::IsolationLevel::Serializable
  end
end
