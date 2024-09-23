require "./spec_helper"

describe CQL::Table do
  it "creates table" do
    TableDB.customers.drop!
    TableDB.customers.create!

    customer = CustomerModel.new(1, "John", "New York", 100)

    TableDB.insert.into(:customers).values(
      id: customer.id,
      name: customer.name,
      city: customer.city,
      balance: customer.balance
    ).commit

    persisted = TableDB.query.from(:customers).first!(as: CustomerModel)

    persisted.id.should eq customer.id
    persisted.name.should eq customer.name
    persisted.city.should eq customer.city
    persisted.balance.should eq customer.balance
  end

  it "truncates table" do
    TableDB.customers.drop!
    TableDB.customers.create!

    customers = [
      {:name => "John", :city => "New York", :balance => 100},
      {:name => "Jane", :city => "New York", :balance => 200},
    ]

    TableDB
      .insert
      .into(:customers)
      .values(customers)
      .commit

    count_query = TableDB.query.from(:customers).count
    count_query.first!(as: Int32).should eq 2

    TableDB.delete.from(:customers).commit
    count_query.first!(as: Int32).should eq 0
  end

  it "drops table" do
    TableDB.customers.drop!
    table = TableDB.customers.table_name.to_s
    check_query = "SELECT name FROM sqlite_master WHERE type='table' AND name='#{table}'"

    expect_raises(DB::NoResultsError) do
      TableDB.db.query_one(check_query, as: String)
    end
  end
end
