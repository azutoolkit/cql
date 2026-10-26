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

class TxMigrationFailOnDown < TxMigration
  def self.version : Int64
    4_i64
  end

  def up
    schema.exec("CREATE TABLE tx_migration_e (id INTEGER)")
  end

  def down
    raise "boom"
  end
end

class TxMigrationDropDOnDown < TxMigration
  def self.version : Int64
    5_i64
  end

  def up
    schema.exec("CREATE TABLE tx_migration_d (id INTEGER)")
  end

  def down
    schema.exec("DROP TABLE tx_migration_d")
  end
end

private def tx_schema(uri : String, schema_class : CQL::Schema.class = CQL::Schema)
  schema_class.new(:migration_tx, uri, CQL::Adapter::SQLite)
end

private def with_migrator(uri : String, *migrations : CQL::BaseMigration.class, schema_class : CQL::Schema.class = CQL::Schema, &)
  original = CQL::Migrator.migrations
  migrator = CQL::Migrator.new(tx_schema(uri, schema_class), CQL::MigratorConfig.new(auto_sync: false))
  begin
    CQL::Migrator.migrations = [*migrations] of CQL::BaseMigration.class
    yield migrator
  ensure
    CQL::Migrator.migrations = original
    migrator.schema.close
  end
end

describe "CQL::Migrator transaction" do
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
      %w[tx_migration_a tx_migration_b tx_migration_c tx_migration_d tx_migration_e cql_schema_migrations].each { |table| db.exec("DROP TABLE IF EXISTS #{table}") }
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
    with_migrator(uri, TxMigrationCreateA, TxMigrationCreateBThenFail, schema_class: NonTransactionalDdlSchema) do |migrator|
      expect_raises(Exception, "boom") { migrator.up }
    end

    committed_tables.call.should eq(["tx_migration_a", "tx_migration_b"])
    committed_versions.call.should eq([TxMigrationCreateA.version])
  end

  it "refuses to run inside a caller's transaction without transactional DDL" do
    with_migrator(uri, TxMigrationCreateA, schema_class: NonTransactionalDdlSchema) do |migrator|
      expect_raises(CQL::DialectError, "MySQL") { migrator.schema.transaction { migrator.up } }
    end

    committed_tables.call.should be_empty
    committed_versions.call.should be_empty
  end

  it "refuses to create the migrations table inside a caller's transaction without transactional DDL" do
    schema = tx_schema(uri, NonTransactionalDdlSchema)
    statements = [] of String
    CQL::Telemetry.subscribe("migration_tx_spec") { |event| statements << event.sql }

    begin
      expect_raises(CQL::DialectError, "MySQL") do
        schema.transaction { CQL::Migrator.new(schema, CQL::MigratorConfig.new(auto_sync: false)) }
      end
    ensure
      CQL::Telemetry.unsubscribe("migration_tx_spec")
      schema.close
    end

    statements.select(&.includes?("CREATE")).should be_empty
  end

  it "refuses to bootstrap the schema file inside a caller's transaction without transactional DDL" do
    schema = tx_schema(uri, NonTransactionalDdlSchema)
    schema_file = File.join(Dir.tempdir, "cql_migration_tx_schema_#{Process.pid}_#{Random::Secure.hex(4)}.cr")

    begin
      expect_raises(CQL::DialectError, "MySQL") do
        schema.transaction { CQL::Migrator.new(schema, CQL::MigratorConfig.new(schema_file_path: schema_file, auto_sync: true)) }
      end
      File.exists?(schema_file).should be_false
    ensure
      File.delete(schema_file) if File.exists?(schema_file)
      schema.close
    end
  end

  it "refuses to list pending migrations inside a caller's transaction without transactional DDL" do
    statements = [] of String
    with_migrator(uri, TxMigrationCreateA, schema_class: NonTransactionalDdlSchema) do |migrator|
      CQL::Telemetry.subscribe("migration_tx_spec") { |event| statements << event.sql }
      begin
        expect_raises(CQL::DialectError, "MySQL") { migrator.schema.transaction { migrator.pending_migrations } }
      ensure
        CQL::Telemetry.unsubscribe("migration_tx_spec")
      end

      migrator.pending_migrations.should eq([TxMigrationCreateA] of CQL::BaseMigration.class)
    end

    # `pending_migrations` creates the migrations table if it is missing, which MySQL would commit with the caller's work.
    statements.select(&.includes?("CREATE")).should be_empty
  end

  it "runs every migration and its record on the single pooled connection" do
    pool_of_one = "#{uri}?initial_pool_size=0&max_pool_size=1&checkout_timeout=0.05"

    with_migrator(pool_of_one, TxMigrationCreateA, TxMigrationCreateC) do |migrator|
      migrator.up

      migrator.applied_migrations.map(&.version).should eq([TxMigrationCreateA.version, TxMigrationCreateC.version])
    end

    committed_tables.call.should eq(["tx_migration_a", "tx_migration_c"])
  end

  it "creates the migrations table and runs migrations inside a caller's transaction on the single pooled connection" do
    pool_of_one = "#{uri}?initial_pool_size=0&max_pool_size=1&checkout_timeout=0.05"
    original = CQL::Migrator.migrations
    schema = tx_schema(pool_of_one)

    begin
      CQL::Migrator.migrations = [TxMigrationCreateA] of CQL::BaseMigration.class
      schema.transaction { CQL::Migrator.new(schema, CQL::MigratorConfig.new(auto_sync: false)).up }
    ensure
      CQL::Migrator.migrations = original
      schema.close
    end

    committed_tables.call.should eq(["tx_migration_a"])
  end

  it "rolls back reverted migrations and their records when a later revert fails" do
    with_migrator(uri, TxMigrationFailOnDown, TxMigrationDropDOnDown) do |migrator|
      migrator.up
      expect_raises(Exception, "boom") { migrator.down }
    end

    committed_tables.call.should eq(["tx_migration_d", "tx_migration_e"])
    committed_versions.call.should eq([TxMigrationFailOnDown.version, TxMigrationDropDOnDown.version])
  end

  it "keeps completed reverts when a later revert fails without transactional DDL" do
    with_migrator(uri, TxMigrationFailOnDown, TxMigrationDropDOnDown, schema_class: NonTransactionalDdlSchema) do |migrator|
      migrator.up
      expect_raises(Exception, "boom") { migrator.down }
    end

    committed_tables.call.should eq(["tx_migration_e"])
    committed_versions.call.should eq([TxMigrationFailOnDown.version])
  end

  it "refuses to revert inside a caller's transaction without transactional DDL" do
    statements = [] of String
    with_migrator(uri, TxMigrationDropDOnDown, schema_class: NonTransactionalDdlSchema) do |migrator|
      migrator.up
      CQL::Telemetry.subscribe("migration_tx_spec") { |event| statements << event.sql }
      begin
        expect_raises(CQL::DialectError, "MySQL") { migrator.schema.transaction { migrator.redo } }
      ensure
        CQL::Telemetry.unsubscribe("migration_tx_spec")
      end
    end

    # On SQLite the caller's rollback would undo a late DROP; MySQL would have committed it.
    statements.select(&.includes?("DROP")).should be_empty
    committed_tables.call.should eq(["tx_migration_d"])
    committed_versions.call.should eq([TxMigrationDropDOnDown.version])
  end

  it "refuses to roll back to a version inside a caller's transaction without transactional DDL" do
    statements = [] of String
    with_migrator(uri, TxMigrationCreateA, TxMigrationDropDOnDown, schema_class: NonTransactionalDdlSchema) do |migrator|
      migrator.up
      CQL::Telemetry.subscribe("migration_tx_spec") { |event| statements << event.sql }
      begin
        expect_raises(CQL::DialectError, "MySQL") { migrator.schema.transaction { migrator.down_to(TxMigrationCreateA.version) } }
      ensure
        CQL::Telemetry.unsubscribe("migration_tx_spec")
      end
    end

    statements.select(&.includes?("DROP")).should be_empty
    committed_tables.call.should eq(["tx_migration_a", "tx_migration_d"])
    committed_versions.call.should eq([TxMigrationCreateA.version, TxMigrationDropDOnDown.version])
  end

  it "reverts every migration and its record on the single pooled connection" do
    pool_of_one = "#{uri}?initial_pool_size=0&max_pool_size=1&checkout_timeout=0.05"

    with_migrator(pool_of_one, TxMigrationDropDOnDown) do |migrator|
      migrator.up
      migrator.down
    end

    committed_tables.call.should be_empty
    committed_versions.call.should be_empty
  end
end
