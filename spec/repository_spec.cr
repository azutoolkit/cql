require "./spec_helper"

Users = CQL::Repository(User, Int32).new(Billing, :users)

describe CQL::Repository(User, Int32) do
  Billing.users.create!

  before_each do
    Users.delete_all
  end

  it "creates a new user" do
    id = Users.create(name: "John Doe", email: "john@example.com")
    user = Users.find!(id.to_i32)

    user.name.should eq("John Doe")
    user.email.should eq("john@example.com")
    Users.delete_all
  end

  it "fetches all users" do
    Users.delete_all
    Users.create(name: "John Doe", email: "john@example.com")
    Users.create(name: "Jane Doe", email: "jane@example.com")
    users = Users.all
    users.size.should eq(2)
  end

  it "finds a user by ID" do
    id = Users.create(name: "John Doe", email: "john@example.com")
    user = Users.find!(id.to_i32)

    user.name.should eq("John Doe")
  end

  it "updates a user by ID" do
    id = Users.create(name: "John Doe", email: "john@example.com")
    Users.update(id.to_i32, name: "John Updated", email: "john.updated@example.com")

    user = Users.find!(id.to_i32)

    user.name.should eq("John Updated")
    user.email.should eq("john.updated@example.com")
  end

  it "deletes a user by ID" do
    user_id = Users.create(name: "John Doe", email: "john@example.com")
    Users.delete(user_id.to_i32)

    Users.find(user_id.to_i32).should be_nil
  end

  it "counts the number of users" do
    Users.create(name: "John Doe", email: "john@example.com")
    Users.create(name: "Jane Doe", email: "jane@example.com")

    user_count = Users.count
    user_count.should eq(2)
  end

  it "checks if a user exists with specific attributes" do
    Users.create(name: "John Doe", email: "john@example.com")

    exists = Users.exists?(name: "John Doe")
    exists.should be_true

    not_exists = Users.exists?(name: "Jane Doe")
    not_exists.should be_false
  end

  it "fetches the first user" do
    Users.create(name: "John Doe", email: "john@example.com")
    Users.create(name: "Jane Doe", email: "jane@example.com")
    first_user = Users.first

    first_user.should be_a(User)
    first_user.name.should eq("John Doe")
  end

  it "fetches the last user" do
    Users.create(name: "John Doe", email: "john@example.com")
    Users.create(name: "Jane Doe", email: "jane@example.com")
    last_user = Users.last

    last_user.should be_a(User)
    last_user.name.should eq("Jane Doe")
  end

  it "fetches users with pagination" do
    (1..20).each do |i|
      Users.create(name: "User #{i}", email: "user#{i}@example.com")
    end

    users_page_1 = Users.page(1, 10)
    users_page_2 = Users.page(2, 10)

    users_page_1.size.should eq(10)
    users_page_2.size.should eq(10)

    users_page_1.first.name.should eq("User 1")
    users_page_2.first.name.should eq("User 11")
  end
end
