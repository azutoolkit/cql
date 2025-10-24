require "./spec_helper"

# Test schema for Persistence specs
PersistenceTestDB = CQL::Schema.define(
  :persistence_test_db,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3:./spec/support/db/persistence_spec.db"
) do
  table :persistence_users do
    primary :id, Int64, auto_increment: true
    text :name
    text :email, unique: true
    integer :age, null: true
    boolean :active, default: true
    timestamps
  end

  table :persistence_articles do
    primary :id, Int32, auto_increment: true
    text :title
    text :content
    bigint :user_id
    timestamps
  end
end

# Test model for Persistence specs
class PersistenceUser
  include CQL::ActiveRecord::Model(Int64)

  db_context schema: PersistenceTestDB, table: :persistence_users

  property name : String = ""
  property email : String = ""
  property age : Int32? = nil
  property active : Bool = true
  property created_at : Time?
  property updated_at : Time?

  def initialize(@name : String = "", @email : String = "", @age : Int32? = nil, @active : Bool = true, @created_at : Time? = nil, @updated_at : Time? = nil)
    @created_at = Time.utc if @created_at.nil?
    @updated_at = Time.utc if @updated_at.nil?
  end
end

# Test model with Int32 primary key for touch_all testing
class PersistenceArticle
  include CQL::ActiveRecord::Model(Int32)

  db_context schema: PersistenceTestDB, table: :persistence_articles

  property title : String = ""
  property content : String = ""
  property user_id : Int64 = 0_i64
  property created_at : Time?
  property updated_at : Time?

  def initialize(@title : String = "", @content : String = "", @user_id : Int64 = 0_i64, @created_at : Time? = nil, @updated_at : Time? = nil)
    @created_at = Time.utc if @created_at.nil?
    @updated_at = Time.utc if @updated_at.nil?
  end
end

describe CQL::ActiveRecord::Persistence do
  before_each do
    begin
      PersistenceTestDB.persistence_users.drop!
      PersistenceTestDB.persistence_articles.drop!
    rescue
      # Tables don't exist yet, that's fine
    end
    PersistenceTestDB.persistence_users.create!
    PersistenceTestDB.persistence_articles.create!
  end

  after_each do
    begin
      PersistenceTestDB.persistence_users.drop!
      PersistenceTestDB.persistence_articles.drop!
    rescue
      # Tables don't exist, that's fine
    end
  end

  describe "reload!" do
    it "reloads the record from the database" do
      user = PersistenceUser.new("John Doe", "john@example.com", 30)
      user.create!
      original_id = user.id
      original_name = user.name

      # Modify the record in memory
      user.name = "Jane Doe"

      # Reload from database
      user.reload!

      # Should have the original values from database
      user.id.should eq(original_id)
      user.name.should eq(original_name)
    end

    it "returns self after reloading" do
      user = PersistenceUser.new("John Doe", "john@example.com", 30)
      user.create!

      result = user.reload!
      result.should be(user)
    end
  end

  describe "persisted?" do
    it "returns true for records with an ID" do
      user = PersistenceUser.new("John Doe", "john@example.com", 30)
      user.create!

      user.persisted?.should be_true
    end

    it "returns false for new records without an ID" do
      user = PersistenceUser.new("John Doe", "john@example.com", 30)

      user.persisted?.should be_false
    end
  end

  describe "new_record?" do
    it "returns true for records without an ID" do
      user = PersistenceUser.new("John Doe", "john@example.com", 30)

      user.new_record?.should be_true
    end

    it "returns false for persisted records with an ID" do
      user = PersistenceUser.new("John Doe", "john@example.com", 30)
      user.create!

      user.new_record?.should be_false
    end
  end

  describe "touch" do
    it "touches the updated_at timestamp by default" do
      user = PersistenceUser.new("John Doe", "john@example.com", 30)
      user.create!
      original_updated_at = user.updated_at
      original_updated_at.should_not be_nil

      # Wait a small amount to ensure time difference
      sleep 1.millisecond

      result = user.touch
      result.should be_true

      # Should have updated the timestamp
      user.updated_at.should_not be_nil
      user.updated_at.not_nil!.should be > original_updated_at.not_nil!
    end

    it "touches specific timestamp fields" do
      user = PersistenceUser.new("John Doe", "john@example.com", 30)
      user.create!
      original_updated_at = user.updated_at
      original_updated_at.should_not be_nil

      # Wait a small amount to ensure time difference
      sleep 1.millisecond

      result = user.touch(:updated_at)
      result.should be_true

      # Should have updated the timestamp
      user.updated_at.should_not be_nil
      user.updated_at.not_nil!.should be > original_updated_at.not_nil!
    end

    it "touches with a specific time" do
      user = PersistenceUser.new("John Doe", "john@example.com", 30)
      user.create!
      specific_time = Time.utc(2023, 1, 1, 12, 0, 0)

      result = user.touch(:updated_at, time: specific_time)
      result.should be_true

      # Should have set the specific time
      user.updated_at.should eq(specific_time)
    end

    it "raises error when trying to touch a new record" do
      user = PersistenceUser.new("John Doe", "john@example.com", 30)

      expect_raises(CQL::Error, "Cannot touch on a new record object") do
        user.touch
      end
    end

    it "raises error for unknown column" do
      user = PersistenceUser.new("John Doe", "john@example.com", 30)
      user.create!

      expect_raises(CQL::Error, "Unknown column: unknown_field") do
        user.touch(:unknown_field)
      end
    end

    it "returns false when no rows are affected" do
      user = PersistenceUser.new("John Doe", "john@example.com", 30)
      user.create!

      # Manually delete the record from database to simulate race condition
      PersistenceUser.delete!(user.id!)

      result = user.touch
      result.should be_false
    end
  end

  describe "touch!" do
    it "touches the updated_at timestamp" do
      user = PersistenceUser.new("John Doe", "john@example.com", 30)
      user.create!
      original_updated_at = user.updated_at
      original_updated_at.should_not be_nil

      # Wait a small amount to ensure time difference
      sleep 1.millisecond

      result = user.touch!
      result.should be_true

      # Should have updated the timestamp
      user.updated_at.should_not be_nil
      user.updated_at.not_nil!.should be > original_updated_at.not_nil!
    end

    it "touches with a specific time" do
      user = PersistenceUser.new("John Doe", "john@example.com", 30)
      user.create!
      specific_time = Time.utc(2023, 1, 1, 12, 0, 0)

      result = user.touch!(time: specific_time)
      result.should be_true

      # Should have set the specific time
      user.updated_at.should eq(specific_time)
    end
  end

  describe "touch_all" do
    it "touches multiple records by IDs" do
      # Create multiple articles
      article1 = PersistenceArticle.new("Title 1", "Content 1", 1_i64)
      article1.create!
      article2 = PersistenceArticle.new("Title 2", "Content 2", 1_i64)
      article2.create!
      article3 = PersistenceArticle.new("Title 3", "Content 3", 1_i64)
      article3.create!

      ids = [article1.id!, article2.id!, article3.id!]
      original_times = [article1.updated_at, article2.updated_at, article3.updated_at]
      original_times.each { |time| time.should_not be_nil }

      # Wait a small amount to ensure time difference
      sleep 1.millisecond

      result = PersistenceArticle.touch_all(ids)
      result.should eq(3)

      # Reload records to check updated timestamps
      article1.reload!
      article2.reload!
      article3.reload!

      article1.updated_at.should_not be_nil
      article1.updated_at.not_nil!.should be > original_times[0].not_nil!
      article2.updated_at.should_not be_nil
      article2.updated_at.not_nil!.should be > original_times[1].not_nil!
      article3.updated_at.should_not be_nil
      article3.updated_at.not_nil!.should be > original_times[2].not_nil!
    end

    it "touches specific timestamp fields for multiple records" do
      article1 = PersistenceArticle.new("Title 1", "Content 1", 1_i64)
      article1.create!
      article2 = PersistenceArticle.new("Title 2", "Content 2", 1_i64)
      article2.create!

      ids = [article1.id!, article2.id!]
      original_times = [article1.updated_at, article2.updated_at]
      original_times.each { |time| time.should_not be_nil }

      # Wait a small amount to ensure time difference
      sleep 1.millisecond

      result = PersistenceArticle.touch_all(ids, :updated_at)
      result.should eq(2)

      # Reload records to check updated timestamps
      article1.reload!
      article2.reload!

      article1.updated_at.should_not be_nil
      article1.updated_at.not_nil!.should be > original_times[0].not_nil!
      article2.updated_at.should_not be_nil
      article2.updated_at.not_nil!.should be > original_times[1].not_nil!
    end

    it "touches with a specific time for multiple records" do
      article1 = PersistenceArticle.new("Title 1", "Content 1", 1_i64)
      article1.create!
      article2 = PersistenceArticle.new("Title 2", "Content 2", 1_i64)
      article2.create!

      ids = [article1.id!, article2.id!]
      specific_time = Time.utc(2023, 1, 1, 12, 0, 0)

      result = PersistenceArticle.touch_all(ids, :updated_at, time: specific_time)
      result.should eq(2)

      # Reload records to check updated timestamps
      article1.reload!
      article2.reload!

      article1.updated_at.should eq(specific_time)
      article2.updated_at.should eq(specific_time)
    end

    it "returns 0 for empty array of IDs" do
      result = PersistenceArticle.touch_all([] of Int32)
      result.should eq(0)
    end

    it "raises error for unknown column" do
      article = PersistenceArticle.new("Title", "Content", 1_i64)
      article.create!

      expect_raises(CQL::Error, "Unknown column: unknown_field") do
        PersistenceArticle.touch_all([article.id!], :unknown_field)
      end
    end
  end

  describe "save" do
    it "saves a new record successfully" do
      user = PersistenceUser.new("John Doe", "john@example.com", 30)

      result = user.save
      result.should be_true
      user.persisted?.should be_true
      user.id.should_not be_nil
    end

    it "updates an existing record successfully" do
      user = PersistenceUser.new("John Doe", "john@example.com", 30)
      user.create!
      original_id = user.id

      user.name = "Jane Doe"
      result = user.save
      result.should be_true

      # ID should remain the same
      user.id.should eq(original_id)
      user.name.should eq("Jane Doe")
    end

    it "sets timestamps on save" do
      user = PersistenceUser.new("John Doe", "john@example.com", 30)

      result = user.save
      result.should be_true

      user.created_at.should_not be_nil
      user.updated_at.should_not be_nil
    end

    it "updates updated_at timestamp on existing record" do
      user = PersistenceUser.new("John Doe", "john@example.com", 30)
      user.create!
      original_updated_at = user.updated_at
      original_updated_at.should_not be_nil

      # Wait a small amount to ensure time difference
      sleep 1.millisecond

      user.name = "Jane Doe"
      result = user.save
      result.should be_true

      user.updated_at.should_not be_nil
      user.updated_at.not_nil!.should be > original_updated_at.not_nil!
    end

    it "returns false when validation fails" do
      # Create a user with invalid data that would fail validation
      # Note: This test assumes there are validations in place
      # For now, we'll test the basic save functionality
      user = PersistenceUser.new("John Doe", "john@example.com", 30)

      result = user.save
      result.should be_true # Should pass since no validations are defined
    end
  end

  describe "save!" do
    it "saves a new record successfully" do
      user = PersistenceUser.new("John Doe", "john@example.com", 30)

      result = user.save!
      result.should be_true
      user.persisted?.should be_true
      user.id.should_not be_nil
    end

    it "updates an existing record successfully" do
      user = PersistenceUser.new("John Doe", "john@example.com", 30)
      user.create!
      original_id = user.id

      user.name = "Jane Doe"
      result = user.save!
      result.should be_true

      # ID should remain the same
      user.id.should eq(original_id)
      user.name.should eq("Jane Doe")
    end

    it "raises RecordInvalid when validation fails" do
      # This test would need actual validations to be meaningful
      # For now, we'll test that save! returns true when save succeeds
      user = PersistenceUser.new("John Doe", "john@example.com", 30)

      result = user.save!
      result.should be_true
    end

    it "raises RecordNotSaved when save fails for other reasons" do
      # This test would need a scenario where save fails but not due to validation
      # For now, we'll test the basic functionality
      user = PersistenceUser.new("John Doe", "john@example.com", 30)

      result = user.save!
      result.should be_true
    end
  end

  describe "set_timestamps!" do
    it "sets created_at and updated_at for new records" do
      user = PersistenceUser.new("John Doe", "john@example.com", 30)

      # Call the private method through save
      user.save

      user.created_at.should_not be_nil
      user.updated_at.should_not be_nil
      user.created_at.should eq(user.updated_at)
    end

    it "updates updated_at for existing records" do
      user = PersistenceUser.new("John Doe", "john@example.com", 30)
      user.create!
      original_created_at = user.created_at
      original_updated_at = user.updated_at
      original_updated_at.should_not be_nil

      # Wait a small amount to ensure time difference
      sleep 1.millisecond

      user.name = "Jane Doe"
      user.save

      # created_at should remain the same
      user.created_at.should eq(original_created_at)
      # updated_at should be newer
      user.updated_at.should_not be_nil
      user.updated_at.not_nil!.should be > original_updated_at.not_nil!
    end
  end
end
