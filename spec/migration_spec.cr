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

  it "has a migration" do
    Cql::Migrator.migrations.size.should eq(2)
  end

  it "migrates up" do
    migrator.up

    migrator.last.not_nil!.version.should eq(MigrationTwo.version)
    migrator.applied_migrations.map(&.version).should eq([CreateUsers.version, MigrationTwo.version])
  end

  it "migrates down" do
    migrator.down

    migrator.last.should eq(nil)
    migrator.applied_migrations.size.should eq(0)
    migrator.applied_migrations.map(&.version).should eq([] of Int64)
  end

  it "redo" do
    migrator.down
    migrator.up
    migrator.redo

    # migrator.up
    # migrator.applied_migrations.size.should eq(2)
    # migrator.last.not_nil!.version.should eq(MigrationTwo.version)
    # migrator.redo

    # migrator.last.not_nil!.version.should eq(MigrationTwo.version)
    # migrator.applied_migrations.map(&.version).should eq([CreateUsers.version, MigrationTwo.version])
    # migrator.applied_migrations.size.should eq(2)
  end
end
