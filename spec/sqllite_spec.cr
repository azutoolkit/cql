require "./spec_helper"

struct CustomerModel
  include DB::Serializable

  property customer_id : Int64
  property name : String
  property city : String
  property balance : Int64

  def initialize(@customer_id : Int64, @name : String, @city : String, @balance : Int64)
  end
end

describe "Sqlite3" do
  it "creates a table" do
    Schema.customers.create!
    table = Schema.customers.table_name.to_s

    check_query = "SELECT name FROM sqlite_master WHERE type='table' AND name='#{table}'"
    name = Schema.query_one(check_query, as: String)

    name.should eq table
  end

  it "creates table" do
    customer = CustomerModel.new(1, "'John'", "'New York'", 100)

    insert_query = i.into(:customers).values(
      customer_id: customer.customer_id,
      name: customer.name,
      city: customer.city,
      balance: customer.balance
    ).exec
  end

  it "queries customers" do
    query = q.from(:customers)
    customers = CustomerModel.from_rs(query.fetch)
    customers.size.should eq 1
  end
end
