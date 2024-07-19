require "./spec_helper"

describe Sql::Schema do
  schema = Sql::Schema.new(
    :northwind,
    adapter: Sql::Adapter::Sqlite,
    db: DB.connect("sqlite3://spec/data.db"),
    version: "1.0")

  column_exists = ->(col : Symbol, table : Symbol) do
    begin
      query = "SELECT 1 FROM pragma_table_info('#{table}') WHERE name = '#{col}';\n"
      result = Schema.query_one(query, as: Int32)
      result
    rescue exception
      0
    end
  end

  schema.table :customers, as: "cust" do
    primary_key :customer_id, Int64, auto_increment: true
    column :customer_name, String, as: "cust_name"
    column :city, String
  end

  before_each do
  end

  it "creates a schema" do
    schema.tables.size.should eq(1)
    schema.tables[:customers].columns.size.should eq(3)
  end

  it "add a column to an existing table" do
    schema.customers.drop!
    schema.customers.create!

    schema.alter :customers do
      add_column :country, String
    end

    column_exists.call(:country, :customers).should eq(1)
    schema.tables[:customers].columns.size.should eq(4)
  end

  it "drops a column from an existing table" do
    schema.customers.drop!
    schema.customers.create!

    column_exists.call(:city, :customers).should eq(1)

    schema.alter :customers do
      drop_column :city
    end

    column_exists.call(:city, :customers).should eq(0)
    schema.tables[:customers].columns.size.should eq(3)
  end
end
