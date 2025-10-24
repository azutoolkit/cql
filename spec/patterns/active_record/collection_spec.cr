require "./spec_helper"

describe CQL::ActiveRecord::Relations::Collection do
  describe "#initialize" do
    it "creates a collection with the given parameters" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        cascade: false,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false,
        dependent: :nullify
      )

      collection.should be_a(CQL::ActiveRecord::Relations::Collection(TestUser, Int32))
    end

    it "handles legacy cascade parameter with deprecation warning" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      # This should trigger a deprecation warning in the logs
      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        cascade: true, # This should trigger deprecation warning
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false,
        dependent: :nullify
      )

      collection.should be_a(CQL::ActiveRecord::Relations::Collection(TestUser, Int32))
    end

    it "auto-loads records when auto_load is true" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      # Create some associated records
      TestUser.create!(name: "Associated User 1", email: "assoc1@example.com", age: 30)
      TestUser.create!(name: "Associated User 2", email: "assoc2@example.com", age: 35)

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        cascade: false,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: true,
        dependent: :nullify
      )

      collection.should be_a(CQL::ActiveRecord::Relations::Collection(TestUser, Int32))
    end
  end

  describe "#each" do
    it "implements the each method for Enumerable" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      count = 0
      collection.each do |record|
        count += 1
        record.should be_a(TestUser)
      end

      count.should eq(0) # No associated records yet
    end
  end

  describe "#all" do
    it "returns all associated records" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      records = collection.all
      records.should be_a(Array(TestUser))
    end

    it "returns records of specified type" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      records = collection.all(TestUser)
      records.should be_a(Array(TestUser))
    end
  end

  describe "#reload" do
    it "reloads the association records from the database" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      records = collection.reload
      records.should be_a(Array(TestUser))
    end
  end

  describe "#loaded?" do
    it "checks if the collection has been loaded" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      collection.loaded?.should be_false

      collection.reload
      collection.loaded?.should be_true
    end
  end

  describe "#ids" do
    it "returns a list of primary keys for the associated records" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      ids = collection.ids
      ids.should be_a(Array(Int32))
    end
  end

  describe "#<<" do
    it "adds a record to the collection and saves it" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      new_record = TestUser.new("New User", "new@example.com", 30)
      result = collection << new_record

      result.should be_a(Array(TestUser))
    end
  end

  describe "#empty?" do
    it "checks if the collection is empty" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      collection.empty?.should be_true
    end
  end

  describe "#exists?" do
    it "checks if any records exist with the given attributes" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      exists = collection.exists?(name: "Test User")
      exists.should be_a(Bool)
    end
  end

  describe "#first?" do
    it "returns the first record in the collection" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      first = collection.first?
      first.should be_a(TestUser?)
    end
  end

  describe "#first" do
    it "returns the first record in the collection, raises if none found" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      expect_raises(CQL::ActiveRecord::Relations::BaseRelation::AssociationNotFound) do
        collection.first
      end
    end
  end

  describe "#last?" do
    it "returns the last record in the collection" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      last = collection.last?
      last.should be_a(TestUser?)
    end
  end

  describe "#last" do
    it "returns the last record in the collection, raises if none found" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      expect_raises(CQL::ActiveRecord::Relations::BaseRelation::AssociationNotFound) do
        collection.last
      end
    end
  end

  describe "#size" do
    it "returns the number of associated records" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      size = collection.size
      size.should be_a(Int32)
    end
  end

  describe "#count" do
    it "counts records directly from database without loading" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      count = collection.count
      count.should be_a(Int64)
    end
  end

  describe "#find" do
    it "finds associated records matching the given attributes" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      records = collection.find(name: "Test User")
      records.should be_a(Array(TestUser))
    end
  end

  describe "#find_by" do
    it "finds a single record by attributes" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      record = collection.find_by(name: "Test User")
      record.should be_a(TestUser?)
    end
  end

  describe "#build" do
    it "creates a new, unsaved record with the parent association set" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      record = collection.build(name: "New User", email: "new@example.com", age: 30)
      record.should be_a(TestUser)
    end
  end

  describe "#create" do
    it "creates a new record with the given attributes and saves it" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      record = collection.create(name: "New User", email: "new@example.com", age: 30)
      record.should be_a(TestUser)
    end

    it "creates and associates an existing record" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      existing_record = TestUser.create!(name: "Existing User", email: "existing@example.com", age: 35)
      result = collection.create(existing_record)
      result.should be_a(TestUser)
    end
  end

  describe "#delete" do
    it "deletes the associated record from the parent record" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      record = TestUser.create!(name: "To Delete", email: "delete@example.com", age: 30)
      result = collection.delete(record)
      result.should be_a(Bool)
    end

    it "deletes the associated record by ID" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      record = TestUser.create!(name: "To Delete", email: "delete@example.com", age: 30)
      record_id = record.id.not_nil!
      result = collection.delete(record_id)
      result.should be_a(Bool)
    end
  end

  describe "#delete_all" do
    it "deletes all associated records" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      result = collection.delete_all
      result.should be_a(Int64)
    end
  end

  describe "#nullify_all" do
    it "sets all foreign keys to nil" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      result = collection.nullify_all
      result.should be_a(Int64)
    end
  end

  describe "#ids=" do
    it "associates the parent record with the records that match the primary keys" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      record1 = TestUser.create!(name: "Record 1", email: "record1@example.com", age: 30)
      record2 = TestUser.create!(name: "Record 2", email: "record2@example.com", age: 35)

      ids = [record1.id.not_nil!, record2.id.not_nil!]
      collection.ids = ids

      # This would reload the collection
      collection.reload
    end
  end

  describe "#where" do
    it "returns a new query for chaining where conditions" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      query = collection.where(name: "Test User")
      query.should be_a(CQL::Query)
    end
  end

  describe "#limit" do
    it "applies a limit to the query" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      query = collection.limit(5)
      query.should be_a(CQL::Query)
    end
  end

  describe "#offset" do
    it "applies an offset to the query" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      query = collection.offset(10)
      query.should be_a(CQL::Query)
    end
  end

  describe "#order" do
    it "orders the query results" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      query = collection.order(name: :asc)
      query.should be_a(CQL::Query)
    end
  end

  describe "#clear" do
    it "clears all associated records from the parent record" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false,
        dependent: :destroy
      )

      result = collection.clear
      result.should be_a(Int64)
    end
  end

  describe "#includes?" do
    it "checks if the collection includes a specific record" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      record = TestUser.create!(name: "Test Record", email: "test@example.com", age: 30)
      includes = collection.includes?(record)
      includes.should be_a(Bool)
    end
  end

  describe "Enumerable methods" do
    it "implements map method" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      names = collection.map(&.name)
      names.should be_a(Array(String?))
    end

    it "implements select method" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      selected = collection.select { |record| record.age > 20 }
      selected.should be_a(Array(TestUser))
    end

    it "implements reject method" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      rejected = collection.reject { |record| record.age < 20 }
      rejected.should be_a(Array(TestUser))
    end

    it "implements find method" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      found = collection.find { |record| record.name == "Test User" }
      found.should be_a(TestUser?)
    end

    it "implements any? method" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      any = collection.any? { |record| record.age > 20 }
      any.should be_a(Bool)
    end

    it "implements all? method" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      all = collection.all? { |record| record.age > 20 }
      all.should be_a(Bool)
    end
  end

  describe "#[]" do
    it "gets element at index, returns nil if out of bounds" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      element = collection[0]?
      element.should be_a(TestUser?)
    end

    it "gets element at index, raises if out of bounds" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      expect_raises(IndexError) do
        collection[0]
      end
    end
  end

  describe "#to_a" do
    it "converts to array" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      array = collection.to_a
      array.should be_a(Array(TestUser))
    end
  end

  describe "#each_with_index" do
    it "each with index" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      count = 0
      collection.each_with_index do |record, index|
        count += 1
        index.should be_a(Int32)
        record.should be_a(TestUser)
      end

      count.should eq(0) # No records in collection
    end
  end

  describe "#map_with_index" do
    it "map with index" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      result = collection.map_with_index { |record, index| "#{index}: #{record.name}" }
      result.should be_a(Array(String))
    end
  end

  describe "#length" do
    it "gets the length/size of the collection" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      length = collection.length
      length.should be_a(Int32)
    end
  end

  describe "#concat" do
    it "adds multiple records to the collection" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      records = [
        TestUser.new("User 1", "user1@example.com", 30),
        TestUser.new("User 2", "user2@example.com", 35),
      ]

      result = collection.concat(records)
      result.should be_a(Array(TestUser))
    end
  end

  describe "#remove" do
    it "removes records from the collection without deleting them" do
      user = TestUser.create!(name: "Test User", email: "test@example.com", age: 25)
      user_id = user.id.not_nil!

      collection = CQL::ActiveRecord::Relations::Collection(TestUser, Int32).new(
        key: :user_id,
        id: user_id,
        query: CQL::Query.new(TestUser.schema).from(TestUser.table),
        auto_load: false
      )

      records = [
        TestUser.create!(name: "User 1", email: "user1@example.com", age: 30),
        TestUser.create!(name: "User 2", email: "user2@example.com", age: 35),
      ]

      result = collection.remove(records)
      result.should be_a(Array(TestUser))
    end
  end
end
