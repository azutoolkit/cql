require "./spec_helper"

describe CQL::ActiveRecord::Deleteable do
  describe ".delete!" do
    it "deletes a record by ID" do
      user = TestUser.create!(name: "Delete Test", email: "delete@example.com", age: 25)
      id = user.id.not_nil!

      result = TestUser.delete!(id)
      result.should be_a(Int64)

      # Verify the record is deleted
      expect_raises(DB::NoResultsError) do
        TestUser.find!(id)
      end
    end

    it "returns a result with affected rows" do
      user = TestUser.create!(name: "Delete Test", email: "delete@example.com", age: 25)
      id = user.id.not_nil!

      result = TestUser.delete!(id)
      result.rows_affected.should eq(1)
    end
  end

  describe ".delete_by!" do
    it "deletes records matching specific fields with hash syntax" do
      user1 = TestUser.create!(name: "Delete Test 1", email: "delete1@example.com", age: 25)
      user2 = TestUser.create!(name: "Delete Test 2", email: "delete2@example.com", age: 30)
      user3 = TestUser.create!(name: "Delete Test 3", email: "delete3@example.com", age: 25)

      result = TestUser.delete_by!(age: 25)
      result.should be_a(Int64)

      # Verify only records with age 25 are deleted
      expect_raises(DB::NoResultsError) { TestUser.find!(user1.id.not_nil!) }
      TestUser.find!(user2.id.not_nil!) # Should still exist
      expect_raises(DB::NoResultsError) { TestUser.find!(user3.id.not_nil!) }
    end

    it "deletes records matching specific fields with hash parameter" do
      user1 = TestUser.create!(name: "Delete Test 1", email: "delete1@example.com", age: 25)
      user2 = TestUser.create!(name: "Delete Test 2", email: "delete2@example.com", age: 30)

      fields = {:age => 25} of Symbol => DB::Any
      result = TestUser.delete_by!(fields)
      result.should be_a(Int64)

      # Verify only records with age 25 are deleted
      expect_raises(DB::NoResultsError) { TestUser.find!(user1.id.not_nil!) }
      TestUser.find!(user2.id.not_nil!) # Should still exist
    end

    it "deletes records matching multiple fields" do
      user1 = TestUser.create!(name: "Delete Test", email: "delete1@example.com", age: 25)
      user2 = TestUser.create!(name: "Delete Test", email: "delete2@example.com", age: 30)
      user3 = TestUser.create!(name: "Other Name", email: "delete3@example.com", age: 25)

      result = TestUser.delete_by!(name: "Delete Test", age: 25)
      result.should be_a(Int64)

      # Verify only the matching record is deleted
      expect_raises(DB::NoResultsError) { TestUser.find!(user1.id.not_nil!) }
      TestUser.find!(user2.id.not_nil!) # Should still exist
      TestUser.find!(user3.id.not_nil!) # Should still exist
    end
  end

  describe ".delete_all" do
    it "deletes all records in the table" do
      # Create some test records
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)
      TestUser.create!(name: "User 3", email: "user3@example.com", age: 35)

      result = TestUser.delete_all
      result.should be_a(Int64)

      # Verify all records are deleted
      TestUser.all.size.should eq(0)
    end

    it "returns a result with affected rows" do
      # Create some test records
      TestUser.create!(name: "User 1", email: "user1@example.com", age: 25)
      TestUser.create!(name: "User 2", email: "user2@example.com", age: 30)

      result = TestUser.delete_all
      result.rows_affected.should eq(2)
    end
  end

  describe "#destroyed?" do
    it "returns false for a new record" do
      user = TestUser.new("Test User", "test@example.com", 25)
      user.destroyed?.should be_false
    end

    it "returns false for a persisted record" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user.destroyed?.should be_false
    end

    it "returns true after the record is destroyed" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user.delete!
      user.destroyed?.should be_true
    end
  end

  describe "#delete!" do
    it "deletes the record from the database" do
      user = TestUser.create!(name: "Delete Test", email: "delete@example.com", age: 25)
      id = user.id.not_nil!

      result = user.delete!
      result.should be_true

      # Verify the record is deleted
      expect_raises(DB::NoResultsError) do
        TestUser.find!(id)
      end
    end

    it "returns false for a new record" do
      user = TestUser.new("Test User", "test@example.com", 25)
      result = user.delete!
      result.should be_false
    end

    it "runs before_destroy callbacks" do
      user = TestUser.create!(name: "Callback Test", email: "callback@example.com", age: 25)
      user.halt_on_callback = "before_destroy"

      result = user.delete!
      result.should be_false

      # Verify the record still exists
      TestUser.find!(user.id.not_nil!)
    end

    it "runs after_destroy callbacks on successful deletion" do
      user = TestUser.create!(name: "Callback Test", email: "callback@example.com", age: 25)
      user.halt_on_callback = nil

      result = user.delete!
      result.should be_true

      # Verify callbacks were run
      CallbackTracker.included?("before_destroy").should be_true
      CallbackTracker.included?("after_destroy").should be_true
    end

    it "sets destroyed flag and clears ID on successful deletion" do
      user = TestUser.create!(name: "Destroy Test", email: "destroy@example.com", age: 25)
      user.id.not_nil!

      result = user.delete!
      result.should be_true

      user.destroyed?.should be_true
      user.id.should be_nil
    end

    it "does not set destroyed flag on failed deletion" do
      user = TestUser.create!(name: "Fail Test", email: "fail@example.com", age: 25)
      user.halt_on_callback = "before_destroy"

      result = user.delete!
      result.should be_false

      user.destroyed?.should be_false
      user.id.should_not be_nil
    end
  end
end
