require "spec"
require "sqlite3"
require "../src/cql/mysql"
require "../src/cql"

# Deliberately fails if the requested server is missing: no pending matrix jobs.
V1_ADAPTER = case ENV.fetch("CQL_ENTERPRISE_DIALECT")
             when "sqlite"    then CQL::Adapter::SQLite
             when "postgres"  then CQL::Adapter::Postgres
             when "mysql"     then CQL::Adapter::MySql
             when "cockroach" then CQL::Adapter::CockroachDB
             else                  raise "unknown CQL_ENTERPRISE_DIALECT"
             end
V1_DATABASE = CQL::Schema.define(:enterprise_validation, adapter: V1_ADAPTER, uri: ENV.fetch("CQL_ENTERPRISE_URL")) do
  table :cql_v1_records do
    primary :id, Int64, auto_increment: false
    text :name
    lock_version :lock_version
  end
end

class V1Record
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::OptimisticLocking
  db_context V1_DATABASE, :cql_v1_records
  property name : String = ""
  property lock_version : Int32 = 1
  optimistic_locking

  def initialize
  end
end

private def current_v1_isolation : String
  sql = if V1_ADAPTER.my_sql?
          # @@transaction_isolation is the session default, not SET TRANSACTION's
          # one-transaction override. CI enables this performance_schema consumer.
          "SELECT ISOLATION_LEVEL FROM performance_schema.events_transactions_current " \
          "WHERE THREAD_ID = (SELECT THREAD_ID FROM performance_schema.threads WHERE PROCESSLIST_ID = CONNECTION_ID())"
        else
          "SHOW transaction_isolation"
        end
  V1_DATABASE.with_connection(&.query_one(sql, as: String)).downcase.tr("-", " ")
end

describe "live #{V1_ADAPTER} release contract" do
  before_all { V1_DATABASE.build }
  before_each do
    V1_DATABASE.exec("DELETE FROM cql_v1_records")
    V1_DATABASE.insert.into(:cql_v1_records).values(id: 1_i64, name: "original", lock_version: 1).commit
  end
  after_all do
    V1_DATABASE.cql_v1_records.drop!
    V1_DATABASE.close
  end

  it "rejects stale model updates and deletes" do
    winner = V1Record.find!(1_i64)
    stale = V1Record.find!(1_i64)
    winner.name = "winner"
    winner.update!
    winner.lock_version.should eq 2
    stale.name = "lost"
    expect_raises(CQL::OptimisticLockError) { stale.update! }
    expect_raises(CQL::OptimisticLockError) { stale.delete! }
    V1Record.find!(1_i64).name.should eq "winner"
  end

  it "rolls back a savepoint while committing the outer update" do
    V1_DATABASE.transaction do
      V1_DATABASE.update.table(:cql_v1_records).set(name: "outer").where(id: 1_i64).commit
      V1_DATABASE.transaction do
        V1_DATABASE.update.table(:cql_v1_records).set(name: "inner").where(id: 1_i64).commit
        raise DB::Rollback.new
      end
      V1Record.find!(1_i64).name.should eq "outer"
    end
    V1Record.find!(1_i64).name.should eq "outer"
  end

  it "rolls back a released savepoint when the outer transaction aborts" do
    V1_DATABASE.transaction do
      V1_DATABASE.transaction do
        V1_DATABASE.update.table(:cql_v1_records).set(name: "inner").where(id: 1_i64).commit
      end
      raise DB::Rollback.new
    end
    V1Record.find!(1_i64).name.should eq "original"
  end

  it "enforces serializable isolation and explicit read-committed support" do
    V1_DATABASE.transaction(isolation: :serializable) do
      unless V1_ADAPTER.sq_lite?
        current_v1_isolation.should eq "serializable"
      end
    end
    if V1_ADAPTER.sq_lite?
      expect_raises(CQL::DialectError) { V1_DATABASE.transaction(isolation: :read_committed) { fail "unsupported isolation ran" } }
    else
      V1_DATABASE.transaction(isolation: :read_committed) do
        # CockroachDB versions may strengthen READ COMMITTED to SERIALIZABLE.
        level = current_v1_isolation
        allowed = V1_ADAPTER.cockroach_db? ? ["read committed", "serializable"] : ["read committed"]
        allowed.should contain level
      end
    end
  end
end
