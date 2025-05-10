require "../spec_helper"

describe CQL::ActiveRecord::Relations::BelongsTo do
  before_each do
    UserDB.users.create!
    UserDB.posts.create!
  end

  after_each do
    UserDB.posts.drop!
    UserDB.users.drop!
  end

  describe "belongs_to association" do
    it "returns the associated user" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post = Post.new("My Post", "Post content", user.id)
      post.create!

      associated_user = post.user
      associated_user.should_not be_nil
      associated_user = associated_user.not_nil!
      associated_user.should be_a(TestUser)
      associated_user.id.should eq(user.id)
    end

    it "sets the associated user" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post = Post.new("My Post", "Post content")
      post.user = user
      post.user_id.should eq(user.id)
    end

    it "builds a new associated user" do
      post = Post.new("My Post", "Post content")
      new_user = post.build_user(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )

      new_user.should be_a(TestUser)
      new_user.name.should eq("John Doe")
      new_user.email.should eq("john@example.com")
      new_user.id.should be_nil
    end

    it "creates a new associated user" do
      post = Post.new("My Post", "Post content")
      new_user = post.create_user(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )

      new_user.should be_a(TestUser)
      new_user.name.should eq("John Doe")
      new_user.email.should eq("john@example.com")
      new_user.id.should_not be_nil
      post.user_id.should eq(new_user.id)
    end

    it "updates the associated user" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post = Post.new("My Post", "Post content", user.id)
      post.create!

      updated_user = post.update_user(name: "John Updated")
      updated_user.name.should eq("John Updated")
      updated_user.id.should eq(user.id)
    end

    it "deletes the associated user" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post = Post.new("My Post", "Post content", user.id)
      post.create!

      post.delete_user.should be_true
      expect_raises(DB::NoResultsError) do
        TestUser.find!(user.id.not_nil!)
      end
      post.user_id.should eq(user.id)
    end

    it "returns nil when no associated user exists" do
      post = Post.new("My Post", "Post content")
      post.user.should be_nil
    end

    it "raises error when trying to access non-existent associated user" do
      post = Post.new("My Post", "Post content", 999)
      expect_raises(DB::NoResultsError) do
        post.user
      end
    end
  end
end
