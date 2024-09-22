require "./spec_helper"

AcmeDB = Cql::Schema.define(
  :acme_db,
  adapter: Cql::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]) do
  table :posts do
    primary :id, Int64, auto_increment: true
    text :title
    text :body
    timestamp :published_at
  end

  table :comments do
    primary
    bigint :post_id
    text :body
  end
end

struct Post < Cql::Record(Int64)
  db_context AcmeDB, :posts

  getter id : Int64?
  getter title : String
  getter body : String
  getter published_at : Time

  def initialize(@title : String, @body : String, @published_at : Time = Time.utc)
  end
end

struct Comment < Cql::Record(Int64)
  db_context AcmeDB, :comments

  getter id : Int64?
  getter post_id : Int64
  getter body : String

  def initialize(@post_id : Int64, @body : String)
  end
end

describe Cql::Record do
  AcmeDB.posts.create!
  AcmeDB.comments.create!

  before_each do
    AcmeDB.posts.create!
    AcmeDB.comments.create!
  end

  after_each do
    AcmeDB.posts.drop!
    AcmeDB.comments.drop!
  end

  describe ".build" do
    it "builds a new record" do
      post = Post.build(title: "Hello, World!", body: "This is my first post")
      post.title.should eq "Hello, World!"
      post.body.should eq "This is my first post"
    end
  end

  describe ".query" do
    it "returns a new query object" do
      query = Post.query
        .where(title: "Hello, World!")
        .limit(1)
        .order(published_at: :desc)

      query.should be_a Cql::Query
    end
  end

  describe ".all" do
    it "returns all records" do
      Post.all.should eq([] of Post)
    end
  end

  describe ".find" do
    it "finds a record by ID" do
      Post.delete_all
      post = Post.build(title: "Hello, World!", body: "This is my first post")

      post.save
      post.reload!

      Post.find(post.id).should eq post
    end
  end

  describe ".exists?" do
    it "checks if a record exists" do
      post = Post.build(title: "Hello, World!", body: "This is my first post")
      post.save
      post.reload!

      Post.exists?(id: post.id).should eq true
    end
  end

  describe ".count" do
    it "returns the number of records" do
      Post.count.should eq 0
    end
  end

  describe ".find_by" do
    it "finds a record by a column" do
      Post.delete_all
      post = Post.build(title: "Hello, World!", body: "This is my first post")
      post.save
      post.reload!

      Post.find_by(title: "Hello, World!").should eq post
    end
  end

  describe "#save" do
    it "saves a new record" do
      post = Post.build(title: "Hello, World!", body: "This is my first post")
      post.save
      post.reload!
      Post.find(post.id).should eq post
    end
  end

  describe "#update" do
    it "updates a record" do
      post = Post.build(title: "Hello, World!", body: "This is my first post")
      post.save

      post.update(title: "Hello, World!", body: "This is my first post")
      Post.find!(post.id).title.should eq "Hello, World!"
    end
  end

  describe "#delete" do
    it "deletes a record" do
      post = Post.build(title: "Hello, World!", body: "This is my first post")
      post.save
      id = post.id
      post.delete

      post.id.should eq nil
      Post.find(id).should eq nil
    end
  end
end
