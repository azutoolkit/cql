require "../spec_helper"
require "log/spec"

describe CQL::ActiveRecord::Relations::HasMany do
  before_each do
    UserDB.users.create!
    UserDB.posts.create!
  end

  after_each do
    UserDB.posts.drop!
    UserDB.users.drop!
  end

  describe "has_many association" do
    it "reads an association with dependent: :destroy without logging a deprecation warning" do
      user = TestUser.new(name: "John Doe", email: "john@example.com", age: 30, password: "password123", password_confirmation: "password123")
      user.create!

      Log.capture("*", level: :warn) do |logs|
        user.posts.size.should eq(0)
        logs.empty
      end
    end

    it "preloads an association with dependent: :destroy without logging a deprecation warning" do
      user = TestUser.new(name: "John Doe", email: "john@example.com", age: 30, password: "password123", password_confirmation: "password123")
      user.create!
      Post.create!(title: "First Post", body: "Body", user_id: user.id)

      Log.capture("*", level: :warn) do |logs|
        TestUser.preload(:posts).all.first.posts.size.should eq(1)
        logs.empty
      end
    end

    it "returns the associated posts" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post1 = Post.new(
        title: "First Post",
        body: "This is the first post",
        user_id: user.id!
      )
      post1.create!

      post2 = Post.new(
        title: "Second Post",
        body: "This is the second post",
        user_id: user.id!
      )
      post2.create!

      user_posts = user.posts
      user_posts.should be_a(CQL::ActiveRecord::Relations::Collection(Post, Int32))
      user_posts.size.should eq(2)
      user_posts.all.any? { |post| post.title == "First Post" }.should be_true
      user_posts.all.any? { |post| post.title == "Second Post" }.should be_true
    end

    it "creates a new associated post" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post = user.posts.create(
        title: "New Post",
        body: "This is a new post"
      )

      post.should be_a(Post)
      post.title.should eq("New Post")
      post.body.should eq("This is a new post")
      post.user_id.should eq(user.id)
      post.id.should_not be_nil
    end

    it "creates multiple associated posts" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      user.posts.create(
        title: "First Post",
        body: "This is the first post"
      )

      user.posts.create(
        title: "Second Post",
        body: "This is the second post"
      )

      user.posts.size.should eq(2)
      user.posts.all.any? { |post| post.title == "First Post" }.should be_true
      user.posts.all.any? { |post| post.title == "Second Post" }.should be_true
    end

    it "inserts many associated posts with one INSERT and no records" do
      user = TestUser.new(name: "John Doe", email: "john@example.com", age: 30, password: "password123", password_confirmation: "password123")
      user.create!
      user.posts.to_a.should be_empty # memoized empty collection
      rows = [{title: "First", body: "one", user_id: 999}, {title: "Second", body: "two", user_id: nil}]

      inserts = count_queries(:insert) { user.insert_posts_all(rows).should eq(2) }

      inserts.size.should eq(1)
      user.posts.map(&.title).sort!.should eq(["First", "Second"])
      Post.where(user_id: 999).count.should eq(0)
      user.insert_posts_all([{:title => "Third", :body => "three"} of Symbol => DB::Any]).should eq(1)
      user.insert_posts_all([] of Hash(Symbol, DB::Any)).should eq(0)
      user.posts.size.should eq(3)
    end

    it "refuses to insert posts for an unsaved user" do
      user = TestUser.new(name: "John Doe", email: "john@example.com", age: 30, password: "password123", password_confirmation: "password123")

      expect_raises(CQL::ActiveRecord::Relations::BaseRelation::UnsavedRecord) { user.insert_posts_all([{title: "x", body: "y"}]) }
      Post.count.should eq(0)
    end

    it "counts the foreign key toward the bind-parameter limit of each INSERT" do
      user = TestUser.new(name: "John Doe", email: "john@example.com", age: 30, password: "password123", password_confirmation: "password123")
      user.create!
      fits_without_key = Post.adapter.dialect.max_bind_params // 2 # rows bind title and body, plus user_id

      expect_raises(ArgumentError) { user.insert_posts_all([{title: "x", body: "y"}], batch_size: fits_without_key) }
      Post.count.should eq(0)
    end

    it "returns empty array when no associated posts exist" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      user.posts.should be_a(CQL::ActiveRecord::Relations::Collection(Post, Int32))
      user.posts.should be_empty
    end

    it "deletes all associated posts" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post1 = Post.new(
        title: "First Post",
        body: "This is the first post",
        user_id: user.id!
      )
      post1.create!

      post2 = Post.new(
        title: "Second Post",
        body: "This is the second post",
        user_id: user.id!
      )
      post2.create!

      user.posts.clear
      user.posts.should be_empty
    end

    it "counts associated posts" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post1 = Post.new(
        title: "First Post",
        body: "This is the first post",
        user_id: user.id!
      )
      post1.create!

      post2 = Post.new(
        title: "Second Post",
        body: "This is the second post",
        user_id: user.id!
      )
      post2.create!

      user.posts.size.should eq(2)
    end

    it "finds posts by attributes" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post1 = Post.new(
        title: "First Post",
        body: "This is the first post",
        user_id: user.id!
      )
      post1.create!

      post2 = Post.new(
        title: "Second Post",
        body: "This is the second post",
        user_id: user.id!
      )
      post2.create!

      found_posts = user.posts.find(title: "First Post")
      found_posts.size.should eq(1)
      found_posts.first.title.should eq("First Post")
    end

    it "checks if post exists by attributes" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post = Post.new(
        title: "Test Post",
        body: "This is a test post",
        user_id: user.id!
      )
      post.create!

      user.posts.exists?(title: "Test Post").should be_true
      user.posts.exists?(title: "Non-existent Post").should be_false
    end

    it "deletes a specific post" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post = Post.new(
        title: "Test Post",
        body: "This is a test post",
        user_id: user.id!
      )
      post.create!

      user.posts.delete(post)
      user.posts.size.should eq(0)
    end

    it "deletes a post by id" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post = Post.new(
        title: "Test Post",
        body: "This is a test post",
        user_id: user.id!
      )
      post.create!

      user.posts.delete(post.id.not_nil!)
      user.posts.size.should eq(0)
    end

    it "sets posts by ids" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post1 = Post.new(
        title: "First Post",
        body: "This is the first post",
        user_id: user.id!
      )
      post1.create!

      post2 = Post.new(
        title: "Second Post",
        body: "This is the second post",
        user_id: user.id!
      )
      post2.create!

      user.posts.ids = [post1.id.not_nil!, post2.id.not_nil!]
      user.posts.size.should eq(2)
      user.posts.all.map(&.id!).sort!.should eq([post1.id.not_nil!, post2.id.not_nil!].sort)
    end

    it "assigns ids with one UPDATE" do
      user = TestUser.create!(name: "Ids User", email: "ids@example.com", age: 30, password: "password123", password_confirmation: "password123")
      posts = (1..3).map { |i| Post.create!(title: "Loose #{i}", body: "b") }
      other = Post.create!(title: "Other", body: "b")

      updates = count_queries(:update) { user.posts.ids = posts.map(&.id!) }

      updates.size.should eq(1)
      user.posts.map(&.id!).sort!.should eq(posts.map(&.id!).sort!)
      Post.find!(other.id!).user_id.should be_nil
    end

    it "chunks ids so each UPDATE stays within the bind limit beside the SET value" do
      user = TestUser.create!(name: "Many Ids", email: "manyids@example.com", age: 30, password: "password123", password_confirmation: "password123")
      limit = Post.adapter.dialect.max_bind_params
      ids = (1..limit).to_a # limit ids + the SET value do not fit one statement

      updates = count_queries(:update) { user.posts.ids = ids }

      updates.size.should eq(2)
    end

    it "sends a repeated id once" do
      user = TestUser.create!(name: "Dup Ids", email: "dupids@example.com", age: 30, password: "password123", password_confirmation: "password123")
      post = Post.create!(title: "Dup", body: "b")

      updates = count_queries(:update) { user.posts.ids = [post.id!, post.id!] }

      updates.first.scan("?").size.should eq(2) # the SET value and one id
      user.posts.map(&.id!).should eq([post.id!])
    end

    it "assigns no ids without an UPDATE" do
      user = TestUser.create!(name: "No Ids", email: "noids@example.com", age: 30, password: "password123", password_confirmation: "password123")

      count_queries(:update) { user.posts.ids = [] of Int32 }.should be_empty
    end

    it "reloads posts after changes" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post = Post.new(
        title: "Test Post",
        body: "This is a test post",
        user_id: user.id!
      )
      post.create!

      user.posts.size.should eq(1)
      post.title = "Updated Post"
      post.save!

      user.posts.reload
      user.posts.all.first.title.should eq("Updated Post")
    end

    it "returns post ids" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post1 = Post.new(
        title: "First Post",
        body: "This is the first post",
        user_id: user.id!
      )
      post1.create!

      post2 = Post.new(
        title: "Second Post",
        body: "This is the second post",
        user_id: user.id!
      )
      post2.create!

      user.posts.ids.sort.should eq([post1.id.not_nil!, post2.id.not_nil!].sort)
    end
  end

  describe "memoization" do
    it "memoizes the collection instance" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      # First access creates the collection
      collection1 = user.posts
      # Second access should return the same instance
      collection2 = user.posts

      # Both variables should reference the same object
      collection1.object_id.should eq(collection2.object_id)
    end

    it "reloads the association when requested" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      # Get the initial collection
      initial_collection = user.posts

      # Create a post outside the collection's knowledge
      post = Post.new(
        title: "New Post",
        body: "This is a new post",
        user_id: user.id!
      )
      post.create!

      # Standard ORM: the collection should see the new post immediately
      user.posts.size.should eq(1)

      # Reload the association
      reloaded_collection = user.reload_posts

      # The collection should still include the new post
      reloaded_collection.size.should eq(1)
      reloaded_collection.first.title.should eq("New Post")

      # The reloaded collection should be a new object
      reloaded_collection.object_id.should_not eq(initial_collection.object_id)

      # But subsequent access should use the new memoized value
      user.posts.object_id.should eq(reloaded_collection.object_id)
    end
  end
end
