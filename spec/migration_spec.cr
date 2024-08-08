require "./spec_helper"

Schema.table :users do
  primary :id, Int32
  column :name, String
  column :email, String
  column :age, Int32
  timestamps
end

class CreateUsers < Cql::Migration
  self.version = 123456789_i64

  def up
    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end

class MigrationTwo < Cql::Migration
  self.version = 987654321_i64

  def up
    schema.alter :users do
      add_column :phone, String
    end
  end

  def down
    schema.alter :users do
      drop_column :phone
    end
  end
end

describe Cql::Migration do
  migrator = Cql::Migrator.new(Schema)

  after_all do
    File.delete("spec/db/data.db")
  end

  it "has a migration" do
    Cql::Migrator.migrations.size.should eq(2)
  end

  it "migrates up" do
    migrator.up

    migrator.last.try(&.version).should eq(MigrationTwo.version)
    migrator.applied_migrations.map(&.version).should eq([CreateUsers.version, MigrationTwo.version])
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
    migrator.applied_migrations.map(&.version).should eq([] of Cql::Migrator::MigrationRecord)
  end

  it "redo" do
    migrator.up

    migrator.last.try(&.version).should eq(MigrationTwo.version)
    migrator.applied_migrations.map(&.version).should eq([CreateUsers.version, MigrationTwo.version])

    migrator.redo

    migrator.last.try(&.version).should eq(MigrationTwo.version)
    migrator.applied_migrations.map(&.version).should eq([CreateUsers.version, MigrationTwo.version])
  end

  it "migrates down to a specific version" do
    migrator.down_to(CreateUsers.version)

    migrator.last.try(&.version).should eq(CreateUsers.version)
    migrator.applied_migrations.map(&.version).should eq([CreateUsers.version])
  end

  it "migrates up to a specific version" do
    migrator.up_to(MigrationTwo.version)

    migrator.last.try(&.version).should eq(MigrationTwo.version)
    migrator.applied_migrations.map(&.version).should eq([CreateUsers.version, MigrationTwo.version])
  end

  it "prints pending migrations" do
    migrator.down
    migrator.print_pending_migrations
    migrator.pending_migrations.should be_a(Array(Cql::Migrator::MigrationRecord))
  end
end
