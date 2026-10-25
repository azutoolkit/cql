require "../spec_helper"

# Not `CQL::Migration(V)` subclasses: those register themselves in the global `CQL::Migrator.migrations`.
abstract class TxMigration < CQL::BaseMigration
  getter schema : CQL::Schema

  def initialize(@schema : CQL::Schema); end

  def down
  end
end

class TxMigrationCreateA < TxMigration
  def self.version : Int64
    1_i64
  end

  def up
    schema.exec("CREATE TABLE tx_migration_a (id INTEGER)")
  end
end

class TxMigrationCreateBThenFail < TxMigration
  def self.version : Int64
    2_i64
  end

  def up
    schema.exec("CREATE TABLE tx_migration_b (id INTEGER)")
    raise "boom"
  end
end

class TxMigrationCreateC < TxMigration
  def self.version : Int64
    3_i64
  end

  def up
    schema.exec("CREATE TABLE tx_migration_c (id INTEGER)")
  end
end

# SQLite underneath, but reports MySQL's dialect, so DDL is treated as non-transactional.
class TxNonTransactionalDdlSchema < CQL::Schema
  def dialect
    CQL::Adapter::MySql.dialect
  end
end

private def with_migrator(uri : String, *migrations : CQL::BaseMigration.class, schema_class : CQL::Schema.class = CQL::Schema, &)
  original = CQL::Migrator.migrations
  migrator = CQL::Migrator.new(schema_class.new(:migration_tx, uri, CQL::Adapter::SQLite), CQL::MigratorConfig.new(auto_sync: false))
  begin
    CQL::Migrator.migrations = [*migrations] of CQL::BaseMigration.class
    yield migrator
  ensure
    CQL::Migrator.migrations = original
    migrator.schema.close
  end
end

describe "CQL::Migrator#up transaction" do
  db_file = File.join(Dir.tempdir, "cql_migration_tx_#{Process.pid}_#{Random::Secure.hex(4)}.db")
  uri = "sqlite3://#{db_file}"

  # Reads through a separate connection, so it sees only committed state.
  committed_tables = -> do
    DB.open(uri, &.query_all("SELECT name FROM sqlite_master WHERE type = 'table' AND name GLOB 'tx_migration_*' ORDER BY name", as: String))
  end
  committed_versions = -> do
    DB.open(uri, &.query_all("SELECT version FROM cql_schema_migrations ORDER BY version", as: Int64))
  end

  before_each do
    DB.open(uri) do |db|
      %w[tx_migration_a tx_migration_b tx_migration_c cql_schema_migrations].each { |table| db.exec("DROP TABLE IF EXISTS #{table}") }
    end
  end

  after_all do
    ["", "-wal", "-shm", "-journal"].each do |suffix|
      path = db_file + suffix
      File.delete(path) if File.exists?(path)
    end
  end

  it "rolls back earlier migrations and their records when a later one fails" do
    registered = CQL::Migrator.migrations.dup

    with_migrator(uri, TxMigrationCreateA, TxMigrationCreateBThenFail) do |migrator|
      expect_raises(Exception, "boom") { migrator.up }
    end

    committed_tables.call.should be_empty
    committed_versions.call.should be_empty
    CQL::Migrator.migrations.should eq(registered)
  end

  it "keeps earlier migrations applied when a later one fails without transactional DDL" do
    with_migrator(uri, TxMigrationCreateA, TxMigrationCreateBThenFail, schema_class: TxNonTransactionalDdlSchema) do |migrator|
      expect_raises(Exception, "boom") { migrator.up }
    end

    committed_tables.call.should eq(["tx_migration_a", "tx_migration_b"])
    committed_versions.call.should eq([TxMigrationCreateA.version])
  end

  it "refuses to run inside a caller's transaction without transactional DDL" do
    with_migrator(uri, TxMigrationCreateA, schema_class: TxNonTransactionalDdlSchema) do |migrator|
      expect_raises(CQL::DialectError, "MySQL") { migrator.schema.transaction { migrator.up } }
    end

    committed_tables.call.should be_empty
    committed_versions.call.should be_empty
  end

  it "runs every migration and its record on the single pooled connection" do
    pool_of_one = "#{uri}?initial_pool_size=0&max_pool_size=1&checkout_timeout=0.05"

    with_migrator(pool_of_one, TxMigrationCreateA, TxMigrationCreateC) do |migrator|
      migrator.up

      migrator.applied_migrations.map(&.version).should eq([TxMigrationCreateA.version, TxMigrationCreateC.version])
    end

    committed_tables.call.should eq(["tx_migration_a", "tx_migration_c"])
  end
end
