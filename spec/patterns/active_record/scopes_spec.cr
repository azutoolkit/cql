require "../../spec_helper"

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
