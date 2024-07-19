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

  index_exists = ->(index : Symbol, table : Symbol) do
    begin
      query = <<-SQL
      SELECT 1 FROM SQLite_master  WHERE type = 'index' AND tbl_name = '#{table}' AND name = '#{index}';
      SQL
      result = Schema.query_one(query, as: Int32)
      result
    rescue exception
      puts exception
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

  it "adds an index to a table" do
    schema.customers.drop!
    schema.customers.create!

    schema.alter :customers do
      create_index :name_index, [:customer_name], true
    end

    index_exists.call(:name_index, :customers).should eq(1)
  end

  it "drops an index from a table" do
    schema.customers.drop!
    schema.customers.create!

    schema.alter :customers do
      create_index :name_index, [:customer_name], true
    end

    index_exists.call(:name_index, :customers).should eq(1)

    schema.alter :customers do
      drop_index :name_index
    end

    index_exists.call(:name_index, :customers).should eq(0)
  end
end
