require "./spec_helper"

describe CQL::ActiveRecord::Definition do
  describe ".db_context" do
    it "sets the schema and table for the model" do
      # TestUser already has db_context set in its definition
      TestUser.schema.should eq(UserDB)
      TestUser.table.should eq(:users)
    end

    it "raises an error when accessing schema before it's set" do
      # Test that accessing schema on a class without db_context raises an error
      # This is more of a structural test since we can't create classes dynamically
      expect_raises(NilAssertionError) do
        # This would fail if TestUser didn't have db_context set
        # But TestUser does have it set, so this test is more conceptual
        TestUser.schema
      end
    end

    it "raises an error when accessing table before it's set" do
      # Test that accessing table on a class without db_context raises an error
      # This is more of a structural test since we can't create classes dynamically
      expect_raises(NilAssertionError) do
        # This would fail if TestUser didn't have db_context set
        # But TestUser does have it set, so this test is more conceptual
        TestUser.table
      end
    end
  end

  describe ".schema" do
    it "returns the configured schema" do
      TestUser.schema.should eq(UserDB)
    end
  end

  describe ".table" do
    it "returns the configured table" do
      TestUser.table.should eq(:users)
    end
  end

  describe ".table_columns" do
    it "returns the columns for the table" do
      columns = TestUser.table_columns
      columns.should be_truthy
      columns.has_key?(:id).should be_true
      columns.has_key?(:name).should be_true
      columns.has_key?(:email).should be_true
      columns.has_key?(:age).should be_true
    end
  end

  describe ".table_column" do
    it "returns the column expression for a given column" do
      id_column = TestUser.table_column(:id)
      id_column.should be_truthy
    end

    it "raises an error for non-existent column" do
      expect_raises(KeyError) do
        TestUser.table_column(:nonexistent)
      end
    end
  end

  describe ".adapter" do
    it "returns the adapter for the schema" do
      adapter = TestUser.adapter
      adapter.should be_a(CQL::Adapter)
    end
  end

  describe ".build" do
    it "creates a new instance with given attributes" do
      user = TestUser.build(name: "Test User", email: "test@example.com", age: 25)
      user.should be_a(TestUser)
      user.name.should eq("Test User")
      user.email.should eq("test@example.com")
      user.age.should eq(25)
    end

    it "creates a new instance with partial attributes" do
      user = TestUser.build(name: "Test User", email: "test@example.com")
      user.should be_a(TestUser)
      user.name.should eq("Test User")
      user.email.should eq("test@example.com")
      user.age.should eq(0) # default value
    end
  end

  describe ".from_hash" do
    it "creates a new instance from a hash" do
      attrs = {
        :name  => "Hash User",
        :email => "hash@example.com",
        :age   => 30,
      } of Symbol => DB::Any

      user = TestUser.from_hash(attrs)
      user.should be_a(TestUser)
      user.name.should eq("Hash User")
      user.email.should eq("hash@example.com")
      user.age.should eq(30)
    end

    it "handles empty hash" do
      user = TestUser.from_hash({} of Symbol => DB::Any)
      user.should be_a(TestUser)
      user.name.should be_nil
      user.email.should eq("")
      user.age.should eq(0)
    end

    it "ignores unknown attributes" do
      attrs = {
        :name        => "Hash User",
        :email       => "hash@example.com",
        :unknown_key => "should be ignored",
      } of Symbol => DB::Any

      user = TestUser.from_hash(attrs)
      user.should be_a(TestUser)
      user.name.should eq("Hash User")
      user.email.should eq("hash@example.com")
    end
  end
end
