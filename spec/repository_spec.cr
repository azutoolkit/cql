require "./spec_helper"

describe Cql::Repository(User) do
  before_each do
    Billing.tables.each do |_, table|
      table.create!
    end
  end

  after_each do
    Billing.tables.each do |_, table|
      table.drop!
    end
  end

  user_repository = Cql::Repository(User).new(Billing, :users)

  it "creates a new user" do
    user_repository.create(id: 1, name: "John Doe", email: "john@example.com")
    user = user_repository.find!(1)

    user.name.should eq("John Doe")
    user.email.should eq("john@example.com")
  end

  it "fetches all users" do
    user_repository.create(id: 1, name: "John Doe", email: "john@example.com")
    user_repository.create(id: 2, name: "Jane Doe", email: "jane@example.com")

    users = user_repository.all

    users.size.should eq(2)
  end

  it "finds a user by ID" do
    user_repository.create(id: 1, name: "John Doe", email: "john@example.com")
    user = user_repository.find!(1)

    user.name.should eq("John Doe")
  end

  it "updates a user by ID" do
    user_repository.create(id: 1, name: "John Doe", email: "john@example.com")
    user_repository.update(1, name: "John Updated", email: "john.updated@example.com")
    user = user_repository.find!(1)

    user.name.should eq("John Updated")
    user.email.should eq("john.updated@example.com")
  end

  it "deletes a user by ID" do
    user_id = user_repository.create(id: 1, name: "John Doe", email: "john@example.com")
    user_repository.delete(user_id.to_i32)

    user_repository.find(user_id.to_i32).should be_nil
  end

  it "counts the number of users" do
    user_repository.create(id: 1, name: "John Doe", email: "john@example.com")
    user_repository.create(id: 2, name: "Jane Doe", email: "jane@example.com")

    user_count = user_repository.count
    user_count.should eq(2)
  end

  it "checks if a user exists with specific attributes" do
    user_repository.create(id: 1, name: "John Doe", email: "john@example.com")

    exists = user_repository.exists?(name: "John Doe")
    exists.should be_true

    not_exists = user_repository.exists?(name: "Jane Doe")
    not_exists.should be_false
  end

  it "fetches the first user" do
    user_repository.create(id: 1, name: "John Doe", email: "john@example.com")
    user_repository.create(id: 2, name: "Jane Doe", email: "jane@example.com")
    first_user = user_repository.first

    first_user.should be_a(User)
    first_user.name.should eq("John Doe")
  end

  it "fetches the last user" do
    user_repository.create(id: 1, name: "John Doe", email: "john@example.com")
    user_repository.create(id: 2, name: "Jane Doe", email: "jane@example.com")
    last_user = user_repository.last

    last_user.should be_a(User)
    last_user.name.should eq("Jane Doe")
  end

  it "fetches users with pagination" do
    (1..20).each do |i|
      user_repository.create(id: i, name: "User #{i}", email: "user#{i}@example.com")
    end

    users_page_1 = user_repository.page(1, 10)
    users_page_2 = user_repository.page(2, 10)

    users_page_1.size.should eq(10)
    users_page_2.size.should eq(10)

    users_page_1.first.name.should eq("User 1")
    users_page_2.first.name.should eq("User 11")
  end
end
