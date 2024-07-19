require "./spec_helper"

describe Sql::Schema do
  it "creates a schema" do
    schema = Sql::Schema.new(:northwind, adapter: Sql::Adapter::Sqlite, db: DB.connect("sqlite3://spec/data.db"), version: "1.0")

    schema.table :customers, as: "cust" do
      primary_key :customer_id, Int64, auto_increment: true
      column :customer_name, String, as: "cust_name"
      column :city, String
    end

    schema.tables.size.should eq(1)
    schema.tables[:customers].columns.size.should eq(3)
  end
end
