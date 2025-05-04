require "../spec_helper"

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
        user_id: user.id
      )
      post1.create!

      post2 = Post.new(
        title: "Second Post",
        body: "This is the second post",
        user_id: user.id
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
        user_id: user.id
      )
      post1.create!

      post2 = Post.new(
        title: "Second Post",
        body: "This is the second post",
        user_id: user.id
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
        user_id: user.id
      )
      post1.create!

      post2 = Post.new(
        title: "Second Post",
        body: "This is the second post",
        user_id: user.id
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
        user_id: user.id
      )
      post1.create!

      post2 = Post.new(
        title: "Second Post",
        body: "This is the second post",
        user_id: user.id
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
        user_id: user.id
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
        user_id: user.id
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
        user_id: user.id
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
        user_id: user.id
      )
      post1.create!

      post2 = Post.new(
        title: "Second Post",
        body: "This is the second post",
        user_id: user.id
      )
      post2.create!

      user.posts.ids = [post1.id.not_nil!, post2.id.not_nil!]
      user.posts.size.should eq(2)
      user.posts.all.map(&.id!).sort!.should eq([post1.id.not_nil!, post2.id.not_nil!].sort)
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
        user_id: user.id
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
        user_id: user.id
      )
      post1.create!

      post2 = Post.new(
        title: "Second Post",
        body: "This is the second post",
        user_id: user.id
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
        user_id: user.id
      )
      post.create!

      # The collection should not see the new post yet
      user.posts.size.should eq(0)

      # Reload the association
      reloaded_collection = user.reload_posts

      # The collection should now include the new post
      reloaded_collection.size.should eq(1)
      reloaded_collection.first.title.should eq("New Post")

      # The reloaded collection should be a new object
      reloaded_collection.object_id.should_not eq(initial_collection.object_id)

      # But subsequent access should use the new memoized value
      user.posts.object_id.should eq(reloaded_collection.object_id)
    end
  end
end
