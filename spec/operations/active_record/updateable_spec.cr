require "../../spec_helper"

describe CQL::ActiveRecord::Updateable do
  before_each do
    UserDB.users.create!
  end

  after_each do
    UserDB.users.drop!
  end

  describe ".update" do
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

    it "raises error when updating non-existent record" do
      result = TestUser.update!(999, name: "Jane Doe")
      result.rows_affected.should eq(0)
    end

    it "raises error when updating with invalid data type" do
      user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
      user.save!
      id = user.id!

      expect_raises(CQL::Error) do
        TestUser.update!(id, age: "invalid")
      end
    end

    it "handles updating with nil values" do
      user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
      user.save!
      id = user.id!

      result = TestUser.update!(id, name: "")
      result.rows_affected.should eq(1)

      updated_user = TestUser.find!(id)
      updated_user.name.should be_empty
    end

    it "handles updating with empty attributes" do
      user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
      user.save!
      id = user.id!

      expect_raises(CQL::Error) do
        TestUser.update!(id, {} of Symbol => DB::Any)
      end

      updated_user = TestUser.find!(id)
      updated_user.name.should eq("John Doe")
      updated_user.age.should eq(25)
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
    end

    it "updates multiple records matching where attributes" do
      user1 = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
      user2 = TestUser.new("Jane Doe", "jane@example.com", 30, "password123", "password123")
      user1.save!
      user2.save!

      result = TestUser.update_by({:age => 25}, {:age => 35})
      result.rows_affected.should eq(1)

      updated_user = TestUser.find!(user1.id.not_nil!)
      updated_user.age.should eq(35)
    end

    it "returns zero affected rows when no records match" do
      user1 = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
      user2 = TestUser.new("Jane Doe", "jane@example.com", 30, "password123", "password123")
      user1.save!
      user2.save!

      result = TestUser.update_by({:email => "nonexistent@example.com"}, {:age => 35})
      result.rows_affected.should eq(0)
    end
  end

  describe ".update_all" do
    it "updates all records with given attributes" do
      user1 = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
      user2 = TestUser.new("Jane Doe", "jane@example.com", 30, "password123", "password123")
      user1.save!
      user2.save!

      result = TestUser.update_all({:age => 35})
      result.rows_affected.should eq(2)

      updated_users = TestUser.all
      updated_users.each do |user|
        user.age.should eq(35)
      end
    end

    it "returns zero affected rows when table is empty" do
      result = TestUser.update_all({:age => 35})
      result.rows_affected.should eq(0)
    end
  end

  describe "#update!" do
    it "updates the record with given fields" do
      user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
      user.save!
      id = user.id!
      user.name = "Jane Doe"
      user.age = 30
      result = user.update!

      result.should be_a(TestUser)
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

    it "updates the record with given attributes hash" do
      user = TestUser.new("John Doe", "john@example.com", 25, "password123", "password123")
      user.save!

      user.update!(name: "Jane Doe", age: 30)

      user.name.should eq("Jane Doe")
      user.age.should eq(30)
    end
  end
end
