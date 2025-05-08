require "pg"

Example = CQL::Schema.define(
  :example,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]) do
  table :customers, as: "cust" do
    primary :customer_id, Int64, auto_increment: true
    column :customer_name, String, as: "cust_name"
    column :city, String
    column :country_id, Int64
  end

  table :countries do
    primary :id, Int64, auto_increment: true
    column :country, String
  end
end
