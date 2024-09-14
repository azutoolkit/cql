require "pg"
require "../spec_helper"

struct UserPref
  include DB::Serializable

  property id : Int64
  getter preferences do |value|
    JSON.parse(value)
  end
end

describe Cql::Schema do
  context "handles json fields" do
    Example.table :user_pref do
      primary
      json :preferences
    end

    Example.user_pref.create!

    # it "inserts a record with a json field" do
    #   insert_json_query, arguments = Example.insert.into(:user_pref).values(id: 1, preferences: %({"theme": "dark"})).to_sql
    #   puts insert_json_query, arguments
    # end

    it "fetches user preferences" do
      Example
        .insert
        .into(:user_pref)
        .values(preferences: %({"theme": "dark"}))
        .commit
      result = Example.query.from(:user_pref).limit(1).first!(UserPref)
      result.preferences.should be_a(JSON::Any)
    end
  end

  column_exists = ->(col : Symbol, table : Symbol) do
    begin
      query = <<-SQL
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'  AND table_name = '#{table}'  AND column_name = '#{col}';
      SQL
      Example.db.query_one(query, as: Int32)
    rescue exception
      Log.debug { exception }
      0
    end
  end

  index_exists = ->(index : Symbol, table : Symbol) do
    begin
      query = <<-SQL
      SELECT 1 FROM pg_indexes WHERE tablename = '#{table}' AND indexname = '#{index}';
      SQL
      Example.db.query_one(query, as: Int32)
    rescue exception
      0
    end
  end

  it "creates a schema" do
    Example.tables.size.should eq(3)
    Example.tables[:customers].columns.size.should eq(4)
  end

  it "add a column to an existing table" do
    Example.customers.drop!
    Example.customers.create!

    Example.alter :customers do
      add_column :country, String, size: 50
    end

    sleep 1

    column_exists.call(:country, :customers).should eq(1)
    Example.tables[:customers].columns.size.should eq(5)
  end

  it "drops a column from an existing table" do
    Example.customers.drop!
    Example.customers.create!

    column_exists.call(:city, :customers).should eq(1)

    Example.alter :customers do
      drop_column :city
    end

    column_exists.call(:city, :customers).should eq(0)
    Example.tables[:customers].columns.size.should eq(4)
  end

  it "adds an index to a table" do
    Example.customers.drop!
    Example.customers.create!

    Example.alter :customers do
      create_index :name_index, [:customer_name], true
    end

    index_exists.call(:name_index, :customers).should eq(1)
  end

  it "drops an index from a table" do
    Example.customers.drop!
    Example.customers.create!

    Example.alter :customers do
      create_index :name_index, [:customer_name], true
    end

    index_exists.call(:name_index, :customers).should eq(1)

    Example.alter :customers do
      drop_index :name_index
    end

    index_exists.call(:name_index, :customers).should eq(0)
  end

  it "renames a column in a table" do
    Example.customers.drop!
    Example.customers.create!

    column_exists.call(:customer_name, :customers).should eq(1)

    Example.alter :customers do
      rename_column :customer_name, :full_name
    end

    column_exists.call(:customer_name, :customers).should eq(0)
    column_exists.call(:full_name, :customers).should eq(1)
  end

  it "changes a column in a table" do
    Example.customers.drop!
    Example.customers.create!

    column_exists.call(:full_name, :customers).should eq(1)

    Example.alter :customers do
      change_column :full_name, String
    end
  end

  it "renames a table" do
    Example.customers.drop!
    Example.customers.create!

    Example.alter :customers do
      rename_table :clients
    end

    Example.tables[:customers]?.should be_nil
    Example.tables[:clients]?.should_not be_nil

    Example.clients.drop!
  end

  it "adds a foreign key to a table" do
    Example.countries.create!

    Example.table :customers, as: "cust" do
      primary :id, Int64, auto_increment: true
      column :customer_name, String, as: "cust_name"
      column :city, String
      column :country_id, Int64
    end

    Example.customers.create!

    Example.alter :customers do
      foreign_key :fk_country, [:country_id], :countries, [:id]
    end
  end

  it "drops a foreign key from a table" do
    Example.customers.drop!
    Example.countries.create!

    Example.table :customers, as: "cust" do
      primary :id, Int64, auto_increment: true
      column :customer_name, String, as: "cust_name"
      column :city, String
      column :country_id, Int64
    end

    Example.customers.create!

    Example.alter :customers do
      foreign_key :fk_country, [:country_id], :countries, [:id]
    end

    Example.alter :customers do
      drop_foreign_key :fk_country
    end
  end
end
