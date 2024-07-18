require "./spec_helper"

describe Sql::Table do
  before_all do
    Schema.customers.drop!
  end

  it "creates table" do
    Schema.customers.drop!
    Schema.customers.create!

    customer = CustomerModel.new(1, "'John'", "'New York'", 100)

    insert_query = i.into(:customers).values(
      customer_id: customer.customer_id,
      name: customer.name,
      city: customer.city,
      balance: customer.balance
    ).exec
  end

  it "truncates table" do
    Schema.customers.drop!
    Schema.customers.create!

    customers = [
      CustomerModel.new(1, "'John'", "'New York'", 100),
      CustomerModel.new(2, "'Jane'", "'New York'", 200),
    ]

    customers.each do |c|
      i.into(:customers).values(customer_id: c.customer_id, name: c.name, city: c.city, balance: c.balance).exec
    end

    count_sql = q.from(:customers).count.to_sql

    count = Schema.query_one(count_sql, as: Int32)
    count.should eq 2

    result = d.from(:customers).exec

    count = Schema.query_one(count_sql, as: Int32)
    count.should eq 0
  end

  it "drops table" do
    Schema.customers.drop!
    table = Schema.customers.table_name.to_s
    check_query = "SELECT name FROM sqlite_master WHERE type='table' AND name='#{table}'"

    expect_raises(DB::NoResultsError) do
      name = Schema.query_one(check_query, as: String)
    end
  end
end
