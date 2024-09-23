require "./spec_helper"
require "./migrations/*"

describe CQL::Migration do
  migrator = Northwind.migrator

  after_all do
    File.delete("spec/db/northwind.db")
  end

  it "has a migration" do
    CQL::Migrator.migrations.size.should eq(2)
  end

  it "migrates up" do
    migrator.up

    migrator.last.try(&.version).should eq(AlterUsersMigration.version)
    migrator.applied_migrations.map(&.version).should eq([CreateUsersMigration.version, AlterUsersMigration.version])
  end

  it "migrates down" do
    migrator.down

    migrator.last.should eq(nil)
    migrator.applied_migrations.size.should eq(0)
    migrator.applied_migrations.map(&.version).should eq([] of Int64)
  end

  it "rolls back" do
    migrator.rollback

    migrator.last.try(&.version).should eq(nil)
    migrator.applied_migrations.map(&.version).should eq([] of CQL::Migrator::MigrationRecord)
  end

  it "redo" do
    migrator.up

    migrator.last.try(&.version).should eq(AlterUsersMigration.version)
    migrator.applied_migrations.map(&.version).should eq([CreateUsersMigration.version, AlterUsersMigration.version])

    migrator.redo

    migrator.last.try(&.version).should eq(AlterUsersMigration.version)
    migrator.applied_migrations.map(&.version).should eq([CreateUsersMigration.version, AlterUsersMigration.version])
  end

  it "migrates down to a specific version" do
    migrator.down_to(CreateUsersMigration.version)

    migrator.last.try(&.version).should eq(CreateUsersMigration.version)
    migrator.applied_migrations.map(&.version).should eq([CreateUsersMigration.version])
  end

  it "migrates up to a specific version" do
    migrator.up_to(AlterUsersMigration.version)

    migrator.last.try(&.version).should eq(AlterUsersMigration.version)
    migrator.applied_migrations.map(&.version).should eq([CreateUsersMigration.version, AlterUsersMigration.version])
  end

  it "prints pending migrations" do
    migrator.down
    migrator.print_pending_migrations
    migrator.pending_migrations.should be_a(Array(CQL::BaseMigration.class))
  end
end
