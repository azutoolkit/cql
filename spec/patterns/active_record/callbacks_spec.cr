require "./spec_helper"

describe CQL::ActiveRecord::Callbacks do
  before_each do
    UserDB.users.create!
    CallbackTracker.clear
  end

  after_each do
    UserDB.users.drop!
  end

  describe "callback registration and execution" do
    it "runs validation callbacks in the correct order" do
      model = TestUser.new(
        name: "Test Model",
        email: "test@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      model.run_callbacks(:before_validation)
      model.run_callbacks(:after_validation)

      CallbackTracker.order.should eq(["before_validation", "after_validation"])
    end
  end

  describe "callback chain halting" do
    it "doesn't halt the chain when callbacks return true" do
      model = TestUser.new(
        name: "Test Model",
        email: "test@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )

      result = model.save!

      result.should be_true
      CallbackTracker.included?("after_save").should be_true
    end
  end

  describe "create operation" do
    it "runs callbacks in the correct order for create" do
      model = TestUser.new(
        name: "Test Model",
        email: "test@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      model.save!

      expected_order = [
        "before_validation",
        "after_validation",
        "before_save",
        "check_halt_save",
        "before_create",
        "after_create",
        "after_save",
      ]

      CallbackTracker.order.should eq(expected_order)
    end

    it "sets the ID when create is successful" do
      model = TestUser.new(
        name: "Test Model",
        email: "test@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      model.create!

      model.id.should_not be_nil
    end
  end

  describe "update operation" do
    it "runs callbacks in the correct order for update" do
      model = TestUser.new(
        name: "Test Model",
        email: "test@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      model.save!

      CallbackTracker.clear
      model.name = "Updated Model"
      model.save!

      expected_order = [
        "before_validation",
        "after_validation",
        "before_save",
        "check_halt_save",
        "before_update",
        "after_update",
        "after_save",
      ]

      CallbackTracker.order.should eq(expected_order)
    end
  end

  describe "destroy operation" do
    it "runs callbacks in the correct order for destroy" do
      model = TestUser.new(
        name: "Test Model",
        email: "test@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      model.create!

      CallbackTracker.clear
      model.delete!

      expected_order = [
        "before_destroy",
        "check_halt_destroy",
        "after_destroy",
      ]

      CallbackTracker.order.should eq(expected_order)
    end
  end
end
