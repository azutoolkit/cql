require "../../spec_helper"

# A second model on the same table whose `recent` differs from ScopesPost's
private class ScopesArchivedPost
  include CQL::ActiveRecord::Model(Int64)

  db_context MyApp::DB, :scopes_posts

  getter id : Int64?
  getter title : String
  getter published : Bool

  scope :recent, -> { order(created_at: :desc) }
  # Stands in for a query in a scope body failing with a message that quotes a value
  scope :leaky, -> { raise DB::Error.new("bad value marker-secret-42") if published_marker?; where(published: true) }

  def self.published_marker? : Bool
    true
  end

  def initialize(@title : String, @published = false)
  end
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
    posts.first.title.should eq("Getting Started with Crystal")
    posts.last.title.should eq("Crystal ORM Tutorial")
    posts.size.should eq(3)
  end

  it "retrieves published posts with 'Crystal' in the title" do
    ScopesPost.published.with_title("Crystal").count.should eq(3)
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
    posts.count.should eq(1)
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

  describe "chained after other query methods" do
    it "adds the scope's conditions once" do
      sql, params = ScopesPost.where(category: "Tutorial").published.to_sql_with_params

      sql.should end_with("FROM scopes_posts WHERE (scopes_posts.category = ?) AND (scopes_posts.published = ?)")
      params.should eq(["Tutorial", true] of DB::Any)
    end

    it "builds the same query as writing the scope's body inline" do
      ScopesPost.where(category: "Tutorial").recent.to_sql_with_params
        .should eq(ScopesPost.where(category: "Tutorial").limit(3).order(created_at: :asc).to_sql_with_params)
      ScopesPost.published.by_category("Tutorial").to_sql_with_params
        .should eq(ScopesPost.where(published: true).where(category: "Tutorial").to_sql_with_params)
    end

    it "leaves the receiver unchanged" do
      base = ScopesPost.where(category: "Tutorial")
      before = base.to_sql_with_params

      base.published.all
      base.to_sql_with_params.should eq(before)
    end

    it "rejects arguments to a scope without parameters in both forms" do
      message = "Scope 'published' expects no arguments, got 1 positional and 0 keyword arguments"
      expect_raises(ArgumentError, message) { ScopesPost.published(1) }
      expect_raises(ArgumentError, message) { ScopesPost.query.published(1) }
    end

    it "raises ArgumentError naming the scope and the error class, keeping the error as its cause" do
      error = expect_raises(ArgumentError, "Error in scope 'leaky' (DB::Error)") { ScopesArchivedPost.leaky }
      error.message.to_s.should_not contain("marker-secret-42")
      error.cause.try(&.message).should eq("bad value marker-secret-42")
    end

    it "runs the scope of the model it is chained on" do
      ScopesPost.where(published: true).recent.to_sql_with_params
        .should eq(ScopesPost.where(published: true).limit(3).order(created_at: :asc).to_sql_with_params)
      ScopesArchivedPost.where(published: true).recent.to_sql_with_params
        .should eq(ScopesArchivedPost.where(published: true).order(created_at: :desc).to_sql_with_params)
    end
  end

  describe "result types" do
    it "keeps whole-model results typed as the model when the model also plucks" do
      ScopesPost.pluck(:title, as: String).size.should eq(6)
      ScopesPost.select(:id, :title).to_a.size.should eq(6)

      typeof(ScopesPost.published.all).should eq(Array(ScopesPost))
      typeof(ScopesPost.query.published.all).should eq(Array(ScopesPost))
    end
  end

  describe CQL::ActiveRecord::Scopes::ScopeUtilities do
    it "finds scopes by their plain names" do
      CQL::ActiveRecord::Scopes::ScopeUtilities.scope_defined?(ScopesPost, "published").should be_true
      CQL::ActiveRecord::Scopes::ScopeUtilities.list_scopes(ScopesPost).should eq(["published", "recent", "with_title", "by_category"])
    end
  end
end
