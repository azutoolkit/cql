require "./spec_helper"

describe CQL::ActiveRecord::Attributes do
  describe "#attributes" do
    it "returns a hash of attributes" do
      user = TestUser.new("Test User", "test@example.com", 30, "password123", "password123")
      attrs = user.attributes

      attrs.should be_a(Hash(Symbol, DB::Any))
      attrs[:name].should eq("Test User")
      attrs[:email].should eq("test@example.com")
      attrs[:age].should eq(30)
      attrs[:password].should eq("password123")
      attrs[:id].should eq(nil)
    end

    it "includes all model properties in the returned hash" do
      user = TestUser.new("Property Test", "property@example.com", 30, "password123", "password123")
      attrs = user.attributes

      # Check that all model properties are included in the hash
      [:id, :name, :email, :age, :password].each do |property|
        attrs.has_key?(property).should be_true
      end
    end
  end

  describe "#attributes(attrs)" do
    it "sets attributes from a hash" do
      user = TestUser.new("Original", "original@example.com", 25, "password123", "password123")

      # Create a Hash directly
      new_attrs = {
        :name  => "Updated Name",
        :email => "updated@example.com",
        :age   => 35,
      } of Symbol => DB::Any

      user.attributes(new_attrs)

      user.name.should eq("Updated Name")
      user.email.should eq("updated@example.com")
      user.age.should eq(35)
    end

    it "ignores attributes that don't exist on the model" do
      user = TestUser.new("Test User", "test@example.com", 30, "password123", "password123")

      # Create a Hash directly
      attrs = {
        :name        => "New Name",
        :nonexistent => "Should be ignored",
      } of Symbol => DB::Any

      user.attributes(attrs)
      user.name.should eq("New Name")
    end

    it "ignores attributes with incorrect types" do
      user = TestUser.new("Test User", "test@example.com", 30, "password123", "password123")

      # Create a Hash directly
      attrs = {
        :name  => 123, # Wrong type (Int32 instead of String)
        :email => "valid@example.com",
      } of Symbol => DB::Any

      user.attributes(attrs)

      # Name should not be changed because of type mismatch
      user.name.should eq("Test User")
      # Email should be changed because type is correct
      user.email.should eq("valid@example.com")
    end

    it "handles nil values correctly for nullable fields" do
      user = TestUser.new("Nil Test", "nil@example.com", 30, "password123", "password123")
      user.id = 1 # Set ID to non-nil value

      attrs = {
        :id => nil,
      } of Symbol => DB::Any

      user.attributes(attrs)
      user.id.should be_nil
    end

    it "handles partial updates (only some fields)" do
      user = TestUser.new("Partial Test", "partial@example.com", 30, "password123", "password123")

      # Only update one field
      attrs = {
        :age => 40,
      } of Symbol => DB::Any

      user.attributes(attrs)

      # Updated field should change
      user.age.should eq(40)

      # Other fields should remain unchanged
      user.name.should eq("Partial Test")
      user.email.should eq("partial@example.com")
    end
  end
end
