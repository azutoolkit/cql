Data = CQL::Schema.define(
  :data,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://spec/support/db/data.db") do
  table :customers do
    primary :id, Int32
    varchar :name
    varchar :email
    varchar :city
    integer :balance
    timestamps
  end

  table :countries do
    primary :id, Int32
    varchar :country
  end
end
