require "../spec_helper"

Users = CQL::Repository(User, Int32).new(Billing, :users)

# A repository whose key is a String, for count
RepositoryLabelDB = CQL::Schema.define(:repository_labels, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("repository_labels.db")) do
  table :labels do
    primary :id, String, auto_increment: false
    column :name, String
  end
end

struct RepositoryLabel
  include DB::Serializable

  getter id : String
  getter name : String
end

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

  it "raises DB::NoResultsError from find! for a missing ID" do
    expect_raises(DB::NoResultsError, "No records found with id=999") { Users.find!(999) }
  end

  it "counts rows of a repository keyed by a String" do
    RepositoryLabelDB.labels.create!
    labels = CQL::Repository(RepositoryLabel, String).new(RepositoryLabelDB, :labels)
    RepositoryLabelDB.insert.into(:labels).values(id: "red", name: "Red").commit
    RepositoryLabelDB.insert.into(:labels).values(id: "blue", name: "Blue").commit

    labels.count.should eq(2_i64)
  ensure
    RepositoryLabelDB.labels.drop!
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

  it "updates a user by ID from a hash" do
    id = Users.create(name: "John Doe", email: "john@example.com")
    Users.update(id.to_i32, {:name => "John Updated"} of Symbol => DB::Any)

    Users.find!(id.to_i32).name.should eq("John Updated")
  end

  it "updates the users matching the where attributes" do
    john = Users.create(name: "John Doe", email: "john@example.com")
    jane = Users.create(name: "Jane Doe", email: "jane@example.com")
    Users.update_by({:email => "john@example.com"} of Symbol => DB::Any, {:name => "John Updated"} of Symbol => DB::Any)

    Users.find!(john.to_i32).name.should eq("John Updated")
    Users.find!(jane.to_i32).name.should eq("Jane Doe")
  end

  it "updates every user from a hash" do
    Users.create(name: "John Doe", email: "john@example.com")
    Users.create(name: "Jane Doe", email: "jane@example.com")
    Users.update_all({:name => "Renamed"} of Symbol => DB::Any)

    Users.all.map(&.name).should eq(["Renamed", "Renamed"])
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
    first_user = Users.first.not_nil!

    first_user.should be_a(User)
    first_user.name.should eq("John Doe")
  end

  it "fetches the last user" do
    Users.create(name: "John Doe", email: "john@example.com")
    Users.create(name: "Jane Doe", email: "jane@example.com")
    last_user = Users.last

    last_user.should be_a(User)
    last_user.try(&.name).should eq("Jane Doe")
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
