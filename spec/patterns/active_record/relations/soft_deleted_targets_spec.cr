require "../spec_helper"

# A soft-deleted record keeps its id and row, so associating it links that row instead of
# inserting a copy or raising as if it were unsaved.
SoftTargetsDB = CQL::Schema.define(:soft_targets_db, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("soft_targets.db")) do
  table :soft_authors do
    primary :id, Int64, auto_increment: true
    text :name
    timestamp :deleted_at, null: true
  end

  table :soft_books do
    primary :id, Int64, auto_increment: true
    text :title
    bigint :soft_author_id, null: true
    timestamp :deleted_at, null: true
  end
end

class SoftBook
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::SoftDeletable
  db_context SoftTargetsDB, :soft_books

  property title : String = ""
  property soft_author_id : Int64?

  belongs_to :soft_author, SoftAuthor, :soft_author_id, optional: true

  validate :title, presence: true

  def initialize(@title : String = "", @soft_author_id : Int64? = nil)
  end
end

class SoftAuthor
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::SoftDeletable
  db_context SoftTargetsDB, :soft_authors

  property name : String = ""

  has_many :soft_books, SoftBook, foreign_key: :soft_author_id

  def initialize(@name : String = "")
  end
end

describe "associating saved and soft-deleted records" do
  before_each do
    SoftTargetsDB.soft_authors.create!
    SoftTargetsDB.soft_books.create!
  end

  after_each do
    SoftTargetsDB.soft_books.drop!
    SoftTargetsDB.soft_authors.drop!
  end

  describe "has_many <<" do
    it "links a saved record instead of inserting a copy of it" do
      author = SoftAuthor.create!(name: "Ada")
      book = SoftBook.create!(title: "Notes")

      author.soft_books << book

      SoftBook.count.should eq(1)
      book.id.should eq(SoftBook.find_by!(title: "Notes").id)
      SoftBook.find!(book.id!).soft_author_id.should eq(author.id)
    end

    it "links a soft-deleted record without inserting it again" do
      author = SoftAuthor.create!(name: "Ada")
      book = SoftBook.create!(title: "Draft")
      book.delete!

      author.soft_books << book

      SoftBook.with_deleted.count.should eq(1)
      SoftBook.with_deleted.find!(book.id!).soft_author_id.should eq(author.id)
      author.soft_books.size.should eq(0)
    end

    it "leaves a record already in the collection as it is" do
      author = SoftAuthor.create!(name: "Ada")
      book = SoftBook.create!(title: "Notes", soft_author_id: author.id)

      author.soft_books << book
      (author.soft_books << book).size.should eq(1)

      SoftBook.count.should eq(1)
    end

    it "moves a record from another parent" do
      ada = SoftAuthor.create!(name: "Ada")
      bob = SoftAuthor.create!(name: "Bob")
      book = SoftBook.create!(title: "Notes", soft_author_id: ada.id)

      bob.soft_books << book

      SoftBook.find!(book.id!).soft_author_id.should eq(bob.id)
      ada.soft_books.size.should eq(0)
    end

    it "validates a saved record and leaves its row alone when it is invalid" do
      author = SoftAuthor.create!(name: "Ada")
      book = SoftBook.create!(title: "Notes")
      book.title = ""

      expect_raises(CQL::RecordInvalid) { author.soft_books << book }

      SoftBook.find!(book.id!).soft_author_id.should be_nil
    end

    it "still inserts a new record" do
      author = SoftAuthor.create!(name: "Ada")

      author.soft_books << SoftBook.new(title: "Fresh")

      SoftBook.find_by!(title: "Fresh").soft_author_id.should eq(author.id)
    end
  end

  describe "create(record) and create_<name>" do
    it "link saved records instead of inserting copies" do
      author = SoftAuthor.create!(name: "Ada")
      first = SoftBook.create!(title: "One")
      second = SoftBook.create!(title: "Two")

      author.soft_books.create(first)
      author.create_soft_books([second, SoftBook.new(title: "Three")])

      SoftBook.count.should eq(3)
      SoftBook.where(soft_author_id: author.id).count.should eq(3)
    end
  end

  describe "belongs_to=" do
    it "accepts a soft-deleted parent, which still has its row" do
      author = SoftAuthor.create!(name: "Gone")
      author.delete!
      book = SoftBook.new(title: "Orphan")

      book.soft_author = author

      book.soft_author_id.should eq(author.id)
    end

    it "still rejects an unsaved parent" do
      book = SoftBook.new(title: "Orphan")

      expect_raises(CQL::ActiveRecord::Relations::BaseRelation::UnsavedRecord) do
        book.soft_author = SoftAuthor.new(name: "Unsaved")
      end
    end
  end
end
