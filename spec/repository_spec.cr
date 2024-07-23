require "./spec_helper"

# Assuming we have these models defined
class User
  include DB::Serializable

  property id : Int64
  property name : String
  property email : String

  def initialize(@id : Int64, @name : String, @email : String)
  end
end

describe Sql::Repository(User) do
  schema = Sql::Schema.new(
    database: :northwind,
    adapter: Sql::Adapter::Sqlite,
    db: DB.connect("sqlite3://spec/test.db")
  )

  schema.table :users do
    primary_key :id, Int64, auto_increment: true
    column :name, String
    column :email, String
  end

  before_each do
    schema.tables.each do |_, table|
      table.drop!
      table.create!
    end
  end

  user_repository = Sql::Repository(User).new(schema, :users)

  it "creates a new user" do
    user_repository.create(id: 1_i64, name: "'John Doe'", email: "'john@example.com'")
    user = user_repository.find(1_i64)

    user.name.should eq("John Doe")
    user.email.should eq("john@example.com")
  end

  it "fetches all users" do
    user_repository.create(id: 1_i64, name: "'John Doe'", email: "'john@example.com'")
    user_repository.create(id: 2_i64, name: "'Jane Doe'", email: "'jane@example.com'")

    users = user_repository.all

    users.size.should eq(2)
  end

  it "finds a user by ID" do
    user_repository.create(id: 1_i64, name: "'John Doe'", email: "'john@example.com'")
    user = user_repository.find(1)

    user.name.should eq("John Doe")
  end

  it "updates a user by ID" do
    user_repository.create(id: 1_i64, name: "'John Doe'", email: "'john@example.com'")
    user_repository.update(1, name: "'John Updated", email: "john.updated@example.com'")
    user = user_repository.find(1)

    user.name.should eq("John Updated")
    user.email.should eq("john.updated@example.com")
  end

  it "deletes a user by ID" do
    user_repository.create(id: 1_i64, name: "'John Doe'", email: "'john@example.com'")
    user_repository.delete(1_i64)

    user = user_repository.find(1)
    user.should be_nil
  end

  it "counts the number of users" do
    user_repository.create(id: 1_i64, name: "'John Doe'", email: "'john@example.com'")
    user_repository.create(id: 2_i64, name: "'Jane Doe'", email: "'jane@example.com'")

    user_count = user_repository.count
    user_count.should eq(2)
  end

  it "checks if a user exists with specific attributes" do
    user_repository.create(id: 1_i64, name: "'John Doe'", email: "'john@example.com'")

    exists = user_repository.exists?(name: "'John Doe'")
    exists.should be_true

    not_exists = user_repository.exists?(name: "'Jane Doe'")
    not_exists.should be_false
  end

  it "fetches the first user" do
    user_repository.create(id: 1_i64, name: "'John Doe'", email: "'john@example.com'")
    user_repository.create(id: 2_i64, name: "'Jane Doe'", email: "'jane@example.com'")
    first_user = user_repository.first

    first_user.name.should eq("John Doe")
  end

  it "fetches the last user" do
    user_repository.create(id: 1_i64, name: "'John Doe'", email: "'john@example.com'")
    user_repository.create(id: 2_i64, name: "'Jane Doe'", email: "'jane@example.com'")
    last_user = user_repository.last

    last_user.name.should eq("Jane Doe")
  end

  it "fetches users with pagination" do
    (1..20).each do |i|
      user_repository.create(id: 1_i64, name: "'User #{i}'", email: "'user#{i}@example.com'")
    end

    users_page_1 = user_repository.page(1, 10)
    users_page_2 = user_repository.page(2, 10)

    users_page_1.size.should eq(10)
    users_page_2.size.should eq(10)

    users_page_1.first.name.should eq("User 1")
    users_page_2.first.name.should eq("User 11")
  end
end
