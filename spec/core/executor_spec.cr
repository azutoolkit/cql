require "../spec_helper"

# Counts what runs through it, then delegates to a real schema.
private class CountingExecutor
  include CQL::Executor

  getter statements = 0

  def initialize(@schema : CQL::Schema)
  end

  def adapter : CQL::Adapter
    @schema.adapter
  end

  def exec_query(& : DB::Connection -> _)
    @statements += 1
    @schema.exec_query { |connection| yield connection }
  end
end

private ExecutorDB = CQL::Schema.define(:executor_spec, spec_sqlite_uri("executor_spec.db"), CQL::Adapter::SQLite) do
  table :things do
    primary :id, Int64, auto_increment: true
    text :name
  end
end

describe CQL::Pinnable do
  before_each do
    ExecutorDB.exec("DROP TABLE IF EXISTS things")
    ExecutorDB.exec("CREATE TABLE things (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)")
  end

  it "runs queries, inserts, updates and deletes on any executor given to `using`" do
    executor = CountingExecutor.new(ExecutorDB)
    ExecutorDB.insert.into(:things).values(name: "a").using(executor).commit
    ExecutorDB.update.table(:things).set(name: "b").where(name: "a").using(executor).commit
    ExecutorDB.query.from(:things).select(:name).using(executor).all(as: String).should eq ["b"]
    ExecutorDB.delete.from(:things).where(name: "b").using(executor).commit
    executor.statements.should eq 4
  end

  it "still accepts a plain connection" do
    ExecutorDB.with_connection do |connection|
      ExecutorDB.insert.into(:things).values(name: "c").using(connection).commit
      ExecutorDB.query.from(:things).select(:name).using(connection).all(as: String).should eq ["c"]
    end
  end

  it "pins ActiveRecord model queries to an executor" do
    UserDB.users.create!
    begin
      executor = CountingExecutor.new(UserDB)
      TestUser.query.using(executor).to_a.should be_empty
      executor.statements.should eq 1
    ensure
      UserDB.users.drop!
    end
  end

  it "reports statements run on a custom executor to telemetry" do
    events = [] of CQL::Telemetry::QueryEvent
    CQL::Telemetry.subscribe("executor_spec") { |event| events << event }
    begin
      ExecutorDB.query.from(:things).select(:name).using(CountingExecutor.new(ExecutorDB)).all(as: String)
    ensure
      CQL::Telemetry.reset!
    end
    events.map(&.operation).should eq [:select]
  end
end
