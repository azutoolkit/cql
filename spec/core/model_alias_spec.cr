require "../spec_helper"

# Test classes using the alias and full module path
class TestModelWithAlias
  include CQL::Model(Int32)

  property id : Int32?
  property name : String

  def initialize(@name : String)
  end
end

class TestWithAlias
  include CQL::Model(Int32)
  property name : String
  def initialize(@name : String); end
end

class TestWithFullPath
  include CQL::ActiveRecord::Model(Int32)
  property name : String
  def initialize(@name : String); end
end

describe "CQL::Model alias" do
  it "should be an alias for CQL::ActiveRecord::Model" do
    # Test that the alias exists and points to the correct module
    CQL::Model.should eq(CQL::ActiveRecord::Model)
  end

    it "should work when including the alias in a class" do
    # Verify the class has the expected ActiveRecord functionality
    test_instance = TestModelWithAlias.new("Test")
    test_instance.name.should eq("Test")

    # Test that ActiveRecord methods are available and functional
    test_instance.attributes.should be_a(Hash(Symbol, DB::Any))
    test_instance.valid?.should be_a(Bool)
  end

  it "should provide the same functionality as the full module path" do
    # Both should have the same methods available
    alias_instance = TestWithAlias.new("Alias Test")
    full_path_instance = TestWithFullPath.new("Full Path Test")

    # Test that both have core ActiveRecord methods working
    alias_instance.attributes.should be_a(Hash(Symbol, DB::Any))
    full_path_instance.attributes.should be_a(Hash(Symbol, DB::Any))

    alias_instance.valid?.should be_a(Bool)
    full_path_instance.valid?.should be_a(Bool)

    # Both instances should have the same name values
    alias_instance.name.should eq("Alias Test")
    full_path_instance.name.should eq("Full Path Test")
  end
end
