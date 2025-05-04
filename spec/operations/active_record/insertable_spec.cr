require "../../spec_helper"

describe CQL::ActiveRecord::Insertable do
  before_each do
    UserDB.users.create!
  end

  after_each do
    UserDB.users.drop!
  end

  describe ".create!" do
    it "creates a new record with given attributes" do
      id = TestUser.create!(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123"
      )

      id.should be_a(Int32)

      user = TestUser.find!(id)

      user.should be_a(TestUser)
      user.id.should_not be_nil
      user.name.should eq("John Doe")
      user.email.should eq("john@example.com")
      user.age.should eq(30)
    end

    it "raises validation error when attributes are invalid" do
      expect_raises(CQL::ActiveRecord::Validations::ValidationError) do
        record = TestUser.new(
          name: "J", # Too short
          email: "invalid-email",
          age: 0, # Invalid age
          password: "password123"
        )

        record.save!
      end
    end

    it "raises validation error when required fields are missing" do
      expect_raises(SQLite3::Exception) do
        TestUser.create!(
          name: "John Doe",
          email: "john@example.com"
          # Missing age and password fields
        )
      end
    end
  end

  describe ".create" do
    it "creates a new record with given fields" do
      user = TestUser.create!(
        name: "Jane Doe",
        email: "jane@example.com",
        age: 25,
        password: "password123"
      )

      user.should be_a(Int32) # Returns the ID
      user.should_not eq(0)
    end

    it "creates a record without validation" do
      user = TestUser.create!(
        name: "J",              # Invalid name
        email: "invalid-email", # Invalid email
        age: 0,                 # Invalid age
        password: "password123",
      )

      user.should be_a(Int32)
      user.should_not eq(0)
    end
  end

  describe "#create!" do
    it "creates a new record from a model instance" do
      user = TestUser.new(
        name: "Alice Smith",
        email: "alice@example.com",
        age: 28,
        password: "password123",
        password_confirmation: "password123"
      )

      created_user = user.create!

      created_user.should be_a(TestUser)
      # created_user.id.should_not be_nil
      # created_user.name.should eq("Alice Smith")
    end

    it "raises validation error when instance is invalid" do
      user = TestUser.new(
        name: "A",              # Invalid name
        email: "invalid-email", # Invalid email
        age: 0,                 # Invalid age
        password: "password123",
        password_confirmation: "different" # Mismatch
      )

      expect_raises(CQL::ActiveRecord::Validations::ValidationError) do
        user.save!
      end
    end
  end

  describe "#attributes" do
    it "returns a hash of all non-ignored attributes" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )

      attrs = user.attributes
      attrs.should be_a(Hash(Symbol, DB::Any))
      attrs[:name].should eq("John Doe")
      attrs[:email].should eq("john@example.com")
      attrs[:age].should eq(30)
      attrs[:password].should eq("password123")
      attrs.has_key?(:password_confirmation).should be_false # Should be ignored due to @[DB::Field(ignore: true)]
    end

    it "excludes ignored fields from the attributes hash" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )

      attrs = user.attributes
      attrs.has_key?(:password_confirmation).should be_false
    end

    it "excludes the errors array from the attributes hash" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123"
      )

      attrs = user.attributes
      attrs.has_key?(:errors).should be_false
    end

    it "sets attributes from a hash" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123"
      )

      new_attrs = Hash(Symbol, DB::Any).new
      new_attrs[:name] = "Jane Doe"
      new_attrs[:email] = "jane@example.com"
      new_attrs[:age] = 25

      user.attributes(new_attrs)
      user.name.should eq("Jane Doe")
      user.email.should eq("jane@example.com")
      user.age.should eq(25)
    end

    it "ignores invalid attribute types when setting attributes" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123"
      )

      new_attrs = Hash(Symbol, DB::Any).new
      new_attrs[:name] = "Jane Doe"
      new_attrs[:email] = "jane@example.com"
      new_attrs[:age] = "25" # String instead of Int32

      user.attributes(new_attrs)
      user.name.should eq("Jane Doe")
      user.email.should eq("jane@example.com")
      user.age.should eq(30) # Should remain unchanged due to type mismatch
    end
  end
end
