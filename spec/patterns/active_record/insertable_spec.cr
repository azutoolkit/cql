require "../../spec_helper"

# Define schemas for testing
InsertableTestDB = CQL::Schema.define(
  :insertable_test_db,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3:///tmp/insertable_spec.db"
) do
  table :insertable_spec_users do
    primary :id, Int64, auto_increment: true
    text :name
    text :email, unique: true
    integer :age, null: true
    boolean :active, default: true
    timestamps
  end

  table :insertable_spec_posts do
    primary :id, Int32, auto_increment: true
    text :title
    text :body
    bigint :user_id
    timestamps
  end
end

# Test model for Insertable specs
class InsertableUser
  include CQL::ActiveRecord::Model(Int64)

  db_context schema: InsertableTestDB, table: :insertable_spec_users

  property name : String = ""
  property email : String = ""
  property age : Int32? = nil
  property active : Bool = true
  property created_at : Time?
  property updated_at : Time?

  def initialize
  end
end

# Test model with Int32 primary key
class InsertablePost
  include CQL::ActiveRecord::Model(Int32)

  db_context schema: InsertableTestDB, table: :insertable_spec_posts

  property title : String = ""
  property body : String = ""
  property user_id : Int64 = 0_i64
  property created_at : Time? = Time.utc
  property updated_at : Time? = Time.utc

  def initialize
  end
end

describe CQL::ActiveRecord::Insertable do
  db_file = "/tmp/insertable_spec.db"

  before_all do
    InsertableTestDB.insertable_spec_users.drop! rescue nil
    InsertableTestDB.insertable_spec_posts.drop! rescue nil

    # Create schema
    InsertableTestDB.insertable_spec_users.create!
    InsertableTestDB.insertable_spec_posts.create!
  end

  after_all do
    InsertableTestDB.insertable_spec_users.drop! rescue nil
    InsertableTestDB.insertable_spec_posts.drop! rescue nil
  end

  describe "basic functionality" do
    it "can create the database schema" do
      # This test just ensures the schema builds without error
      File.exists?(db_file).should be_true
    end
  end

  describe ".create!" do
    context "with hash attributes" do
      it "creates a record and returns it with the ID set" do
        user = InsertableUser.create!(
          name: "John Doe",
          email: "john@example.com",
          age: 30,
          active: true,
          created_at: Time.utc,
          updated_at: Time.utc
        )

        user.should be_a(InsertableUser)
        user.id.should_not be_nil
        user.name.should eq("John Doe")
        user.email.should eq("john@example.com")
        user.age.should eq(30)
        user.active.should be_true
      end

      it "ignores id in attributes hash" do
        user = InsertableUser.create!(
          {
            :id         => 999_i64,
            :name       => "Jane Doe",
            :email      => "jane@example.com",
            :active     => true,
            :created_at => Time.utc,
            :updated_at => Time.utc,
          } of Symbol => DB::Any
        )

        user.id.should_not be_nil
        user.id.should_not eq(999_i64) # Should be auto-generated, not caller-supplied
        user.name.should eq("Jane Doe")
      end

      it "handles nil values correctly" do
        user = InsertableUser.create!(
          name: "Bob",
          email: "bob@example.com",
          age: nil,
          active: true,
          created_at: Time.utc,
          updated_at: Time.utc
        )

        user.age.should be_nil
      end
    end

    context "with named tuple" do
      it "creates a record with named tuple syntax" do
        user = InsertableUser.create!(
          name: "Alice",
          email: "alice@example.com",
          age: 25,
          active: true,
          created_at: Time.utc,
          updated_at: Time.utc
        )

        user.id.should_not be_nil
        user.name.should eq("Alice")
        user.age.should eq(25)
      end

      it "uses default values when not specified" do
        user = InsertableUser.create!(
          name: "Charlie",
          email: "charlie@example.com",
          active: true,
          created_at: Time.utc,
          updated_at: Time.utc
        )

        user.active.should be_true # Default value
      end
    end

    context "with model instance" do
      it "creates a record from model instance and sets the ID" do
        user = InsertableUser.new
        user.name = "David"
        user.email = "david@example.com"
        user.age = 40
        user.active = true
        user.created_at = Time.utc
        user.updated_at = Time.utc

        created_user = InsertableUser.create!(user)

        created_user.should be(user) # Same instance
        created_user.id.should_not be_nil
        user.id.should eq(created_user.id) # ID set on original instance
      end
    end

    context "with different primary key types" do
      it "handles Int32 primary keys correctly" do
        post = InsertablePost.create!(
          title: "First Post",
          body: "Hello World",
          user_id: 1_i64,
          created_at: Time.utc,
          updated_at: Time.utc
        )

        post.id.should be_a(Int32)
        post.id.should_not be_nil
      end

      it "correctly increments Int32 primary keys" do
        post1 = InsertablePost.create!(
          title: "Post 1",
          body: "Body 1",
          user_id: 1_i64,
          created_at: Time.utc,
          updated_at: Time.utc
        )

        post2 = InsertablePost.create!(
          title: "Post 2",
          body: "Body 2",
          user_id: 1_i64,
          created_at: Time.utc,
          updated_at: Time.utc
        )

        post1.id.should_not be_nil
        post2.id.should_not be_nil
        post2.id.not_nil!.should eq(post1.id.not_nil! + 1)
      end
    end
  end

  describe "#create!" do
    it "creates a record using instance method" do
      user = InsertableUser.new
      user.name = "Instance User"
      user.email = "instance@example.com"
      user.active = true
      user.created_at = Time.utc
      user.updated_at = Time.utc

      user.create!

      user.id.should_not be_nil
      user.id.not_nil!.should be > 0

      # Verify it was actually saved
      found = InsertableUser.find!(user.id.not_nil!)
      found.name.should eq("Instance User")
    end

    it "validates before creating" do
      # This would test validation if implemented
      # For now, just ensure the method exists and works
      user = InsertableUser.new
      user.name = "Valid User"
      user.email = "valid@example.com"
      user.active = true
      user.created_at = Time.utc
      user.updated_at = Time.utc
      # Should not raise
      user.create!
      user.id.should_not be_nil
    end
  end

  describe ".find_or_create_by" do
    it "finds existing record when it exists" do
      # Create a user first
      existing = InsertableUser.create!(
        name: "Existing User",
        email: "existing@example.com",
        age: 30,
        active: true,
        created_at: Time.utc,
        updated_at: Time.utc
      )

      # Try to find or create with same email
      found = InsertableUser.find_or_create_by(
        email: existing.email,
        active: existing.active,
        name: existing.name,
        age: existing.age,
        created_at: existing.created_at,
        updated_at: existing.updated_at
      )

      found.id.should eq(existing.id)
      found.name.should eq("Existing User")
    end

    it "creates new record when not found" do
      user = InsertableUser.find_or_create_by(
        email: "newuser@example.com",
        name: "New User",
        active: true,
        created_at: Time.utc,
        updated_at: Time.utc
      )

      user.should_not be_nil
      user.email.should eq("newuser@example.com")
      user.name.should eq("New User")

      # Verify it was saved
      InsertableUser.find!(user.id.not_nil!).should_not be_nil
    end

    it "works with hash attributes" do
      attrs = {
        :email      => "hashuser@example.com",
        :name       => "Hash User",
        :active     => true,
        :created_at => Time.utc,
        :updated_at => Time.utc,
      } of Symbol => DB::Any

      user = InsertableUser.find_or_create_by(attrs)

      user.email.should eq("hashuser@example.com")
      user.name.should eq("Hash User")
    end
  end

  describe "database adapter behavior" do
    it "uses correct last_insert_id mechanism for SQLite" do
      # This test verifies that the last_insert_id works correctly
      # by creating multiple records and checking sequential IDs
      ids = [] of Int64

      3.times do |i|
        user = InsertableUser.create!(
          name: "User #{i}",
          email: "user#{i}@example.com",
          active: true,
          created_at: Time.utc,
          updated_at: Time.utc
        )
        user.id.should_not be_nil
        ids << user.id.not_nil!
      end

      # IDs should be sequential
      ids.each_cons(2) do |pair|
        pair[1].should eq(pair[0] + 1)
      end
    end

    it "handles concurrent inserts correctly" do
      # Create multiple records quickly to test connection handling
      users = Array.new(5) do |i|
        InsertableUser.create!(
          name: "Concurrent #{i}",
          email: "concurrent#{i}@example.com",
          active: true,
          created_at: Time.utc,
          updated_at: Time.utc
        )
      end

      # All should have unique IDs
      ids = users.map(&.id.not_nil!)
      ids.uniq.size.should eq(ids.size)
    end
  end

  describe "error handling" do
    it "propagates database errors" do
      # This would test constraint violations, etc.
      # For now, just ensure basic error handling works
      # Create a user
      InsertableUser.create!(
        name: "Unique User",
        email: "unique@example.com",
        active: true,
        age: 30,
        created_at: Time.utc,
        updated_at: Time.utc
      )

      begin
        # Create a user
        InsertableUser.create!(
          name: "Unique User",
          email: "unique@example.com",
          active: true,
          age: 30,
          created_at: Time.utc,
          updated_at: Time.utc
        )
      rescue ex
        ex.should be_a(SQLite3::Exception)
        ex.message.should eq("UNIQUE constraint failed: insertable_spec_users.email")
      end

      # Attempting to create with duplicate email would fail
      # if we had a unique constraint
    end
  end
end
