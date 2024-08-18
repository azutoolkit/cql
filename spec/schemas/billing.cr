Billing = Cql::Schema.define(
  name: :billing,
  adapter: Cql::Adapter::Sqlite,
  uri: "sqlite3://spec/db/billing.db") do
  table :users do
    primary :id, Int32
    column :name, String
    column :email, String
  end
end
