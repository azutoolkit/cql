require "../spec_helper"

{% for suffix in %w[A B] %}
  class DuplicateVersion{{suffix.id}} < CQL::Migration(20990101000001)
    def up
      schema.exec("CREATE TABLE duplicate_version_{{suffix.downcase.id}} (id INTEGER)")
    end

    def down; end
  end
{% end %}

# `CQL::Migration(V)` registers globally: keep the duplicates out of every other spec's registry.
CQL::Migrator.migrations.reject!(&.in?(DuplicateVersionA, DuplicateVersionB))

private def with_duplicate_versions(&)
  original = CQL::Migrator.migrations
  db_file = File.tempname("cql_duplicate_version", ".db")
  schema = CQL::Schema.new(:duplicate_version, "sqlite3://#{db_file}", CQL::Adapter::SQLite)
  begin
    CQL::Migrator.migrations = [DuplicateVersionA, DuplicateVersionB] of CQL::BaseMigration.class
    yield schema, CQL::MigratorConfig.new(auto_sync: false)
  ensure
    CQL::Migrator.migrations = original
    schema.close
    File.delete(db_file) if File.exists?(db_file)
  end
end

describe "CQL::Migrator with two migrations sharing a version" do
  it "raises naming both classes and the version" do
    with_duplicate_versions do |schema, config|
      error = expect_raises(CQL::Migrator::Error) { CQL::Migrator.new(schema, config) }
      {DuplicateVersionA.name, DuplicateVersionB.name, "20990101000001"}.each { |part| error.message.to_s.should contain(part) }
    end
  end

  it "raises when a duplicate joins the registry after the migrator was built" do
    with_duplicate_versions do |schema, config|
      CQL::Migrator.migrations = [DuplicateVersionA] of CQL::BaseMigration.class
      migrator = CQL::Migrator.new(schema, config)
      CQL::Migrator.migrations << DuplicateVersionB
      expect_raises(CQL::Migrator::Error) { migrator.up }
    end
  end

  it "applies and records neither migration" do
    with_duplicate_versions do |schema, config|
      expect_raises(CQL::Migrator::Error) { CQL::Migrator.new(schema, config) }
      tables = schema.exec_query(&.query_all("SELECT name FROM sqlite_master WHERE type = 'table'", as: String))
      (tables & %w[duplicate_version_a duplicate_version_b cql_schema_migrations]).should be_empty
      CQL::Migrator.migrations = [] of CQL::BaseMigration.class # a migrator that can read the records
      CQL::Migrator.new(schema, config).applied_migrations.map(&.version).should_not contain(20990101000001_i64)
    end
  end
end
