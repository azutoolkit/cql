require "../../spec_helper"

describe CQL::ActiveRecord::Updateable do
  before_each do
    UserDB.users.create!
  end

  after_each do
    UserDB.users.drop!
  end

  describe ".update!" do
    describe "with Hash(Symbol, DB::Any)" do
      it "updates a record by ID with attributes" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!
        id = user.id.not_nil!

        result = TestUser.update!(id, name: "Jane Doe", age: 30)
        result.rows_affected.should eq(1)

        updated_user = TestUser.find!(id)
        updated_user.name.should eq("Jane Doe")
        updated_user.age.should eq(30)
      end

      it "raises error when updating with empty attributes" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!
        id = user.id!

        expect_raises(CQL::Error, "No attributes to update") do
          TestUser.update!(id, {} of Symbol => DB::Any)
        end

        updated_user = TestUser.find!(id)
        updated_user.name.should eq("John Doe")
        updated_user.age.should eq(25)
      end

      it "raises error when updating with unknown column" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!
        id = user.id!

        expect_raises(CQL::Error, "Unknown column: unknown_column") do
          TestUser.update!(id, unknown_column: "value")
        end
      end

      it "raises error when updating with invalid data type" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!
        id = user.id!

        expect_raises(CQL::Error, "Invalid type for column age: expected Int32, got String") do
          TestUser.update!(id, age: "invalid")
        end
      end

      it "handles updating with nil values for nullable columns" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!
        id = user.id!

        result = TestUser.update!(id, name: nil)
        result.rows_affected.should eq(1)

        updated_user = TestUser.find!(id)
        updated_user.name.should be_nil
      end

      it "raises error when setting non-nullable column to nil" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!
        id = user.id!

        expect_raises(CQL::Error, "Column email cannot be null") do
          TestUser.update!(id, email: nil)
        end
      end

      it "returns zero affected rows when updating non-existent record" do
        result = TestUser.update!(999, name: "Jane Doe")
        result.rows_affected.should eq(0)
      end
    end

    describe "with keyword arguments" do
      it "updates a record by ID with fields" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!
        id = user.id.not_nil!

        result = TestUser.update!(id, name: "Jane Doe", age: 30)
        result.rows_affected.should eq(1)

        updated_user = TestUser.find!(id)
        updated_user.name.should eq("Jane Doe")
        updated_user.age.should eq(30)
      end

      it "raises error when updating with empty keyword arguments" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!
        id = user.id!

        expect_raises(CQL::Error, "No attributes to update") do
          TestUser.update!(id)
        end
      end

      it "raises error when updating with unknown column via keyword arguments" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!
        id = user.id!

        expect_raises(CQL::Error, "Unknown column: unknown_column") do
          TestUser.update!(id, unknown_column: "value")
        end
      end

      it "raises error when updating with invalid data type via keyword arguments" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!
        id = user.id!

        expect_raises(CQL::Error, "Invalid type for column age: expected Int32, got String") do
          TestUser.update!(id, age: "invalid")
        end
      end

      it "handles updating with nil values for nullable columns via keyword arguments" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!
        id = user.id!

        result = TestUser.update!(id, name: nil)
        result.rows_affected.should eq(1)

        updated_user = TestUser.find!(id)
        updated_user.name.should be_nil
      end

      it "raises error when setting non-nullable column to nil via keyword arguments" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!
        id = user.id!

        expect_raises(CQL::Error, "Column email cannot be null") do
          TestUser.update!(id, email: nil)
        end
      end
    end

    describe "with record object" do
      it "updates a record by record object" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!
        id = user.id!

        user.name = "Jane Doe"
        user.age = 30

        result = TestUser.update!(user)
        result.should be_a(TestUser)
        result.name.should eq("Jane Doe")
        result.age.should eq(30)

        updated_user = TestUser.find!(id)
        updated_user.name.should eq("Jane Doe")
        updated_user.age.should eq(30)
      end

      it "updates record with modified attributes" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!
        id = user.id!

        # Modify multiple attributes
        user.name = "Jane Doe"
        user.email = "jane@example.com"
        user.age = 30

        result = TestUser.update!(user)
        result.should be_a(TestUser)

        updated_user = TestUser.find!(id)
        updated_user.name.should eq("Jane Doe")
        updated_user.email.should eq("jane@example.com")
        updated_user.age.should eq(30)
      end

      it "preserves unchanged attributes" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!
        id = user.id!

        # Only modify one attribute
        user.name = "Jane Doe"

        result = TestUser.update!(user)
        result.should be_a(TestUser)

        updated_user = TestUser.find!(id)
        updated_user.name.should eq("Jane Doe")
        updated_user.email.should eq("john@example.com") # Should remain unchanged
        updated_user.age.should eq(25) # Should remain unchanged
      end
    end
  end

  describe ".update_by" do
    it "updates records matching where attributes" do
      user1 = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
      user2 = TestUser.new("Jane Doe", "jane@example.com", 30, "password123", "password123")
      user1.save!
      user2.save!

      result = TestUser.update_by({:email => "john@example.com"}, {:age => 35})
      result.rows_affected.should eq(1)

      updated_user = TestUser.find!(user1.id.not_nil!)
      updated_user.age.should eq(35)

      # Verify other user is unchanged
      unchanged_user = TestUser.find!(user2.id.not_nil!)
      unchanged_user.age.should eq(30)
    end

    it "updates multiple records matching where attributes" do
      user1 = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
      user2 = TestUser.new("Jane Doe", "jane@example.com", 25, "password123", "password123")
      user3 = TestUser.new("Bob Doe", "bob@example.com", 30, "password123", "password123")
      user1.save!
      user2.save!
      user3.save!

      result = TestUser.update_by({:age => 25}, {:age => 35})
      result.rows_affected.should eq(2)

      updated_user1 = TestUser.find!(user1.id.not_nil!)
      updated_user1.age.should eq(35)

      updated_user2 = TestUser.find!(user2.id.not_nil!)
      updated_user2.age.should eq(35)

      # Verify other user is unchanged
      unchanged_user = TestUser.find!(user3.id.not_nil!)
      unchanged_user.age.should eq(30)
    end

    it "returns zero affected rows when no records match" do
      user1 = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
      user2 = TestUser.new("Jane Doe", "jane@example.com", 30, "password123", "password123")
      user1.save!
      user2.save!

      result = TestUser.update_by({:email => "nonexistent@example.com"}, {:age => 35})
      result.rows_affected.should eq(0)
    end

    it "updates with multiple where conditions" do
      user1 = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
      user2 = TestUser.new("John Doe", "john2@example.com", 25, "password123", "password123")
      user1.save!
      user2.save!

      result = TestUser.update_by({:name => "John Doe", :age => 25}, {:age => 35})
      result.rows_affected.should eq(2)

      updated_user1 = TestUser.find!(user1.id.not_nil!)
      updated_user1.age.should eq(35)

      updated_user2 = TestUser.find!(user2.id.not_nil!)
      updated_user2.age.should eq(35)
    end

    it "updates multiple columns at once" do
      user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
      user.save!

      result = TestUser.update_by({:email => "john@example.com"}, {:name => "Jane Doe", :age => 30})
      result.rows_affected.should eq(1)

      updated_user = TestUser.find!(user.id.not_nil!)
      updated_user.name.should eq("Jane Doe")
      updated_user.age.should eq(30)
    end
  end

  describe ".update_all" do
    it "updates all records with given attributes" do
      user1 = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
      user2 = TestUser.new("Jane Doe", "jane@example.com", 30, "password123", "password123")
      user3 = TestUser.new("Bob Doe", "bob@example.com", 35, "password123", "password123")
      user1.save!
      user2.save!
      user3.save!

      result = TestUser.update_all({:age => 40})
      result.rows_affected.should eq(3)

      updated_users = TestUser.all
      updated_users.each do |user|
        user.age.should eq(40)
      end
    end

    it "returns zero affected rows when table is empty" do
      result = TestUser.update_all({:age => 35})
      result.rows_affected.should eq(0)
    end

    it "updates multiple columns for all records" do
      user1 = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
      user2 = TestUser.new("Jane Doe", "jane@example.com", 30, "password123", "password123")
      user1.save!
      user2.save!

      result = TestUser.update_all({:name => "Updated User", :age => 50})
      result.rows_affected.should eq(2)

      updated_users = TestUser.all
      updated_users.each do |user|
        user.name.should eq("Updated User")
        user.age.should eq(50)
      end
    end

    it "preserves other columns when updating specific ones" do
      user1 = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
      user2 = TestUser.new("Jane Doe", "jane@example.com", 30, "password123", "password123")
      user1.save!
      user2.save!

      original_emails = [user1.email, user2.email]

      result = TestUser.update_all({:age => 40})
      result.rows_affected.should eq(2)

      updated_users = TestUser.all
      updated_users.each_with_index do |user, index|
        user.age.should eq(40)
        user.email.should eq(original_emails[index]) # Email should remain unchanged
      end
    end
  end

  describe "#update!" do
    describe "instance method without arguments" do
      it "updates the record with current attributes" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!
        id = user.id!

        user.name = "Jane Doe"
        user.age = 30

        result = user.update!
        result.should be_a(TestUser)
        result.name.should eq("Jane Doe")
        result.age.should eq(30)

        updated_user = TestUser.find!(id)
        updated_user.name.should eq("Jane Doe")
        updated_user.age.should eq(30)
      end

      it "validates the record before updating" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!
        id = user.id!

        user.name = "J" # Too short
        user.age = 150  # Too old

        expect_raises(CQL::ActiveRecord::Validations::ValidationError) do
          user.save!
        end

        updated_user = TestUser.find!(id)
        updated_user.name.should eq("John Doe")
        updated_user.age.should eq(25)
      end

      it "preserves unchanged attributes" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!
        id = user.id!

        # Only modify one attribute
        user.name = "Jane Doe"

        result = user.update!
        result.should be_a(TestUser)

        updated_user = TestUser.find!(id)
        updated_user.name.should eq("Jane Doe")
        updated_user.email.should eq("john@example.com") # Should remain unchanged
        updated_user.age.should eq(25) # Should remain unchanged
      end
    end

    describe "instance method with keyword arguments" do
      it "updates the record with given fields" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!

        result = user.update!(name: "Jane Doe", age: 30)
        result.should be_a(TestUser)
        result.name.should eq("Jane Doe")
        result.age.should eq(30)

        updated_user = TestUser.find!(user.id.not_nil!)
        updated_user.name.should eq("Jane Doe")
        updated_user.age.should eq(30)
      end

      it "validates the record before updating with keyword arguments" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!

        user.update!(name: "J", age: 150) # Invalid values
        expect_raises(CQL::ActiveRecord::Validations::ValidationError) do
          user.save!
        end
      end

      it "updates local instance attributes" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!

        result = user.update!(name: "Jane Doe", age: 30)

        # Local instance should be updated
        user.name.should eq("Jane Doe")
        user.age.should eq(30)

        # Database should be updated
        updated_user = TestUser.find!(user.id.not_nil!)
        updated_user.name.should eq("Jane Doe")
        updated_user.age.should eq(30)
      end
    end

    describe "instance method with Hash(Symbol, DB::Any)" do
      it "updates the record with given attributes hash" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!

        result = user.update!({:name => "Jane Doe", :age => 30})
        result.should be_a(TestUser)
        result.name.should eq("Jane Doe")
        result.age.should eq(30)

        updated_user = TestUser.find!(user.id.not_nil!)
        updated_user.name.should eq("Jane Doe")
        updated_user.age.should eq(30)
      end

      it "validates the record before updating with attributes hash" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!

        user.update!({:name => "J", :age => 150}) # Invalid values
        expect_raises(CQL::ActiveRecord::Validations::ValidationError) do
          user.save!
        end
      end

      it "updates local instance attributes with hash" do
        user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
        user.save!

        result = user.update!({:name => "Jane Doe", :age => 30})

        # Local instance should be updated
        user.name.should eq("Jane Doe")
        user.age.should eq(30)

        # Database should be updated
        updated_user = TestUser.find!(user.id.not_nil!)
        updated_user.name.should eq("Jane Doe")
        updated_user.age.should eq(30)
      end
    end
  end

  describe "edge cases and error handling" do
    it "handles updating with empty string values" do
      user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
      user.save!
      id = user.id!

      result = TestUser.update!(id, name: "")
      result.rows_affected.should eq(1)

      updated_user = TestUser.find!(id)
      updated_user.name.should eq("")
    end

    it "handles updating with zero values" do
      user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
      user.save!
      id = user.id!

      result = TestUser.update!(id, age: 0)
      result.rows_affected.should eq(1)

      updated_user = TestUser.find!(id)
      updated_user.age.should eq(0)
    end

    it "handles updating with special characters in strings" do
      user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
      user.save!
      id = user.id!

      special_name = "John O'Connor-Smith & Co."
      result = TestUser.update!(id, name: special_name)
      result.rows_affected.should eq(1)

      updated_user = TestUser.find!(id)
      updated_user.name.should eq(special_name)
    end

    it "handles updating with very long strings" do
      user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
      user.save!
      id = user.id!

      long_name = "A" * 1000
      result = TestUser.update!(id, name: long_name)
      result.rows_affected.should eq(1)

      updated_user = TestUser.find!(id)
      updated_user.name.should eq(long_name)
    end

    it "handles updating with large integer values" do
      user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
      user.save!
      id = user.id!

      large_age = 999999
      result = TestUser.update!(id, age: large_age)
      result.rows_affected.should eq(1)

      updated_user = TestUser.find!(id)
      updated_user.age.should eq(large_age)
    end
  end
end
