Billing = CQL::Schema.define(
  name: :billing,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://spec/db/billing.db") do
  table :users do
    primary :id, Int32
    column :name, String
    column :email, String
  end
end
