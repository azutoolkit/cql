require "../spec_helper"

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

  it "refuses a misspelled level, naming the valid ones" do
    expect_raises(ArgumentError, /:serialisable.*:read_uncommitted.*:serializable/) { schema.transaction(isolation: :serialisable) { } }
  end

  it "keeps CQL::Postgres::IsolationLevel as an alias of CQL::IsolationLevel" do
    CQL::Postgres::IsolationLevel::Serializable.should eq CQL::IsolationLevel::Serializable
  end
end
