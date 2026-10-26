require "../spec_helper"

# Not `CQL::Migration(V)` subclasses: those register themselves in the global `CQL::Migrator.migrations`.
abstract class StepMigration < CQL::BaseMigration
  # Versions in the order `down` ran.
  class_getter reverted = [] of Int64

  getter schema : CQL::Schema

  def initialize(@schema : CQL::Schema); end

  def up
    schema.exec("CREATE TABLE step_migration_#{self.class.version} (id INTEGER)")
  end

  def down
    schema.exec("DROP TABLE step_migration_#{self.class.version}")
    StepMigration.reverted << self.class.version
  end
end

{% for version in 1..5 %}
  class StepMigration{{version}} < StepMigration
    def self.version : Int64
      {{version}}_i64
    end
  end
{% end %}

private STEP_MIGRATIONS = [StepMigration1, StepMigration2, StepMigration3, StepMigration4, StepMigration5] of CQL::BaseMigration.class

private def with_step_migrator(migrations = STEP_MIGRATIONS, &)
  original = CQL::Migrator.migrations
  db_file = File.join(Dir.tempdir, "cql_migrator_steps_#{Process.pid}_#{Random::Secure.hex(4)}.db")
  schema = CQL::Schema.new(:migrator_steps, "sqlite3://#{db_file}", CQL::Adapter::SQLite)
  begin
    StepMigration.reverted.clear
    CQL::Migrator.migrations = migrations
    yield CQL::Migrator.new(schema, CQL::MigratorConfig.new(auto_sync: false))
  ensure
    CQL::Migrator.migrations = original
    schema.close
    File.delete(db_file) if File.exists?(db_file)
  end
end

private def applied_versions(migrator : CQL::Migrator) : Array(Int64)
  migrator.applied_migrations.map(&.version).sort!
end

describe "CQL::Migrator steps" do
  describe "#rollback" do
    it "rolls back the newest applied migration while a newer one is pending" do
      with_step_migrator do |migrator|
        migrator.up_to(4_i64)
        migrator.rollback

        applied_versions(migrator).should eq([1_i64, 2_i64, 3_i64])
      end
    end

    it "rolls back one more migration on each call" do
      with_step_migrator do |migrator|
        migrator.up
        migrator.rollback
        migrator.rollback

        applied_versions(migrator).should eq([1_i64, 2_i64, 3_i64])
      end
    end

    it "counts only applied migrations towards its steps" do
      with_step_migrator do |migrator|
        migrator.up_to(4_i64)
        migrator.rollback(2)

        applied_versions(migrator).should eq([1_i64, 2_i64])
      end
    end
  end

  describe "#down" do
    it "rolls back every applied migration without an argument" do
      with_step_migrator do |migrator|
        migrator.up_to(3_i64)
        migrator.down

        applied_versions(migrator).should be_empty
      end
    end
  end

  describe "#down_to" do
    it "rolls back the migrations newer than the version, newest first, and keeps the version applied" do
      with_step_migrator do |migrator|
        migrator.up_to(4_i64)
        migrator.down_to(1_i64)

        StepMigration.reverted.should eq([4_i64, 3_i64, 2_i64])
        applied_versions(migrator).should eq([1_i64])
      end
    end

    it "rolls back nothing when the version is the newest applied" do
      with_step_migrator do |migrator|
        migrator.up_to(4_i64)
        migrator.down_to(4_i64)

        applied_versions(migrator).should eq([1_i64, 2_i64, 3_i64, 4_i64])
      end
    end

    it "raises for a version no migration has" do
      with_step_migrator do |migrator|
        migrator.up

        expect_raises(CQL::Migrator::Error, "No migration with version 99") { migrator.down_to(99_i64) }
        applied_versions(migrator).should eq([1_i64, 2_i64, 3_i64, 4_i64, 5_i64])
      end
    end
  end

  describe "#up" do
    it "applies the next pending migrations, skipping applied ones" do
      with_step_migrator do |migrator|
        migrator.up(1)
        migrator.up(1)

        applied_versions(migrator).should eq([1_i64, 2_i64])
      end
    end
  end

  describe "with an older migration pending behind a newer applied one" do
    it "applies the oldest pending migration with up(1)" do
      with_step_migrator([StepMigration3] of CQL::BaseMigration.class) do |migrator|
        migrator.up
        CQL::Migrator.migrations = STEP_MIGRATIONS
        migrator.up(1)

        applied_versions(migrator).should eq([1_i64, 3_i64])
      end
    end

    it "applies only the pending migrations up to the version with up_to" do
      with_step_migrator([StepMigration3] of CQL::BaseMigration.class) do |migrator|
        migrator.up
        CQL::Migrator.migrations = STEP_MIGRATIONS
        migrator.up_to(2_i64)

        applied_versions(migrator).should eq([1_i64, 2_i64, 3_i64])
      end
    end
  end

  describe "#up_to" do
    it "applies the pending migrations up to and including the version" do
      with_step_migrator do |migrator|
        migrator.up(1)
        migrator.up_to(3_i64)

        applied_versions(migrator).should eq([1_i64, 2_i64, 3_i64])
      end
    end

    it "raises for a version no migration has" do
      with_step_migrator do |migrator|
        expect_raises(CQL::Migrator::Error, "No migration with version 99") { migrator.up_to(99_i64) }
        applied_versions(migrator).should be_empty
      end
    end
  end
end
