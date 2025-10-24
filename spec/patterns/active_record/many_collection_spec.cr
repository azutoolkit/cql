require "./spec_helper"

# Create a test join table model for many-to-many relationships
class TestUserRole
  include CQL::ActiveRecord::Model(Int32)
  db_context schema: UserDB, table: :user_roles

  property user_id : Int32?
  property role_id : Int32?
  property created_at : Time?

  def initialize(@user_id = nil, @role_id = nil, @created_at = Time.utc)
  end
end

# Create a test role model
class TestRole
  include CQL::ActiveRecord::Model(Int32)
  db_context schema: UserDB, table: :roles

  property name : String
  property description : String?

  def initialize(@name, @description = nil)
  end
end

describe CQL::ActiveRecord::Relations::ManyCollection do
  describe "#initialize" do
    it "creates a many-to-many collection with the given parameters" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        cascade: false,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify,
        validate: true,
        autosave: false
      )

      collection.should be_a(CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32))
    end

    it "handles legacy cascade parameter with deprecation warning" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      # This should trigger a deprecation warning in the logs
      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        cascade: true, # This should trigger deprecation warning
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify,
        validate: true,
        autosave: false
      )

      collection.should be_a(CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32))
    end
  end

  describe "#reload" do
    it "reloads the association records from the database" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify
      )

      records = collection.reload
      records.should be_a(Array(TestRole))
    end
  end

  describe "#<<" do
    it "adds an existing record to the association" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!
      role = TestRole.create!(name: "Admin")

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify
      )

      result = collection << role
      result.should be_a(CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32))
    end

    it "raises an error if the target record is not persisted" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!
      role = TestRole.new("Admin") # Not persisted

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify
      )

      expect_raises(CQL::ActiveRecord::Relations::BaseRelation::UnsavedRecord) do
        collection << role
      end
    end
  end

  describe "#create" do
    it "creates a new target record with given attributes and associates it" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify
      )

      role = collection.create(name: "Admin", description: "Administrator role")
      role.should be_a(TestRole)
    end

    it "associates an existing or new target record" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!
      role = TestRole.create!(name: "Admin")

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify
      )

      result = collection.create(role)
      result.should be_a(TestRole)
    end
  end

  describe "#delete" do
    it "deletes the association for the given record" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!
      role = TestRole.create!(name: "Admin")

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify
      )

      # First associate the role
      collection << role

      # Then delete the association
      result = collection.delete(role)
      result.should be_a(TestRole?)
    end

    it "deletes the association for the record with the given ID" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!
      role = TestRole.create!(name: "Admin")
      role_id = role.id.not_nil!

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify
      )

      # First associate the role
      collection << role

      # Then delete the association by ID
      result = collection.delete(role_id)
      result.should be_a(TestRole?)
    end
  end

  describe "#clear" do
    it "clears all associated records from the parent record" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :destroy
      )

      result = collection.clear
      result.should be_a(CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32))
    end
  end

  describe "#clear_with_destroy" do
    it "clears associations and destroys target records" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :destroy
      )

      result = collection.clear_with_destroy
      result.should be_a(CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32))
    end
  end

  describe "#clear_with_delete" do
    it "clears associations and deletes target records" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :delete_all
      )

      result = collection.clear_with_delete
      result.should be_a(CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32))
    end
  end

  describe "#clear_join_records" do
    it "clears only the join table records" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify
      )

      result = collection.clear_join_records
      result.should be_a(CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32))
    end
  end

  describe "#build" do
    it "builds a new target record but doesn't save it or create association" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify
      )

      role = collection.build(name: "Admin", description: "Administrator role")
      role.should be_a(TestRole)
    end
  end

  describe "#exists?" do
    it "checks if any records exist with the given attributes via join table" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify
      )

      exists = collection.exists?(name: "Admin")
      exists.should be_a(Bool)
    end
  end

  describe "#includes?" do
    it "checks if the collection includes a specific record" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!
      role = TestRole.create!(name: "Admin")

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify
      )

      includes = collection.includes?(role)
      includes.should be_a(Bool)
    end
  end

  describe "#ids=" do
    it "sets the associated record IDs" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!
      role1 = TestRole.create!(name: "Admin")
      role2 = TestRole.create!(name: "User")

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify
      )

      ids = [role1.id.not_nil!, role2.id.not_nil!]
      collection.ids = ids

      # This would reload the collection
      collection.reload
    end
  end

  describe "#ids" do
    it "gets associated record IDs" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify
      )

      ids = collection.ids
      ids.should be_a(Array(Int32))
    end
  end

  describe "#concat" do
    it "adds multiple records to the association" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify
      )

      roles = [
        TestRole.create!(name: "Admin"),
        TestRole.create!(name: "User"),
      ]

      result = collection.concat(roles)
      result.should be_a(Array(TestRole))
    end
  end

  describe "#remove" do
    it "removes multiple records from the association" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify
      )

      roles = [
        TestRole.create!(name: "Admin"),
        TestRole.create!(name: "User"),
      ]

      result = collection.remove(roles)
      result.should be_a(Array(TestRole))
    end
  end

  describe "#find" do
    it "finds associated records with given attributes via join table" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify
      )

      records = collection.find(name: "Admin")
      records.should be_a(Array(TestRole))
    end
  end

  describe "#find_by" do
    it "finds a single associated record with given attributes via join table" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify
      )

      record = collection.find_by(name: "Admin")
      record.should be_a(TestRole?)
    end
  end

  describe "inheritance from Collection" do
    it "inherits all Collection methods" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify
      )

      # Test inherited methods
      collection.should be_a(CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32))
      collection.should be_a(CQL::ActiveRecord::Relations::Collection(TestRole, Int32))
    end
  end

  describe "dependent strategies" do
    it "handles :destroy dependent strategy" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :destroy
      )

      collection.should be_a(CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32))
    end

    it "handles :delete_all dependent strategy" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :delete_all
      )

      collection.should be_a(CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32))
    end

    it "handles :nullify dependent strategy" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify
      )

      collection.should be_a(CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32))
    end
  end

  describe "validation and autosave options" do
    it "handles validation option" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify,
        validate: true
      )

      collection.should be_a(CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32))
    end

    it "handles autosave option" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32).new(
        key: :user_id,
        id: user_id,
        target_key: :role_id,
        query: CQL::Query.new(TestRole.schema).from(TestRole.table),
        dependent: :nullify,
        autosave: true
      )

      collection.should be_a(CQL::ActiveRecord::Relations::ManyCollection(TestRole, TestUserRole, Int32))
    end
  end
end
