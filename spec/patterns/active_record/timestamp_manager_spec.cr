require "../../spec_helper"
require "../../../src/cql"
require "../../../src/active_record/timestamp_manager"

# Test schema for TimestampManager
TestTimestampDB = CQL::Schema.define(
  :test_timestamp_db,
  adapter: CQL::Adapter::SQLite,
  uri: spec_sqlite_uri("timestamp_manager_spec.db")
) do
  table :articles do
    primary
    text :title
    text :content
    timestamps
  end
end

class Article
  include CQL::ActiveRecord::Model(Int64)
  db_context TestTimestampDB, :articles

  property id : Int64?
  property title : String
  property content : String
  property created_at : Time?
  property updated_at : Time?

  def initialize(@title : String, @content : String, @id : Int64? = nil, @created_at : Time? = nil, @updated_at : Time? = nil)
  end
end

describe "CQL::ActiveRecord::TimestampManager" do
  before_each do
    begin
      TestTimestampDB.articles.drop!
    rescue
      # Table doesn't exist yet, that's fine
    end
    TestTimestampDB.articles.create!
  end

  after_each do
    begin
      TestTimestampDB.articles.drop!
    rescue
      # Table doesn't exist, that's fine
    end
  end

  describe "timestamp preparation" do
    it "verifies TimestampManager module is included" do
      # Verify that Article includes the TimestampManager module
      # This is evidenced by the automatic timestamp behavior
      article = Article.new("Test", "Content")

      # Initially no timestamps
      article.created_at.should be_nil
      article.updated_at.should be_nil

      # After save, timestamps should be set
      article.save!
      article.created_at.should_not be_nil
      article.updated_at.should_not be_nil
    end

    it "handles timestamp attributes correctly" do
      article = Article.new("Test", "Content")

      # Can set attributes manually if needed using named arguments
      current_time = Time.utc
      article.attributes(
        created_at: current_time,
        updated_at: current_time
      )

      article.created_at.should_not be_nil
      article.updated_at.should_not be_nil
      article.created_at.try(&.should(be_close(current_time, 1.second)))
      article.updated_at.try(&.should(be_close(current_time, 1.second)))
    end
  end

  describe "timestamp handling in save" do
    it "automatically sets created_at and updated_at on create" do
      article = Article.new("New Article", "Fresh content")

      article.created_at.should be_nil
      article.updated_at.should be_nil

      article.save!

      article.created_at.should_not be_nil
      article.updated_at.should_not be_nil
      article.created_at.try(&.should(be_close(Time.utc, 2.seconds)))
      article.updated_at.try(&.should(be_close(Time.utc, 2.seconds)))
    end

    it "updates updated_at on update but not created_at" do
      article = Article.new("Original", "Original content")
      article.save!

      original_created_at = article.created_at
      sleep 0.1.seconds # Small delay to ensure different timestamps

      article.title = "Updated"
      article.save!

      article.created_at.should eq(original_created_at)
      article.updated_at.should_not be_nil
      if updated = article.updated_at
        if created = original_created_at
          updated.should be > created
        end
      end
    end
  end

  describe "#touch" do
    it "updates updated_at without callbacks" do
      article = Article.new("Touch Test", "Content")
      article.save!

      original_updated_at = article.updated_at
      sleep 0.1.seconds

      article.touch(:updated_at)

      article.updated_at.should_not eq(original_updated_at)
      article.updated_at.try(&.should(be_close(Time.utc, 1.second)))
    end

    it "raises error when touching unsaved record" do
      article = Article.new("Unsaved", "Content")

      expect_raises(CQL::Error, /Cannot touch on a new record/) do
        article.touch
      end
    end

    it "can touch multiple timestamp fields" do
      article = Article.new("Multi Touch", "Content")
      article.save!

      sleep 0.1.seconds
      result = article.touch(:updated_at, :created_at)

      result.should be_true
      article.updated_at.try(&.should(be_close(Time.utc, 1.second)))
    end

    it "validates timestamp columns exist" do
      article = Article.new("Invalid Touch", "Content")
      article.save!

      expect_raises(CQL::Error, /Unknown column/) do
        article.touch(:nonexistent_column)
      end
    end
  end

  describe ".touch_all" do
    it "touches multiple records at once" do
      article1 = Article.create!(title: "First", content: "Content 1")
      article2 = Article.create!(title: "Second", content: "Content 2")
      article3 = Article.create!(title: "Third", content: "Content 3")

      ids = [article1.id.not_nil!, article2.id.not_nil!, article3.id.not_nil!]
      sleep 0.1.seconds

      rows_affected = Article.touch_all(ids)

      rows_affected.should eq(3)

      # Verify records were updated
      updated1 = Article.find!(article1.id.not_nil!)
      updated2 = Article.find!(article2.id.not_nil!)
      updated3 = Article.find!(article3.id.not_nil!)

      updated1.updated_at.try(&.should(be_close(Time.utc, 2.seconds)))
      updated2.updated_at.try(&.should(be_close(Time.utc, 2.seconds)))
      updated3.updated_at.try(&.should(be_close(Time.utc, 2.seconds)))
    end

    it "returns 0 when given empty array" do
      rows_affected = Article.touch_all([] of Int64)
      rows_affected.should eq(0)
    end

    it "validates columns exist for touch_all" do
      article = Article.create!(title: "Test", content: "Content")

      expect_raises(CQL::Error, /Unknown column/) do
        Article.touch_all([article.id.not_nil!], :nonexistent)
      end
    end
  end
end
