require "pg"

EXAMPLE_ADAPTER = postgres_available? ? CQL::Adapter::Postgres : CQL::Adapter::SQLite
EXAMPLE_URI     = postgres_available? ? postgres_database_url : "sqlite3:///tmp/cql_postgres_example_fallback.db"

Example = CQL::Schema.define(
  :example,
  adapter: EXAMPLE_ADAPTER,
  uri: EXAMPLE_URI) do
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
