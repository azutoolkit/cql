require "pg"

Example = Cql::Schema.build(
  :northwind,
  adapter: Cql::Adapter::Postgres,
  db: DB.connect("postgresql://example:example@localhost:5432/example"), version: "1.0") do
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
