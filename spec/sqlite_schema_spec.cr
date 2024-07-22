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
      0
    end
  end

  schema.table :customers, as: "cust" do
    primary_key :customer_id, Int64, auto_increment: true
    column :customer_name, String, as: "cust_name"
    column :city, String
    column :country_id, Int64
  end

  schema.table :countries do
    primary_key :country_id, Int64, auto_increment: true
    column :country, String
  end

  it "creates a schema" do
    schema.tables.size.should eq(2)
    schema.tables[:customers].columns.size.should eq(4)
  end

  it "add a column to an existing table" do
    schema.customers.drop!
    schema.customers.create!

    schema.alter :customers do
      add_column :country, String
    end

    column_exists.call(:country, :customers).should eq(1)
    schema.tables[:customers].columns.size.should eq(5)
  end

  it "drops a column from an existing table" do
    schema.customers.drop!
    schema.customers.create!

    column_exists.call(:city, :customers).should eq(1)

    schema.alter :customers do
      drop_column :city
    end

    column_exists.call(:city, :customers).should eq(0)
    schema.tables[:customers].columns.size.should eq(4)
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

  it "renames a column in a table" do
    schema.customers.drop!
    schema.customers.create!

    column_exists.call(:customer_name, :customers).should eq(1)

    schema.alter :customers do
      rename_column :customer_name, :full_name
    end

    column_exists.call(:customer_name, :customers).should eq(0)
    column_exists.call(:full_name, :customers).should eq(1)
  end

  it "changes a column in a table" do
    schema.customers.drop!
    schema.customers.create!

    column_exists.call(:full_name, :customers).should eq(1)

    expect_raises DB::Error do
      schema.alter :customers do
        change_column :full_name, Int32
      end
    end
  end

  it "renames a table" do
    schema.customers.drop!
    schema.customers.create!

    schema.alter :customers do
      rename_table :clients
    end

    schema.tables[:customers]?.should be_nil
    schema.tables[:clients]?.should_not be_nil

    schema.clients.drop!
  end

  it "adds a foreign key to a table" do
    schema.countries.create!

    schema.table :customers, as: "cust" do
      primary_key :customer_id, Int64, auto_increment: true
      column :customer_name, String, as: "cust_name"
      column :city, String
      column :country_id, Int64
    end

    schema.customers.create!

    expect_raises DB::Error do
      schema.alter :customers do
        foreign_key :fk_country, [:country], :countries, [:country_id]
      end
    end
  end

  it "drops a foreign key from a table" do
    schema.countries.create!

    schema.table :customers, as: "cust" do
      primary_key :customer_id, Int64, auto_increment: true
      column :customer_name, String, as: "cust_name"
      column :city, String
      column :country_id, Int64
    end

    schema.customers.create!

    schema.alter :customers do
      foreign_key :fk_country, [:country_id], :countries, [:country_id]
    end

    schema.alter :customers do
      drop_foreign_key :fk_country
    end
  end
end