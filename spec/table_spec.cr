require "./spec_helper"

describe Sql::Table do
  before_all do
    Schema.customers.drop!
  end

  it "creates table" do
    Schema.customers.drop!
    Schema.customers.create!

    customer = CustomerModel.new(1, "John", "New York", 100)

    insert_query = i.into(:customers).values(
      id: customer.id,
      name: customer.name,
      city: customer.city,
      balance: customer.balance
    ).commit

    persisted = q.from(:customers).first!(as: CustomerModel)

    persisted.id.should eq customer.id
    persisted.name.should eq customer.name
    persisted.city.should eq customer.city
    persisted.balance.should eq customer.balance
  end

  it "truncates table" do
    Schema.customers.drop!
    Schema.customers.create!

    customers = [
      CustomerModel.new(1, "'John'", "'New York'", 100),
      CustomerModel.new(2, "'Jane'", "'New York'", 200),
    ]

    customers.each do |c|
      i.into(:customers).values(id: c.id, name: c.name, city: c.city, balance: c.balance).commit
    end

    count_query = q.from(:customers).count
    count_query.first!(as: Int32).should eq 2

    result = d.from(:customers).commit
    count_query.first!(as: Int32).should eq 0
  end

  it "drops table" do
    Schema.customers.drop!
    table = Schema.customers.table_name.to_s
    check_query = "SELECT name FROM sqlite_master WHERE type='table' AND name='#{table}'"

    expect_raises(DB::NoResultsError) do
      name = Schema.db.query_one(check_query, as: String)
    end
  end
end
