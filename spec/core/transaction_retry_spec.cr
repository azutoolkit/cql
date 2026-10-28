require "../spec_helper"

# SQLite standing in for PostgreSQL, whose own classification of retryable errors is what decides.
private class PostgresRetrySqliteDialect < Expression::SqliteDialect
  def retryable_transaction_error?(error : Exception) : Bool
    CQL::Adapter::Postgres.dialect.retryable_transaction_error?(error)
  end
end

private class PostgresRetrySqliteSchema < CQL::Schema
  def dialect
    PostgresRetrySqliteDialect.new
  end
end

private def server_error(sqlstate : String, message = "conflict") : CQL::Postgres::ServerError
  CQL::Postgres::ServerError.from({'C' => sqlstate, 'M' => message})
end

describe "CQL::Schema#retrying_transaction" do
  plain = spec_sqlite_schema("transaction_retry.db")
  retrying = PostgresRetrySqliteSchema.new(:tx_retry, plain.uri, CQL::Adapter::SQLite)
  plain.exec("CREATE TABLE IF NOT EXISTS tx_retry_rows (label TEXT)")

  before_each { plain.exec("DELETE FROM tx_retry_rows") }

  it "runs the whole block again after a serialization failure, keeping only the last run's work and value" do
    runs = 0
    result = retrying.retrying_transaction(isolation: :serializable) do |tx|
      runs += 1
      tx.connection.exec("INSERT INTO tx_retry_rows (label) VALUES (?)", "run #{runs}")
      raise server_error("40001") if runs == 1
      "run #{runs}"
    end
    committed = plain.exec_query(&.query_all("SELECT label FROM tx_retry_rows", as: String))
    {result, runs, committed}.should eq({"run 2", 2, ["run 2"]})
  end

  it "stops after attempts runs, 3 by default, raising the last run's error" do
    runs = 0
    error = expect_raises(CQL::Postgres::DeadlockDetected) { retrying.retrying_transaction { runs += 1; raise server_error("40P01", "run #{runs}") } }
    expect_raises(CQL::Postgres::DeadlockDetected) { retrying.retrying_transaction(2) { runs += 1; raise server_error("40P01", "run #{runs}") } }
    {error.server_message, runs}.should eq({"run 3", 5}) # the first call's last error, then 2 runs of the second
  end

  it "raises an error that is not retryable after one run, as does a dialect that retries nothing" do
    [{retrying, server_error("23505")}, {retrying, RuntimeError.new("boom")}, {plain, server_error("40001")}].each do |(schema, error)|
      runs = 0
      expect_raises(Exception) { schema.retrying_transaction { runs += 1; raise error } }.should be error
      runs.should eq 1
    end
  end

  it "refuses attempts below 1, a call inside a transaction (only a savepoint would run again) and a missing mode" do
    expect_raises(ArgumentError, /attempts/) { retrying.retrying_transaction(attempts: 0) { raise "the block ran" } }
    retrying.transaction { expect_raises(ArgumentError) { retrying.retrying_transaction { raise "the block ran" } } }
    expect_raises(CQL::DialectError, /read.?only/i) { retrying.retrying_transaction(read_only: true) { raise "the block ran" } }
  end

  it "retries only the native PostgreSQL driver's serialization failures and deadlocks, on PostgreSQL and CockroachDB" do
    pg_shard_failure = PQ::PQError.new([PQ::Frame::ErrorResponse::Field.new(:code, "40001", 'C'.ord.to_u8)]) # the pg shard's, not retried
    errors = [server_error("40001"), server_error("40P01"), server_error("40003"), server_error("23505"), RuntimeError.new("boom"), pg_shard_failure]
    {CQL::Adapter::Postgres => true, CQL::Adapter::CockroachDB => true, CQL::Adapter::MySql => false, CQL::Adapter::SQLite => false}.each do |adapter, retryable|
      verdicts = errors.map { |error| adapter.dialect.retryable_transaction_error?(error) }
      {adapter, verdicts}.should eq({adapter, [retryable, retryable, false, false, false, false]})
    end
  end
end
