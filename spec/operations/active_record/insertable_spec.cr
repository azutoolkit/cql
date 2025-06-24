require "../../spec_helper"

describe CQL::ActiveRecord::Insertable do
  before_each do
    UserDB.users.create!
  end

  after_each do
    UserDB.users.drop!
  end

  describe ".create!" do
    it "creates a new record with given attributes and returns the instance" do
      user = TestUser.create!(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123"
      )

      user.should be_a(TestUser)
      user.id!.should be_a(Int32) # Assuming Pk for TestUser is Int32
      user.id!.should_not be_nil
      user.name.should eq("John Doe")
      user.email.should eq("john@example.com")
      user.age.should eq(30)

      # Verify by fetching from DB
      fetched_user = TestUser.find!(user.id.not_nil!)
      fetched_user.name.should eq("John Doe")
      user.persisted?.should be_truthy
    end

    it "raises validation error when attributes are invalid (using save!)" do
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

    it "raises SQLite3::Exception when required fields with NOT NULL constraint are missing" do
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

      user.should be_a(TestUser)
      user.persisted?.should be_truthy
    end

    it "creates a record without validation" do
      user = TestUser.create!(
        name: "J",              # Invalid name
        email: "invalid-email", # Invalid email
        age: 0,                 # Invalid age
        password: "password123",
      )

      user.should be_a(TestUser)
      user.persisted?.should be_truthy
    end
  end

  describe ".create! (with Hash argument)" do
    it "creates a new record with given fields hash and returns the instance" do
      user = TestUser.create!(
        name: "Jane Doe",
        email: "jane@example.com",
        age: 25,
        password: "password123",
      )

      user.should be_a(TestUser)
      user.id.should be_a(Int32)
      user.id.should_not be_nil
      user.name.should eq("Jane Doe")
      user.email.should eq("jane@example.com")
      user.age.should eq(25)

      # Optionally verify by fetching
      fetched_user = TestUser.find!(user.id.not_nil!)
      fetched_user.name.should eq("Jane Doe")
      user.persisted?.should be_truthy
    end

    it "creates a record without running model validations when using attribute hash (hitting DB constraints if any)" do
      # This test assumes create! with a hash bypasses model validations similar to **fields,
      # and would hit DB error for NOT NULL if not provided and constraint exists.
      # If it's expected to run validations, the expectation should change.
      expect_raises(SQLite3::Exception) do # Or specific validation error if create! is changed to validate
        TestUser.create!({
          :name  => "J",             # Potentially invalid by model validation
          :email => "invalid-email", # Potentially invalid by model validation
          # age: 0,                 # Potentially invalid by model validation
          # password: "password123" # Missing age and password for SQLite3::Exception if they are NOT NULL
        })
      end
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
      created_user.id.should_not be_nil
      created_user.id.should be_a(Int32)
      created_user.name.should eq("Alice Smith")
      created_user.email.should eq("alice@example.com")
      created_user.age.should eq(28)
      user.persisted?.should be_truthy
    end

    it "raises validation error when instance is invalid (using save!)" do
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

  describe ".find_or_create_by" do
    context "with named arguments" do
      it "creates a new record if it does not exist and returns the instance" do
        email_to_check = "new_user@example.com"
        TestUser.find_by(email: email_to_check).should be_nil # Ensure it doesn't exist

        user = TestUser.find_or_create_by(
          name: "New User",
          email: email_to_check,
          age: 33,
          password: "passwordSecure"
        )

        user.should be_a(TestUser)
        user.id.should_not be_nil
        user.name.should eq("New User")
        user.email.should eq(email_to_check)
        user.age.should eq(33)

        # Verify it's in the DB
        fetched_user = TestUser.find!(user.id.not_nil!)
        fetched_user.email.should eq(email_to_check)
        user.persisted?.should be_truthy
      end

      it "returns an existing record if found and returns the instance" do
        existing_user = TestUser.create!(
          name: "Existing User",
          email: "existing@example.com",
          age: 40,
          password: "passwordOld"
        )
        existing_user.id.should_not be_nil

        count_before = TestUser.count

        user = TestUser.find_or_create_by(email: "existing@example.com")

        user.should be_a(TestUser)
        user.id.should eq(existing_user.id)
        user.name.should eq("Existing User")

        TestUser.count.should eq(count_before) # No new record created
        user.persisted?.should be_truthy
      end
    end

    context "with a hash argument" do
      it "creates a new record if it does not exist and returns the instance" do
        email_to_check = "new_hash_user@example.com"
        TestUser.find_by(email: email_to_check).should be_nil

        user = TestUser.find_or_create_by({
          :name     => "New Hash User",
          :email    => email_to_check,
          :age      => 34,
          :password => "passwordHashSecure",
        })

        user.should be_a(TestUser)
        user.id.should_not be_nil
        user.name.should eq("New Hash User")
        user.email.should eq(email_to_check)
        user.age.should eq(34)

        fetched_user = TestUser.find!(user.id.not_nil!)
        fetched_user.email.should eq(email_to_check)
        user.persisted?.should be_truthy
      end

      it "returns an existing record if found and returns the instance" do
        existing_user = TestUser.create!(
          name: "Existing Hash User",
          email: "existing_hash@example.com",
          age: 41,
          password: "passwordOldHash"
        )
        existing_user.id.should_not be_nil

        count_before = TestUser.count

        user = TestUser.find_or_create_by({:email => "existing_hash@example.com"})

        user.should be_a(TestUser)
        user.id.should eq(existing_user.id)
        user.name.should eq("Existing Hash User")

        TestUser.count.should eq(count_before)
        user.persisted?.should be_truthy
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

  describe "#new_record?" do
    it "returns true for new records" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )

      user.new_record?.should be_true
      user.persisted?.should be_false
    end

    it "returns false for persisted records" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      user.new_record?.should be_false
      user.persisted?.should be_true
    end

    it "returns false after successful save" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )

      user.new_record?.should be_true
      user.save!
      user.new_record?.should be_false
    end

    it "returns true when record creation fails" do
      user = TestUser.new(
        name: "J", # Too short - validation should fail
        email: "invalid-email",
        age: 0,
        password: "password123",
        password_confirmation: "different"
      )

      user.new_record?.should be_true
      expect_raises(CQL::ActiveRecord::Validations::ValidationError) do
        user.save!
      end
      user.new_record?.should be_true # Should still be true after failed save
    end

    it "is opposite of persisted?" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )

      # Before creation
      user.new_record?.should eq(!user.persisted?)

      # After creation
      user.create!
      user.new_record?.should eq(!user.persisted?)
    end
  end
end
