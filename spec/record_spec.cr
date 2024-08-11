require "./spec_helper"

AcmeDB = Cql::Schema.build(
  :acme_db,
  adapter: Cql::Adapter::Postgres,
  uri: "postgresql://example:example@localhost:5432/example") do
  table :posts do
    primary
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

struct Post
  include DB::Serializable
  include Cql::Record(Post)

  define AcmeDB, :posts

  getter id : Int64?
  getter title : String
  getter body : String
  getter published_at : Time

  def initialize(@title : String, @body : String, @published_at : Time = Time.utc)
  end

  def attributes
    hash = Hash(Symbol, DB::Any).new
    {% for ivar in @type.instance_vars %}
    hash[:{{ ivar }}] = {{ ivar }}
    {% end %}
    hash
  end
end

struct Comment
  include DB::Serializable
  include Cql::Record(Comment)
  define AcmeDB, :comments

  getter id : Int64?
  getter post_id : Int64
  getter body : String

  def initialize(@post_id : Int64, @body : String)
  end

  def attributes
    hash = Hash(Symbol, DB::Any).new
    {% for ivar in @type.instance_vars %}
    hash[:{{ ivar }}] = {{ ivar }}
    {% end %}
    hash
  end
end

describe Cql::Record do
  AcmeDB.posts.create!
  AcmeDB.comments.create!

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
      post = Post.build(title: "Hello, World!", body: "This is my first post")
      post.save

      Post.find(post.id).should eq post
    end
  end
end
