require "../../spec_helper"

# Schema for soft deletable tests
SoftDeletableDB = CQL::Schema.define(
  :soft_deletable_database,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://spec/support/db/soft_deletable_spec.db"
) do
  table :users do
    primary :id, Int32
    column :name, String, size: 255
    column :email, String, size: 255
    column :age, Int32, default: 0
    column :deleted_at, Time, null: true
    timestamp :created_at, null: true
    timestamp :updated_at, null: true
  end
end
