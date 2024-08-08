Billing = Cql::Schema.build(
  name: :northwind,
  adapter: Cql::Adapter::Sqlite,
  db: DB.connect("sqlite3://spec/db/billing.db")) do
  table :users do
    primary :id, Int32
    column :name, String
    column :email, String
  end
end
