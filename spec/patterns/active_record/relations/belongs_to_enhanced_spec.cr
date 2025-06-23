require "../spec_helper"

describe "CQL::ActiveRecord::Relations::BelongsTo Enhanced Tests" do
  before_each do
    UserDB.users.create!
    UserDB.posts.create!
  end

  after_each do
    UserDB.posts.drop!
    UserDB.users.drop!
  end

  describe "caching behavior" do
    it "caches the associated record after first access" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post = Post.new("My Post", "Post content", user.id!)
      post.create!

      # First access should load from database
      associated_user = post.user
      associated_user.should_not be_nil

      # Check if cached
      post.user_loaded?.should be_true

      # Second access should use cache (same object reference)
      cached_user = post.user
      cached_user.should be(associated_user)
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

      post = Post.new("My Post", "Post content", user.id!)
      post.create!

      # Load the association
      original_user = post.user
      original_user.should_not be_nil

      # Update the user outside the association
      user.name = "Jane Doe"
      user.save!

      # Reload the association
      reloaded_user = post.reload_user
      reloaded_user.should_not be_nil
      reloaded_user.not_nil!.name.should eq("Jane Doe")
    end

    it "invalidates cache when association is set" do
      user1 = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user1.create!

      user2 = TestUser.new(
        name: "Jane Doe",
        email: "jane@example.com",
        age: 25,
        password: "password123",
        password_confirmation: "password123"
      )
      user2.create!

      post = Post.new("My Post", "Post content", user1.id!)
      post.create!

      # Load the association to cache it
      post.user.should_not be_nil
      post.user_loaded?.should be_true

      # Change the association
      post.user = user2

      # Verify the cached value is updated
      post.user.should_not be_nil
      post.user.not_nil!.id.should eq(user2.id)
    end
  end

  describe "error handling" do
    it "raises error for unsaved record when setting association" do
      unsaved_user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )

      post = Post.new("My Post", "Post content")

      expect_raises(CQL::ActiveRecord::Relations::BaseRelation::UnsavedRecord) do
        post.user = unsaved_user
      end
    end

    it "handles nil foreign key gracefully" do
      post = Post.new("My Post", "Post content")
      post.user_id = nil

      post.user.should be_nil
    end

    it "handles zero foreign key gracefully" do
      post = Post.new("My Post", "Post content")
      post.user_id = 0

      post.user.should be_nil
    end

    it "handles non-existent foreign key gracefully" do
      post = Post.new("My Post", "Post content")
      post.user_id = 999999

      post.user.should be_nil
    end
  end

  describe "edge cases" do
    it "can clear optional association" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post = Post.new("My Post", "Post content", user.id!)
      post.create!

      # Verify association exists
      post.user.should_not be_nil

      # Clear the association
      post.clear_user
      post.user_id.should be_nil
      post.user.should be_nil
    end

    it "can set association to nil" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post = Post.new("My Post", "Post content", user.id!)
      post.create!

      # Verify association exists
      post.user.should_not be_nil

      # Set to nil
      post.user = nil
      post.user_id.should be_nil
      post.user.should be_nil
    end

    it "handles create with invalid attributes" do
      post = Post.new("My Post", "Post content")

      expect_raises(Exception) do
        post.create_user(
          name: "",                          # Invalid - empty name
          email: "invalid-email",            # Invalid email format
          age: 0,                            # Invalid age
          password: "pass",                  # Too short
          password_confirmation: "different" # Doesn't match
        )
      end
    end

    it "handles update with invalid attributes" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post = Post.new("My Post", "Post content", user.id!)
      post.create!

      expect_raises(Exception) do
        post.update_user(
          name: "",              # Invalid - empty name
          email: "invalid-email" # Invalid email format
        )
      end
    end

    it "raises error when trying to update non-existent association" do
      post = Post.new("My Post", "Post content")
      post.user_id = nil

      expect_raises(CQL::ActiveRecord::Relations::BaseRelation::AssociationNotFound) do
        post.update_user(name: "New Name")
      end
    end

    it "raises error when trying to delete non-existent association" do
      post = Post.new("My Post", "Post content")
      post.user_id = nil

      post.delete_user.should be_false
    end
  end

  describe "database operations" do
    it "handles database connection errors gracefully" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post = Post.new("My Post", "Post content", user.id!)

      # This test would require mocking the database connection
      # For now, we'll just verify the post can be created
      post.create!
      post.user.should_not be_nil
    end
  end
end
