require "sqlite3"
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
  it "queries customers" do
    # Schema.create_table(:customers)

    # customer = CustomerModel.new(1, "'John'", "'New York'", 100)

    # insert_query = i.into(:customers).values(
    #   customer_id: customer.customer_id,
    #   name: customer.name,
    #   city: customer.city,
    #   balance: customer.balance
    # ).exec

    # puts insert_query

    query = q.from(:customers)
    customers = CustomerModel.from_rs(query.fetch)
    customers.size.should eq 1
  end
end
