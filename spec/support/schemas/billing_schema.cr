Billing = CQL::Schema.define(
  name: :billing,
  adapter: CQL::Adapter::SQLite,
  uri: spec_sqlite_uri("billing.db")) do
  table :users do
    primary :id, Int32
    column :name, String
    column :email, String
  end
end
