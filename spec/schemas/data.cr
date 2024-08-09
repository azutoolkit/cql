Data = Cql::Schema.build(
  :data,
  adapter: Cql::Adapter::Sqlite,
  uri: "sqlite3://spec/db/data.db") do
  table :customers do
    primary :id, Int32
    column :name, String
    column :city, String
    column :balance, Int32
    timestamps
  end

  table :countries do
    primary :id, Int32
    column :country, String
  end
end
