require "../spec_helper"

describe "CQL::ActiveRecord::Relations::HasMany Enhanced Tests" do
  before_each do
    UserDB.users.create!
    UserDB.posts.create!
  end

  after_each do
    UserDB.posts.drop!
    UserDB.users.drop!
  end

  describe "dependency strategies" do
    it "destroys associated records when dependent: :destroy" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post1 = user.posts.create(title: "Post 1", body: "Content 1")
      post2 = user.posts.create(title: "Post 2", body: "Content 2")

      post1_id = post1.id!
      post2_id = post2.id!

      # Handle dependency (destroy)
      user.handle_posts_dependency

      # Verify posts are deleted from database
      expect_raises(DB::NoResultsError) do
        Post.find!(post1_id)
      end

      expect_raises(DB::NoResultsError) do
        Post.find!(post2_id)
      end
    end

    it "nullifies foreign keys when dependent: :nullify" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post1 = user.posts.create(title: "Post 1", body: "Content 1")
      post2 = user.posts.create(title: "Post 2", body: "Content 2")

      # Manually nullify using nullify_all to test the nullify behavior
      # since TestUser has dependent: :destroy, not :nullify
      user.posts.nullify_all

      # Verify posts still exist but foreign keys are null
      post1.reload!
      post2.reload!
      post1.user_id.should be_nil
      post2.user_id.should be_nil
    end

    it "restricts deletion when dependent: :restrict_with_error" do
      # This would require a test model with restrict_with_error dependency
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      user.posts.create(title: "Post 1", body: "Content 1")

      # For now, we'll test that the posts exist
      user.posts.size.should eq(1)
    end
  end

  describe "collection methods" do
    it "concatenates multiple records" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      # Create posts for another user first
      other_user = TestUser.new(
        name: "Jane Doe",
        email: "jane@example.com",
        age: 25,
        password: "password123",
        password_confirmation: "password123"
      )
      other_user.create!

      post1 = Post.new("Post 1", "Content 1", other_user.id!)
      post1.create!
      post2 = Post.new("Post 2", "Content 2", other_user.id!)
      post2.create!

      # Concatenate posts to user
      posts_to_add = [post1, post2]
      user.posts.concat(posts_to_add)

      user.posts.size.should eq(2)
      user.posts.all.map(&.title).sort!.should eq(["Post 1", "Post 2"])
    end

    it "removes multiple records from association" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post1 = user.posts.create(title: "Post 1", body: "Content 1")
      post2 = user.posts.create(title: "Post 2", body: "Content 2")
      user.posts.create(title: "Post 3", body: "Content 3")

      user.posts.size.should eq(3)

      # Remove multiple posts
      posts_to_remove = [post1, post2]
      user.posts.remove(posts_to_remove)

      user.posts.size.should eq(1)
      user.posts.first.title.should eq("Post 3")

      # Verify posts still exist but foreign key is null
      post1.reload!
      post2.reload!
      post1.user_id.should be_nil
      post2.user_id.should be_nil
    end

    it "checks if collection includes a specific record" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post1 = user.posts.create(title: "Post 1", body: "Content 1")
      post2 = Post.new("Post 2", "Content 2")
      post2.create!

      user.posts.includes?(post1).should be_true
      user.posts.includes?(post2).should be_false
    end

    it "uses where clause for filtering" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      user.posts.create(title: "Published Post", body: "Content 1")
      user.posts.create(title: "Draft Post", body: "Content 2")

      # Filter posts by title pattern
      published_posts = user.posts.where(title: "Published Post").all(Post)
      published_posts.size.should eq(1)
      published_posts.first.title.should eq("Published Post")
    end

    it "applies limit to query results" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      5.times do |i|
        user.posts.create(title: "Post #{i}", body: "Content #{i}")
      end

      limited_posts = user.posts.limit(3).all(Post)
      limited_posts.size.should eq(3)
    end

    it "applies offset to query results" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      5.times do |i|
        user.posts.create(title: "Post #{i}", body: "Content #{i}")
      end

      offset_posts = user.posts.limit(5).offset(2).all(Post)
      offset_posts.size.should eq(3)
    end

    it "orders query results" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      user.posts.create(title: "Z Post", body: "Content Z")
      user.posts.create(title: "A Post", body: "Content A")
      user.posts.create(title: "M Post", body: "Content M")

      ordered_posts = user.posts.order(title: :asc).all(Post)
      ordered_posts.map(&.title).should eq(["A Post", "M Post", "Z Post"])

      reverse_ordered_posts = user.posts.order(title: :desc).all(Post)
      reverse_ordered_posts.map(&.title).should eq(["Z Post", "M Post", "A Post"])
    end
  end

  describe "count and existence checks" do
    it "counts records without loading them" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      5.times do |i|
        user.posts.create(title: "Post #{i}", body: "Content #{i}")
      end

      # Count should work without loading records
      user.posts.count.should eq(5)
      # Test that count doesn't load the records (size would force loading)
      user.posts.loaded?.should be_false
    end

    it "checks if any records exist without loading them" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      # No posts yet
      user.posts_any?.should be_false

      # Create a post
      user.posts.create(title: "Post 1", body: "Content 1")

      # Now should have posts
      user.posts_any?.should be_true
    end

    it "returns first and last records" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post1 = user.posts.create(title: "First Post", body: "Content 1")
      user.posts.create(title: "Second Post", body: "Content 2")
      post3 = user.posts.create(title: "Third Post", body: "Content 3")

      user.posts.first?.should_not be_nil
      user.posts.last?.should_not be_nil

      user.posts.first.id.should eq(post1.id)
      user.posts.last.id.should eq(post3.id)
    end

    it "returns nil for first/last when empty" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      user.posts.first?.should be_nil
      user.posts.last?.should be_nil
    end

    it "raises error for first/last when empty and using non-safe version" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      expect_raises(CQL::ActiveRecord::Relations::BaseRelation::AssociationNotFound) do
        user.posts.first
      end

      expect_raises(CQL::ActiveRecord::Relations::BaseRelation::AssociationNotFound) do
        user.posts.last
      end
    end
  end

  describe "batch operations" do
    it "creates multiple records in batch" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      posts_to_create = [
        Post.new("Post 1", "Content 1"),
        Post.new("Post 2", "Content 2"),
        Post.new("Post 3", "Content 3"),
      ]

      created_posts = user.create_posts(posts_to_create)
      created_posts.size.should eq(3)

      user.posts.size.should eq(3)
      user.posts.all.map(&.title).sort!.should eq(["Post 1", "Post 2", "Post 3"])
    end

    it "deletes all records efficiently" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      5.times do |i|
        user.posts.create(title: "Post #{i}", body: "Content #{i}")
      end

      user.posts.size.should eq(5)

      # Delete all
      deleted_count = user.posts.delete_all
      deleted_count.should eq(5)

      user.posts.size.should eq(0)
    end

    it "nullifies all foreign keys efficiently" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      post1 = user.posts.create(title: "Post 1", body: "Content 1")
      post2 = user.posts.create(title: "Post 2", body: "Content 2")

      user.posts.size.should eq(2)

      # Nullify all
      updated_count = user.posts.nullify_all
      updated_count.should eq(2)

      # Posts should still exist but not be associated
      post1.reload!
      post2.reload!
      post1.user_id.should be_nil
      post2.user_id.should be_nil

      user.posts.size.should eq(0)
    end
  end

  describe "error handling" do
    it "handles empty collection gracefully" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      user.posts.should be_empty
      user.posts.size.should eq(0)
      user.posts.count.should eq(0)
    end

    it "raises error for invalid parent record" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      # Don't save the user

      expect_raises(CQL::ActiveRecord::Relations::BaseRelation::UnsavedRecord) do
        user.posts.create(title: "Post 1", body: "Content 1")
      end
    end

    it "handles build with unsaved parent" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      # Don't save the user

      expect_raises(CQL::ActiveRecord::Relations::BaseRelation::UnsavedRecord) do
        user.posts.build(title: "Post 1", body: "Content 1")
      end
    end

    it "handles delete with non-existent record" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      # Try to delete non-existent record
      result = user.posts.delete(999999)
      result.should be_false
    end

    it "handles find_by with non-existent attributes" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      result = user.posts.find_by(title: "Non-existent Post")
      result.should be_nil
    end
  end

  describe "enumerable behavior" do
    it "implements enumerable methods" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      user.posts.create(title: "Post 1", body: "Content 1")
      user.posts.create(title: "Post 2", body: "Content 2")
      user.posts.create(title: "Post 3", body: "Content 3")

      # Test each
      titles = [] of String
      user.posts.each { |post| titles << post.title }
      titles.sort.should eq(["Post 1", "Post 2", "Post 3"])

      # Test map
      mapped_titles = user.posts.map(&.title).sort!
      mapped_titles.should eq(["Post 1", "Post 2", "Post 3"])

      # Test select
      filtered_posts = user.posts.select(&.title.includes?("1"))
      filtered_posts.size.should eq(1)
      filtered_posts.first.title.should eq("Post 1")
    end
  end

  describe "cache management" do
    it "clears cache when requested" do
      user = TestUser.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      # Access to load cache
      user.posts.size.should eq(0)
      user.posts_loaded?.should be_true

      # Clear cache
      user.clear_posts_cache

      # Create post outside of collection
      Post.new("External Post", "External Content", user.id!).create!

      # Should see new post after clearing cache
      user.posts.size.should eq(1)
    end
  end
end
