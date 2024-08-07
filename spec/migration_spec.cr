require "./spec_helper"

Schema.table :users do
  primary
  column :name, String
  column :email, String
  column :age, Int32
  timestamps
end

class CreateUsers < Cql::Migration
  def up
    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end

describe Cql::Migration do
  migrator = Cql::Migrator.new(Schema)

  it "has a migration" do
    puts Cql::Migrator.migrations.first.version
    Cql::Migrator.migrations.size.should eq(1)
  end

  it "migrates up" do
    migrator.migrate_up

    migrator.applied_migrations.first.version.should eq(1)
    migrator.applied_migrations.size.should eq(1)
  end
end
