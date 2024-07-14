require "./spec_helper"

describe Sql::Schema do
  it "creates a schema" do
    schema = Sql::Schema.new(:northwind)

    schema.table :customers, as: "cust" do
      primary_key :customer_id, Int64, auto_increment: true
      column :customer_name, String, as: "cust_name"
      column :city, String
    end

    schema.tables.size.should eq(1)
    schema.tables.first.name.should eq(:customers)
    schema.tables.first.as_name.should eq("cust")
    schema.tables.first.columns.size.should eq(3)
    schema.tables.first.columns.first.name.should eq(:customer_id)
    schema.tables.first.columns.first.type.should eq(Int64)
    schema.tables.first.columns.first.null.should eq(false)
    schema.tables.first.columns.first.default.should eq(nil)
    schema.tables.first.columns.first.unique.should eq(true)
    schema.tables.first.columns.first.as(Sql::PrimaryKey).auto_increment.should eq(true)
    schema.tables.first.columns[1].name.should eq(:customer_name)
    schema.tables.first.columns[1].type.should eq(String)
    schema.tables.first.columns[1].null.should eq(false)
    schema.tables.first.columns[1].default.should eq(nil)
    schema.tables.first.columns[1].unique.should eq(false)
    schema.tables.first.columns[2].name.should eq(:city)
    schema.tables.first.columns[2].type.should eq(String)
    schema.tables.first.columns[2].null.should eq(false)
    schema.tables.first.columns[2].default.should eq(nil)
    schema.tables.first.columns[2].unique.should eq(false)
  end
end
