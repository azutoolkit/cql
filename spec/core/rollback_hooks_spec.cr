require "../spec_helper"

# Raises *error* once the work committed, as a COMMIT whose reply was lost, or that the server refused, would.
private class FailingCommitSource < CQL::DatabaseSource
  property error : Exception = RuntimeError.new("no COMMIT failure set")

  def transaction(& : DB::Transaction -> _)
    super { |tx| yield tx }
    raise error
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
