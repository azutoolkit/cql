require "pg"

Example = Cql::Schema.build(
  :example,
  adapter: Cql::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]) do
  table :customers, as: "cust" do
    primary :customer_id, Int64, auto_increment: true
    column :customer_name, String, as: "cust_name"
    column :city, String
    column :country_id, Int64
  end

  table :countries do
    primary :country_id, Int64, auto_increment: true
    column :country, String
  end
end
