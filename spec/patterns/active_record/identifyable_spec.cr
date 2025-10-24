require "./spec_helper"

describe CQL::ActiveRecord::Identifyable do
  describe "#id" do
    it "returns nil for a new record" do
      user = TestUser.new("Test User", "test@example.com", 25)
      user.id.should be_nil
    end

    it "returns the ID for a persisted record" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user.id.should_not be_nil
      user.id.should be_a(Int32)
    end

    it "returns the ID after setting it" do
      user = TestUser.new("Test User", "test@example.com", 25)
      user.id = 123
      user.id.should eq(123)
    end
  end

  describe "#id!" do
    it "returns the ID for a persisted record" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user.id!.should be_a(Int32)
      user.id!.should eq(user.id)
    end

    it "raises an error for a new record" do
      user = TestUser.new("Test User", "test@example.com", 25)
      expect_raises(NilAssertionError) do
        user.id!
      end
    end

    it "raises an error when ID is nil" do
      user = TestUser.new("Test User", "test@example.com", 25)
      # Note: Setting nil might not be allowed depending on the type definition
      # This test verifies the behavior when ID is not set
      expect_raises(NilAssertionError) do
        user.id!
      end
    end
  end

  describe "#id=" do
    it "sets the ID for a record" do
      user = TestUser.new("Test User", "test@example.com", 25)
      user.id = 456
      user.id.should eq(456)
    end

    it "allows setting ID to different values" do
      user = TestUser.new("Test User", "test@example.com", 25)
      user.id = 123
      user.id.should eq(123)
    end

    it "accepts different integer types" do
      user = TestUser.new("Test User", "test@example.com", 25)
      user.id = 789_i32
      user.id.should eq(789)
    end
  end

  describe "#id?" do
    it "returns nil for a new record" do
      user = TestUser.new("Test User", "test@example.com", 25)
      user.id?.should be_nil
    end

    it "returns the ID for a persisted record" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user.id?.should_not be_nil
      user.id?.should eq(user.id)
    end

    it "returns nil when ID is not set" do
      user = TestUser.new("Test User", "test@example.com", 25)
      # Note: Setting nil might not be allowed depending on the type definition
      # This test verifies the behavior when ID is not set
      user.id?.should be_nil
    end

    it "returns the ID when it's set" do
      user = TestUser.new("Test User", "test@example.com", 25)
      user.id = 999
      user.id?.should eq(999)
    end
  end

  describe "ID persistence" do
    it "maintains ID after saving a record" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      original_id = user.id

      user.name = "Updated Name"
      user.save!

      user.id.should eq(original_id)
    end

    it "assigns ID when creating a record" do
      user = TestUser.new("Test User", "test@example.com", 25)
      user.id.should be_nil

      user.create!
      user.id.should_not be_nil
    end

    it "preserves ID when reloading a record" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      original_id = user.id

      user.reload!
      user.id.should eq(original_id)
    end
  end

  describe "ID type consistency" do
    it "maintains consistent ID type throughout record lifecycle" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      id_type = user.id.class

      user.reload!
      user.id.class.should eq(id_type)

      user.name = "Updated"
      user.save!
      user.id.class.should eq(id_type)
    end
  end
end
