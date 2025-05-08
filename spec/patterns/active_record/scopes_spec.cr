require "../../spec_helper"
require "../../../src/cql"
require "sqlite3"

# Define a database module for our example
module MyApp
  DB = CQL::Schema.define(
    name: :scopes_spec_my_app,
    adapter: CQL::Adapter::SQLite,
    uri: "sqlite3://spec/support/db/scopes_spec.db") do
    table :scopes_posts do
      primary :id, Int64
      varchar :title
      varchar :body
      boolean :published
      varchar :category
      timestamps
    end
  end
end

# Define our Post model with various scopes
class ScopesPost
  include CQL::ActiveRecord::Model(Int64)

  db_context MyApp::DB, :scopes_posts

  # Define attributes
  getter id : Int64?
  getter title : String
  getter body : String
  getter published : Bool
  getter category : String
  getter created_at : Time

  # Define scopes
  scope :published, -> { where(published: true) }
  scope :recent, -> { limit(3).order(created_at: :asc) }

  scope :with_title, ->(title_param : String) do
    query.where { scopes_posts.title.like("%#{title_param}%") }
  end

  scope :by_category, ->(category : String) { where(category: category) }

  # Constructor
  def initialize(
    @title : String,
    @body : String,
    @category : String,
    @published = false,
    @created_at = Time.utc,
  )
  end
end

def setup_scopes_db
  # Setup the database
  MyApp::DB.scopes_posts.drop!
  MyApp::DB.scopes_posts.create!

  # Let's add some sample data
  posts = [
    ScopesPost.new(
      title: "No title",
      body: "No body",
      category: "fictional",
      published: false,
      created_at: Time.utc(1999, 1, 1)
    ),
    ScopesPost.new(
      title: "Getting Started with Crystal",
      body: "Crystal is a programming language...",
      category: "Programming",
      published: true,
      created_at: Time.utc(2023, 1, 1)
    ),
    ScopesPost.new("Why I love Crystal", "Crystal combines speed and readability...", "Programming", true, Time.utc(2023, 3, 15)),
    ScopesPost.new("Crystal ORM Tutorial", "Learn how to use CQL for database access...", "Tutorial", true, Time.utc(2023, 5, 20)),
    ScopesPost.new("Building APIs with Crystal", "Creating RESTful APIs is easy...", "Tutorial", false, Time.utc(2023, 6, 10)),
    ScopesPost.new("Draft: Future of Crystal", "Some thoughts on where Crystal is headed...", "Opinion", false, Time.utc(2023, 7, 1)),
  ]

  # Insert the sample posts
  posts.each(&.save)
end

describe CQL::ActiveRecord::Scopes do
  before_all do
    setup_scopes_db
  end

  after_all do
    File.delete("./scopes_spec.db") if File.exists?("./scopes_spec.db")
  end

  it "retrieves all posts" do
    ScopesPost.all.size.should eq(6)
  end

  it "retrieves published posts" do
    ScopesPost.published.count.should eq(3)
  end

  it "retrieves recent published posts" do
    posts = ScopesPost.published.recent.all
    posts.first.title.should eq("No title")
    posts.last.title.should eq("Why I love Crystal")
    posts.size.should eq(3)
  end

  it "retrieves published posts with 'Crystal' in the title" do
    ScopesPost.published.with_title("Crystal").count.should eq(5)
  end

  it "retrieves published posts with 'ORM' in the title" do
    posts = ScopesPost.published.with_title("ORM")
    post = posts.first!
    post.title.should eq("Crystal ORM Tutorial")
  end

  it "retrieves tutorial category posts" do
    ScopesPost.by_category("Tutorial").count.should eq(2)
  end

  it "retrieves recent published tutorial posts" do
    posts = ScopesPost.published.recent.by_category("Tutorial")
    post = posts.limit(1).first!
    post.title.should eq("Crystal ORM Tutorial")
    posts.count.should eq(2)
  end

  it "handles chaining of scopes" do
    # ScopesPost.published.recent.count.should eq(3)

    # Published, recent, and by category "Programming"
    programming_posts = ScopesPost.published.recent.by_category("Programming")
    all_posts = programming_posts.all
    all_posts.first.title.should eq("Getting Started with Crystal")
    programming_posts.count.should eq(2)

    # Published, with title "Crystal", and by category "Programming"
    crystal_programming_posts = ScopesPost.published.with_title("Crystal").by_category("Programming")
    all_posts = crystal_programming_posts.all
    all_posts.first.title.should eq("Getting Started with Crystal")
    crystal_programming_posts.count.should eq(2)
  end

  it "returns an empty set if no records match" do
    ScopesPost.published.by_category("NonExistentCategory").count.should eq(0)
    ScopesPost.with_title("NonExistentTitle").count.should eq(0)
  end
end
