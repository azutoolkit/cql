Data = Cql::Schema.build(
  :northwind,
  adapter: Cql::Adapter::Sqlite,
  db: DB.connect("sqlite3://spec/db/data.db"),
  version: "1.0") do
  table :customers, as: "cust" do
    primary :id, Int32
    column :customer_name, String, as: "cust_name"
    column :city, String
    column :country_id, Int32
  end

  table :countries do
    primary :country_id, Int32
    column :country, String
  end
end
