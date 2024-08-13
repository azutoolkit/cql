require "../spec_helper"

describe Cql::Schema do
  column_exists = ->(col : Symbol, table : Symbol) do
    begin
      query = "SELECT 1 FROM pragma_table_info('#{table}') WHERE name = '#{col}';\n"
      result = Data.db.query_one(query, as: Int32)
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
      result = Data.db.query_one(query, as: Int32)
      result
    rescue exception
      0
    end
  end

  before_each do
    sleep 1.seconds
  end

  it "creates a table" do
    Data.customers.drop!
    Data.customers.create!

    table = Data.customers.table_name.to_s
    check_query = "SELECT name FROM sqlite_master WHERE type='table' AND name='#{table}'"
    name = Data.db.query_one(check_query, as: String)

    name.should eq table
  end

  it "creates record in table" do
    Data.customers.drop!
    Data.customers.create!

    customer = CustomerModel.new(nil, "John", "New York", 100)

    Data.insert
      .into(:customers)
      .values(
        name: customer.name,
        city: customer.city,
        balance: customer.balance
      ).commit

    total = Data.query.from(:customers).count(:id).first!(as: Int32)
    total.should eq 1
  end

  it "queries customers" do
    Data.customers.drop!
    Data.customers.create!

    customer = CustomerModel.new(nil, "John", "New York", 100)

    Data.insert
      .into(:customers)
      .values(
        name: customer.name,
        city: customer.city,
        balance: customer.balance
      ).commit

    customers = Data.query.from(:customers).select.all!(CustomerModel)
    customers.size.should eq 1
  end

  it "creates a schema" do
    Data.tables.size.should eq(2)
    Data.tables[:customers].columns.size.should eq(6)
  end

  it "add a column to an existing table" do
    Data.customers.drop!
    Data.customers.create!

    Data.alter :customers do
      add_column :country, String
    end

    column_exists.call(:country, :customers).should eq(1)
    Data.tables[:customers].columns.size.should eq(7)
  end

  it "drops a column from an existing table" do
    Data.customers.drop!
    Data.customers.create!

    column_exists.call(:city, :customers).should eq(1)

    Data.alter :customers do
      drop_column :city
    end

    column_exists.call(:city, :customers).should eq(0)
    Data.tables[:customers].columns.size.should eq(6)
  end

  it "adds an index to a table" do
    Data.customers.drop!
    Data.customers.create!

    Data.alter :customers do
      create_index :name_index, [:name], true
    end

    index_exists.call(:name_index, :customers).should eq(1)
  end

  it "drops an index from a table" do
    Data.customers.drop!
    Data.customers.create!

    Data.alter :customers do
      create_index :name_index, [:name], true
    end

    index_exists.call(:name_index, :customers).should eq(1)

    Data.alter :customers do
      drop_index :name_index
    end

    index_exists.call(:name_index, :customers).should eq(0)
  end

  it "renames a column in a table" do
    Data.customers.drop!
    Data.customers.create!

    column_exists.call(:name, :customers).should eq(1)

    Data.alter :customers do
      rename_column :name, :full_name
    end

    column_exists.call(:name, :customers).should eq(0)
    column_exists.call(:full_name, :customers).should eq(1)
  end

  it "changes a column in a table" do
    Data.customers.drop!
    Data.customers.create!

    column_exists.call(:full_name, :customers).should eq(1)

    expect_raises DB::Error do
      Data.alter :customers do
        change_column :full_name, Int32
      end
    end
  end

  it "renames a table" do
    Data.customers.drop!
    Data.customers.create!

    Data.alter :customers do
      rename_table :clients
    end

    Data.tables[:customers]?.should be_nil
    Data.tables[:clients]?.should_not be_nil

    Data.clients.drop!
  end

  it "throws exception adding foreign key to a table" do
    Data.countries.drop!
    Data.countries.create!

    expect_raises DB::Error do
      Data.alter :clients do
        foreign_key :fk_country, [:country_id], :countries, [:id]
      end
    end
  end

  it "raises when droping a foreign key from a table" do
    Data.countries.create!

    expect_raises SQLite3::Exception do
      Data.alter :clients do
        drop_foreign_key :fk_country
      end
    end
  end
end
