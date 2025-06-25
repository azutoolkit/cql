require "./spec_helper"

describe "CQL::ActiveRecord Touch Demo" do
  before_each do
    UserDB.users.create!
    CallbackTracker.clear
  end

  after_each do
    UserDB.users.drop!
  end

  describe "Basic Touch Functionality" do
    it "touches a record without running callbacks" do
      # Create a user with explicit timestamp values
      user = TestUser.new(
        name: "Test User",
        email: "test@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )

      # Set timestamps manually before saving to avoid the NOT NULL issue
      current_time = Time.utc
      user.created_at = current_time
      user.updated_at = current_time
      user.save!
      user.id.should_not be_nil

      # Clear callbacks from save operation
      CallbackTracker.clear

      # Touch the record - this should not trigger callbacks
      user.touch

      # Verify no callbacks were run
      CallbackTracker.order.should be_empty
    end

    it "demonstrates touch vs save callback behavior" do
      # Create a user
      user = TestUser.new(
        name: "Test User",
        email: "test@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )

      # Set timestamps manually and save
      current_time = Time.utc
      user.created_at = current_time
      user.updated_at = current_time
      user.save!

      # Clear callbacks from save operation
      CallbackTracker.clear

      # Touch should not trigger any callbacks
      user.touch
      CallbackTracker.order.should be_empty
      # Now regular save should trigger callbacks
      user.name = "Updated Name"
      user.save!

      # Verify callbacks were triggered for regular save
      CallbackTracker.order.should_not be_empty

      # Show the difference
      expected_callbacks = [
        "before_validation",
        "after_validation",
        "before_save",
        "check_halt_save",
        "before_update",
        "after_update",
        "after_save",
      ]
      CallbackTracker.order.should eq(expected_callbacks)
    end
  end
end
