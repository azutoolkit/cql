require "../spec_helper"

# Raises *error* once the work committed, as a COMMIT whose reply was lost, or that the server refused, would.
private class FailingCommitSource < CQL::DatabaseSource
  property error : Exception = RuntimeError.new("no COMMIT failure set")

  # crystal-db's own `transaction` runs the COMMIT, so it fails where a real one does: also while a `return` unwinds.
  def transaction(& : DB::Transaction -> _)
    using_connection { |connection| FailingCommit.new(connection, error).transaction { |tx| yield tx } }
  end
end

private record FailingCommit, connection : DB::Connection, error : Exception do
  include DB::BeginTransaction

  def begin_transaction : DB::Transaction
    FailingCommitTransaction.new(connection, error)
  end
end

private class FailingCommitTransaction < DB::TopLevelTransaction
  def initialize(connection : DB::Connection, @error : Exception)
    super(connection)
  end

  def commit
    connection.perform_commit_transaction
    @commit_failed = true
    raise @error
  end

  # The ROLLBACK crystal-db sends after a failed COMMIT: a warning on PostgreSQL, skipped on a dropped session.
  def rollback
    @commit_failed ? close : super
  end
end

# SQLite standing in for PostgreSQL, whose own classification of COMMIT failures is what decides.
private class PostgresCommitSqliteSchema < CQL::Schema
  def dialect
    CQL::Adapter::Postgres.dialect
  end
end

describe "CQL::Schema#on_rollback" do
  schema = spec_sqlite_schema("rollback_hooks.db")
  source = FailingCommitSource.new(DB.open(schema.uri))
  failing = PostgresCommitSqliteSchema.new(:rollback_hooks, schema.uri, CQL::Adapter::SQLite, source: source)
  refused = CQL::Postgres::ServerError.from({'C' => "40001", 'M' => "refused"})
  ran = [] of Symbol
  before_each { ran.clear }

  it "runs the hooks newest first when the block raises or rolls back, not on commit nor outside a transaction" do
    schema.on_rollback { ran << :outside }
    expect_raises(Exception, "boom") { schema.transaction { schema.on_rollback { ran << :older }; schema.on_rollback { ran << :newer }; raise "boom" } }
    schema.transaction { schema.on_rollback { ran << :rolled_back }; raise DB::Rollback.new }.should be_nil
    schema.transaction { schema.on_rollback { ran << :committed } }
    ran.should eq [:newer, :older, :rolled_back]
  end

  it "runs a rolled-back savepoint's hook at once, and a committed one's when the enclosing transaction rolls back" do
    schema.transaction do
      schema.transaction { schema.on_rollback { ran << :undone_savepoint }; raise DB::Rollback.new }
      schema.transaction { schema.on_rollback { ran << :kept_savepoint } }
    end
    schema.transaction { schema.transaction { schema.on_rollback { ran << :savepoint } }; raise DB::Rollback.new }
    ran.should eq [:undone_savepoint, :savepoint]
  end

  it "skips the hooks of a transaction or savepoint the block ended itself before raising, a savepoint's go up" do
    {:commit, :rollback}.each do |ending|
      expect_raises(Exception, "after") { schema.transaction { |tx| schema.on_rollback { ran << ending }; ending == :commit ? tx.commit : tx.rollback; raise "after" } }
    end
    [nil, DB::Rollback.new].each do |outer_ending|
      schema.transaction do
        expect_raises(Exception, "after") { schema.transaction { |savepoint| schema.on_rollback { ran << :released }; savepoint.commit; raise "after" } }
        outer_ending.try { |rollback| raise rollback }
      end
    end
    ran.should eq [:released] # only the enclosing transaction that rolled back ran it
  end

  it "after a failed COMMIT runs the hooks only for an error the dialect calls a refusal, then raises it" do
    [{CQL::Postgres::ConnectionLost.new("reply lost"), :lost}, {refused, :refused}, {CQL::Postgres::TransactionAborted.new("aborted"), :aborted}].each do |(error, label)|
      source.error = error
      expect_raises(Exception) { failing.transaction { failing.on_rollback { ran << label } } }.should be error
    end
    ran.should eq [:refused, :aborted]
  end

  it "after a return or break out of the block or a savepoint in it, runs the hooks only for a refused COMMIT and raises it" do
    [{CQL::Postgres::ConnectionLost.new("reply lost"), [] of Symbol}, {refused, [:inner, :outer, :returned, :broke]}].each do |(error, expected)|
      ran.clear
      source.error = error
      nested = -> { failing.transaction { failing.on_rollback { ran << :outer }; failing.transaction { failing.on_rollback { ran << :inner }; return } } }
      expect_raises(Exception) { nested.call }.should be error # and leaves no frame: the next ones are top-level
      expect_raises(Exception) { -> { failing.transaction { failing.on_rollback { ran << :returned }; return } }.call }.should be error
      expect_raises(Exception) { failing.transaction { failing.on_rollback { ran << :broke }; break } }.should be error
      ran.should eq expected
    end
  end

  it "publishes one end event per transaction after a return out of a savepoint whose enclosing COMMIT failed" do
    ends = [] of Int64
    CQL::Telemetry.subscribe_transactions("rollback_hooks_spec") { |event| ends << event.id unless event.state.begin? }
    source.error = refused
    expect_raises(Exception) { -> { failing.transaction { failing.transaction { return } } }.call }
    ends.size.should eq 2
    ends.uniq.size.should eq 2
  ensure
    CQL::Telemetry.unsubscribe_transactions("rollback_hooks_spec")
  end

  it "skips a savepoint's hooks when its block committed the enclosing transaction before raising" do
    expect_raises(Exception) { schema.transaction { |outer| schema.transaction { schema.on_rollback { ran << :inner }; outer.commit; raise "after" } } }
    ran.should be_empty
  end

  it "calls a COMMIT failure refused on PostgreSQL and CockroachDB only for a server answer or a request never sent" do
    errors = [refused, CQL::Postgres::TransactionAborted.new("aborted"), CQL::Postgres::ConnectionClosed.new("closed"),
              CQL::Postgres::ConnectionLost.new("lost"), CQL::Postgres::QueryTimeout.new("timeout"), IO::Error.new("io"), RuntimeError.new("boom"),
              CQL::Postgres::ServerError.from({'S' => "FATAL", 'C' => "08P01", 'M' => "lost"}), CQL::Postgres::ServerError.from({'C' => "40003", 'M' => "ambiguous"})]
    verdicts = [CQL::Adapter::Postgres, CQL::Adapter::CockroachDB, CQL::Adapter::MySql, CQL::Adapter::SQLite].map { |adapter| errors.map { |error| adapter.dialect.commit_refused?(error) } }
    verdicts.should eq [[true, true, true, false, false, false, false, false, false]] * 2 + [[false] * 9] * 2
  end

  it "runs every hook when one raises, and the caller still sees the transaction's own outcome" do
    expect_raises(Exception, "boom") { schema.transaction { schema.on_rollback { ran << :older }; schema.on_rollback { raise "hook failed" }; raise "boom" } }
    schema.transaction { schema.on_rollback { ran << :quiet }; schema.on_rollback { raise "hook failed" }; raise DB::Rollback.new }.should be_nil
    ran.should eq [:older, :quiet]
  end

  it "shares hooks with a transaction passed in only when it is on the enclosing transaction's connection" do
    DB.open(schema.uri) do |other|
      schema.transaction do |tx|
        schema.transaction(tx) { schema.on_rollback { ran << :same_connection } }
        other.transaction { |otx| schema.transaction(otx) { schema.on_rollback { ran << :other_connection } } }
        raise DB::Rollback.new
      end
    end
    ran.should eq [:same_connection]
  end
end
