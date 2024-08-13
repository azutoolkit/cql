require "./spec_helper"

describe Cql::Table do
  it "creates table" do
    Northwind.customers.drop!
    Northwind.customers.create!

    customer = CustomerModel.new(1, "John", "New York", 100)

    insert_query = Northwind.insert.into(:customers).values(
      id: customer.id,
      name: customer.name,
      city: customer.city,
      balance: customer.balance
    ).commit

    persisted = Northwind.query.from(:customers).first!(as: CustomerModel)

    persisted.id.should eq customer.id
    persisted.name.should eq customer.name
    persisted.city.should eq customer.city
    persisted.balance.should eq customer.balance
  end

  it "truncates table" do
    Northwind.customers.drop!
    Northwind.customers.create!

    customers = [
      {:name => "John", :city => "New York", :balance => 100},
      {:name => "Jane", :city => "New York", :balance => 200},
    ]

    Northwind
      .insert
      .into(:customers)
      .values(customers)
      .commit

    count_query = Northwind.query.from(:customers).count
    count_query.first!(as: Int32).should eq 2

    result = Northwind.delete.from(:customers).commit
    count_query.first!(as: Int32).should eq 0
  end

  it "drops table" do
    Northwind.customers.drop!
    table = Northwind.customers.table_name.to_s
    check_query = "SELECT name FROM sqlite_master WHERE type='table' AND name='#{table}'"

    expect_raises(DB::NoResultsError) do
      name = Northwind.db.query_one(check_query, as: String)
    end
  end
end
