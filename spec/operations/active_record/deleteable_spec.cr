require "../../spec_helper"

describe CQL::ActiveRecord::Deleteable do
  before_each do
    UserDB.users.create!
  end

  after_each do
    UserDB.users.drop!
  end

  describe ".delete!" do
    it "deletes a record by ID" do
      # Create a test user
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )

      user.create!
      user.id.should be_a(Int32)

      # Delete the user
      user.delete!

      user.id.should be_nil
    end

    it "raises error when trying to delete non-existent record" do
      result = TestUser.delete!(999)
      result.rows_affected.should eq(0)
    end

    it "returns false when trying to delete a record with nil id" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )

      user.delete!.should be_false
    end
  end

  describe ".delete_by!" do
    it "deletes records matching specific fields" do
      # Create test users
      user1 = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user1.create!

      user2 = TestUser.new(
        name: "Jane Doe",
        email: "jane@example.com",
        age: 25,
        password: "password123",
        password_confirmation: "password123"
      )
      user2.create!

      # Delete user by email
      TestUser.delete_by!(email: "john@example.com")

      # Verify only the matching user is deleted
      users = TestUser.all
      users.size.should eq(1)
      users.first.email.should eq("jane@example.com")
    end

    it "deletes multiple records when multiple fields match" do
      # Create test users
      user1 = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user1.create!

      user2 = TestUser.new(
        name: "John Smith",
        email: "john.smith@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user2.create!

      # Delete users by age
      TestUser.delete_by!(age: 30)

      # Verify all matching users are deleted
      users = TestUser.all
      users.size.should eq(0)
    end

    it "does nothing when no records match" do
      # Create a test user
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      # Try to delete with non-matching criteria
      TestUser.delete_by!(email: "nonexistent@example.com")

      # Verify no records were deleted
      users = TestUser.all
      users.size.should eq(1)
      users.first.email.should eq("john@example.com")
    end

    it "deletes records with multiple matching criteria" do
      # Create test users
      user1 = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user1.create!

      user2 = TestUser.new(
        name: "John Doe",
        email: "john.doe@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user2.create!

      # Delete users by name and age
      TestUser.delete_by!(name: "John Doe", age: 30)

      # Verify all matching users are deleted
      users = TestUser.all
      users.size.should eq(0)
    end
  end

  describe ".delete_all" do
    it "deletes all records in the table" do
      # Create multiple test users
      user1 = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user1.create!

      user2 = TestUser.new(
        name: "Jane Doe",
        email: "jane@example.com",
        age: 25,
        password: "password123",
        password_confirmation: "password123"
      )
      user2.create!

      user3 = TestUser.new(
        name: "Bob Smith",
        email: "bob@example.com",
        age: 35,
        password: "password123",
        password_confirmation: "password123"
      )
      user3.create!

      # Delete all users
      TestUser.delete_all

      # Verify all records are deleted
      users = TestUser.all
      users.size.should eq(0)
    end

    it "does nothing when table is empty" do
      # Delete all users from empty table
      TestUser.delete_all

      # Verify table is still empty
      users = TestUser.all
      users.size.should eq(0)
    end

    it "returns result with correct rows affected" do
      # Create multiple test users
      user1 = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user1.create!

      user2 = TestUser.new(
        name: "Jane Doe",
        email: "jane@example.com",
        age: 25,
        password: "password123",
        password_confirmation: "password123"
      )
      user2.create!

      # Delete all users
      result = TestUser.delete_all
      result.rows_affected.should eq(2)
    end
  end

  describe "callbacks" do
    it "runs before_destroy and after_destroy callbacks" do
      user = TestUser.new(
        name: "Test User",
        email: "test@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      # Clear previous callback executions
      CallbackTracker.clear

      # Delete the user
      user.delete!

      # Verify callbacks were executed in correct order
      CallbackTracker.order.should eq(["before_destroy", "check_halt_destroy", "after_destroy"])
    end

    it "halts deletion when before_destroy callback returns false" do
      user = TestUser.new(
        name: "Test User",
        email: "test@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!
      user.halt_on_callback = "before_destroy"

      # Clear previous callback executions
      CallbackTracker.clear

      # Delete the user
      user.delete!.should be_false

      # Verify callbacks were executed in correct order
      CallbackTracker.order.should eq(["before_destroy"])
    end

    it "halts deletion when check_halt_destroy callback returns false" do
      user = TestUser.new(
        name: "Test User",
        email: "test@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!
      user.halt_on_callback = "check_halt_destroy"

      # Clear previous callback executions
      CallbackTracker.clear

      # Delete the user
      user.delete!.should be_false

      # Verify callbacks were executed in correct order
      CallbackTracker.order.should eq(["before_destroy", "check_halt_destroy"])
    end
  end

  describe "#destroyed?" do
    it "returns false for new records" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )

      user.destroyed?.should be_false
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

      user.destroyed?.should be_false
    end

    it "returns true after record is successfully deleted" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      user.destroyed?.should be_false
      user.delete!
      user.destroyed?.should be_true
    end

    it "returns false when deletion fails due to nil id" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )

      user.destroyed?.should be_false
      user.delete!.should be_false    # Deletion fails
      user.destroyed?.should be_false # Should still be false
    end

    it "returns false when deletion is halted by callback" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!
      user.halt_on_callback = "before_destroy"

      user.destroyed?.should be_false
      user.delete!.should be_false    # Deletion halted
      user.destroyed?.should be_false # Should still be false
    end
  end
end
