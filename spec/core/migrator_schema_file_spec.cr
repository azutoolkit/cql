require "../spec_helper"

# Not a `CQL::Migration(V)` subclass: those register themselves in the global `CQL::Migrator.migrations`.
class SchemaFileMigration < CQL::BaseMigration
  def self.version : Int64
    1_i64
  end

  def up
    schema.exec("CREATE TABLE schema_file_widgets (id INTEGER PRIMARY KEY)")
  end

  def down
    schema.exec("DROP TABLE schema_file_widgets")
  end
end

private def with_schema_file_migrator(schema_file : String, &)
  original = CQL::Migrator.migrations
  db_file = File.join(Dir.tempdir, "cql_migrator_schema_file_#{Process.pid}_#{Random::Secure.hex(4)}.db")
  schema = CQL::Schema.new(:migrator_schema_file, "sqlite3://#{db_file}", CQL::Adapter::SQLite)
  begin
    CQL::Migrator.migrations = [SchemaFileMigration] of CQL::BaseMigration.class
    yield CQL::Migrator.new(schema, CQL::MigratorConfig.new(schema_file_path: schema_file, auto_sync: true))
  ensure
    CQL::Migrator.migrations = original
    schema.close
    [db_file, schema_file].each { |path| File.delete(path) if File.exists?(path) }
  end
end

private def temp_schema_file : String
  File.join(Dir.tempdir, "cql_migrator_schema_file_#{Process.pid}_#{Random::Secure.hex(4)}.cr")
end

describe "CQL::Migrator schema file" do
  it "is not written when the migrator is created" do
    schema_file = temp_schema_file

    with_schema_file_migrator(schema_file) do
      File.exists?(schema_file).should be_false
    end
  end

  it "stays stale after the migrator is created, so verify_schema_consistency reports it" do
    schema_file = temp_schema_file
    File.write(schema_file, "# stale\n")

    with_schema_file_migrator(schema_file) do |migrator|
      File.read(schema_file).should eq("# stale\n")
      migrator.verify_schema_consistency.should be_false
    end
  end

  it "is written after up, with the migrated tables and the migrations table" do
    schema_file = temp_schema_file

    with_schema_file_migrator(schema_file) do |migrator|
      migrator.up

      File.read(schema_file).should contain("table :schema_file_widgets do")
      File.read(schema_file).should contain("table :cql_schema_migrations do")
      migrator.verify_schema_consistency.should be_true
    end
  end
end

describe "CQL::Migrator schema file on a pool of one connection" do
  it "is written after up" do
    original = CQL::Migrator.migrations
    db_file = File.join(Dir.tempdir, "cql_migrator_pool_of_one_#{Process.pid}_#{Random::Secure.hex(4)}.db")
    schema_file = temp_schema_file
    schema = CQL::Schema.new(:migrator_pool_of_one, "sqlite3://#{db_file}?initial_pool_size=0&max_pool_size=1&checkout_timeout=0.05", CQL::Adapter::SQLite)
    begin
      CQL::Migrator.migrations = [SchemaFileMigration] of CQL::BaseMigration.class
      CQL::Migrator.new(schema, CQL::MigratorConfig.new(schema_file_path: schema_file, auto_sync: true)).up

      File.read(schema_file).should contain("table :schema_file_widgets do")
    ensure
      CQL::Migrator.migrations = original
      schema.close
      [db_file, schema_file].each { |path| File.delete(path) if File.exists?(path) }
    end
  end
end

describe "CQL::Migrator#update_schema_file" do
  it "closes the connections its dump opens" do
    pending!("needs /proc/self/fd") unless FileHandles.supported?

    schema_file = temp_schema_file
    with_schema_file_migrator(schema_file) do |migrator|
      db_file = migrator.schema.uri.lchop("sqlite3://")
      migrator.update_schema_file
      before = FileHandles.count(db_file)

      3.times { migrator.update_schema_file }

      FileHandles.count(db_file).should eq(before)
    end
  end
end
