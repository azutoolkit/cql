require "../spec_helper"

def has_many_isolation_user(name : String, email : String) : TestUser
  TestUser.create!(name: name, email: email, age: 30, password: "password123", password_confirmation: "password123")
end

def has_many_isolation_selects(& : ->) : Array(String)
  statements = [] of String
  CQL::Telemetry.subscribe("has_many_isolation") do |event|
    statements << event.sql if event.operation == :select
  end
  begin
    yield
  ensure
    CQL::Telemetry.unsubscribe("has_many_isolation")
  end
  statements
end

# Owners of the `users` rows, one per `dependent:` strategy (TestUser covers :destroy); create the
# rows with TestUser and load them through these models.
class DeleteAllPostsOwner
  include CQL::ActiveRecord::Model(Int32)
  db_context schema: UserDB, table: :users

  property email : String

  has_many :posts, Post, foreign_key: :user_id, dependent: :delete_all
end

class NullifyPostsOwner
  include CQL::ActiveRecord::Model(Int32)
  db_context schema: UserDB, table: :users

  property email : String

  has_many :posts, Post, foreign_key: :user_id, dependent: :nullify
end

class RestrictPostsOwner
  include CQL::ActiveRecord::Model(Int32)
  db_context schema: UserDB, table: :users

  property email : String

  has_many :posts, Post, foreign_key: :user_id, dependent: :restrict_with_error
end

# Declares a destroying association before a restricting one over the same posts.
class DestroyThenRestrictPostsOwner
  include CQL::ActiveRecord::Model(Int32)
  db_context schema: UserDB, table: :users

  property email : String

  has_many :posts, Post, foreign_key: :user_id, dependent: :destroy
  has_many :kept_posts, Post, foreign_key: :user_id, dependent: :restrict_with_error
end

# A post whose before_destroy halts its delete while it is titled "Keep".
class GuardedPost
  include CQL::ActiveRecord::Model(Int32)
  db_context schema: UserDB, table: :posts

  property title : String
  property body : String
  property user_id : Int32?

  before_destroy :deletable?

  def initialize(@title, @body, @user_id = nil)
  end

  def deletable?
    title != "Keep"
  end
end

class GuardedPostsOwner
  include CQL::ActiveRecord::Model(Int32)
  db_context schema: UserDB, table: :users

  property email : String

  has_many :posts, GuardedPost, foreign_key: :user_id, dependent: :destroy
end

# A struct model, so delete! and the strategies run on a value type.
struct StructPostsOwner
  include CQL::ActiveRecord::Model(Int32)
  db_context schema: UserDB, table: :users

  property email : String

  has_many :posts, Post, foreign_key: :user_id, dependent: :destroy
end

class UndeclaredPostsOwner
  include CQL::ActiveRecord::Model(Int32)
  db_context schema: UserDB, table: :users

  property email : String

  has_many :posts, Post, foreign_key: :user_id
end

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
  end

  describe "dependent strategies when the parent is deleted" do
    it "destroys the posts with dependent: :destroy, even when they were never loaded" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      post_ids = (1..2).map { |i| user.posts.create(title: "Post #{i}", body: "Content").id! }

      TestUser.find!(user.id!).delete!.should be_true

      post_ids.each { |id| Post.find?(id).should be_nil }
    end

    it "destroys posts created after the collection was loaded" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      user.posts.size.should eq(0)
      post = Post.new("Late post", "Content", user.id!)
      post.create!

      user.delete!.should be_true

      Post.find?(post.id!).should be_nil
    end

    it "deletes the posts with dependent: :delete_all" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      post_ids = (1..2).map { |i| user.posts.create(title: "Post #{i}", body: "Content").id! }

      DeleteAllPostsOwner.find!(user.id!).delete!.should be_true

      post_ids.each { |id| Post.find?(id).should be_nil }
      TestUser.find?(user.id!).should be_nil
    end

    it "keeps the posts and clears their foreign key with dependent: :nullify" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      post = user.posts.create(title: "Post 1", body: "Content")

      NullifyPostsOwner.find!(user.id!).delete!.should be_true

      post.reload!.user_id.should be_nil
      TestUser.find?(user.id!).should be_nil
    end

    it "raises and deletes nothing with dependent: :restrict_with_error while posts exist" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      post = user.posts.create(title: "Post 1", body: "Content")

      expect_raises(CQL::ActiveRecord::Relations::BaseRelation::RelationError, "Cannot delete record because dependent posts exist") do
        RestrictPostsOwner.find!(user.id!).delete!
      end

      TestUser.find?(user.id!).should_not be_nil
      post.reload!.user_id.should eq(user.id)
    end

    it "deletes a parent without posts with dependent: :restrict_with_error" do
      user = has_many_isolation_user("John Doe", "john@example.com")

      RestrictPostsOwner.find!(user.id!).delete!.should be_true

      TestUser.find?(user.id!).should be_nil
    end

    it "checks restrictions before any other strategy runs" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      post = user.posts.create(title: "Post 1", body: "Content")

      expect_raises(CQL::ActiveRecord::Relations::BaseRelation::RelationError) do
        DestroyThenRestrictPostsOwner.find!(user.id!).delete!
      end

      Post.find?(post.id!).should_not be_nil
      TestUser.find?(user.id!).should_not be_nil
    end

    it "rolls back every deleted post when another post's delete is halted" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      deletable = user.posts.create(title: "Delete me", body: "Content")
      kept = user.posts.create(title: "Keep", body: "Content")

      expect_raises(CQL::ActiveRecord::Relations::BaseRelation::RelationError, "Cannot delete record because dependent posts could not be deleted") do
        GuardedPostsOwner.find!(user.id!).delete!
      end

      Post.find?(deletable.id!).should_not be_nil
      Post.find?(kept.id!).should_not be_nil
      TestUser.find?(user.id!).should_not be_nil
    end

    it "deletes nothing through delete_all when one of the parents is restricted" do
      free = has_many_isolation_user("Free User", "free@example.com")
      restricted = has_many_isolation_user("Restricted User", "restricted@example.com")
      restricted.posts.create(title: "Post 1", body: "Content")

      expect_raises(CQL::ActiveRecord::Relations::BaseRelation::RelationError) do
        RestrictPostsOwner.query.delete_all
      end

      TestUser.find?(free.id!).should_not be_nil
      TestUser.find?(restricted.id!).should_not be_nil
    end

    it "applies the strategy on a struct model" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      post = user.posts.create(title: "Post 1", body: "Content")
      owner = StructPostsOwner.find!(user.id!)

      owner.delete!.should be_true

      owner.destroyed?.should be_true
      Post.find?(post.id!).should be_nil
      TestUser.find?(user.id!).should be_nil
    end

    it "leaves the posts alone when dependent: is not declared" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      post = user.posts.create(title: "Post 1", body: "Content")

      UndeclaredPostsOwner.find!(user.id!).delete!.should be_true

      post.reload!.user_id.should eq(user.id)
    end

    it "applies the strategy through delete_all on a query" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      other = has_many_isolation_user("Jane Doe", "jane@example.com")
      post = user.posts.create(title: "Mine", body: "Content")
      other_post = other.posts.create(title: "Theirs", body: "Content")

      NullifyPostsOwner.where(id: user.id!).delete_all.should eq(1)

      post.reload!.user_id.should be_nil
      other_post.reload!.user_id.should eq(other.id)
    end

    it "runs inside the caller's open transaction" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      post = user.posts.create(title: "Post 1", body: "Content")

      UserDB.transaction do |tx|
        TestUser.find!(user.id!).delete!.should be_true
        Post.find?(post.id!).should be_nil
        tx.rollback
      end

      TestUser.find?(user.id!).should_not be_nil
      Post.find?(post.id!).should_not be_nil
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

  describe "shared query isolation" do
    it "keeps the foreign key predicate single across repeated reloads" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      3.times { |i| user.posts.create(title: "Post #{i}", body: "Content #{i}") }

      statements = has_many_isolation_selects do
        posts = user.posts
        posts.reload
        posts.reload
      end

      statements.size.should eq(2)
      statements.last.scan("user_id = ?").size.should eq(1)
      statements.last.should_not contain("COUNT(")
    end

    it "counts and then reloads full records without a leftover COUNT query" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      3.times { |i| user.posts.create(title: "Post #{i}", body: "Content #{i}") }

      posts = user.posts
      statements = has_many_isolation_selects do
        posts.count.should eq(3)
        posts.reload.map(&.title).sort!.should eq(["Post 0", "Post 1", "Post 2"])
        posts.count.should eq(3)
        posts.reload
      end

      posts.size.should eq(3)
      statements.last.should_not contain("COUNT(")
      statements.last.scan("user_id = ?").size.should eq(1)
    end

    it "leaves the collection unchanged after limit, offset and order chains" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      3.times { |i| user.posts.create(title: "Post #{i}", body: "Content #{i}") }

      posts = user.posts
      posts.limit(1).all(Post).size.should eq(1)
      posts.offset(1).all(Post).size.should eq(2)
      posts.order(title: :desc).all(Post).first.title.should eq("Post 2")

      posts.reload.map(&.title).sort!.should eq(["Post 0", "Post 1", "Post 2"])
    end

    it "keeps the foreign key predicate single after where, find and find_by calls" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      3.times { |i| user.posts.create(title: "Post #{i}", body: "Content #{i}") }

      posts = user.posts
      statements = has_many_isolation_selects do
        posts.where(title: "Post 0").all(Post).size.should eq(1)
        posts.find(title: "Post 1").map(&.title).should eq(["Post 1"])
        posts.find_by(title: "Post 2").try(&.title).should eq("Post 2")
        posts.where(title: "Post 0").all(Post).size.should eq(1)
      end

      statements.size.should eq(4)
      statements.map(&.scan("user_id = ?").size).should eq([1, 1, 1, 1])
      posts.reload.size.should eq(3)
    end

    it "counts twice on an unloaded collection and then loads full records" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      3.times { |i| user.posts.create(title: "Post #{i}", body: "Content #{i}") }

      posts = user.posts
      statements = has_many_isolation_selects do
        posts.count.should eq(3)
        posts.count.should eq(3)
        posts.to_a.map(&.title).sort!.should eq(["Post 0", "Post 1", "Post 2"])
      end

      posts.loaded?.should be_true
      statements.last.should_not contain("COUNT(")
      statements.last.scan("user_id = ?").size.should eq(1)
    end

    it "scopes reload to the parent even when given an unscoped query" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      other = has_many_isolation_user("Jane Doe", "jane@example.com")
      2.times { |i| user.posts.create(title: "Mine #{i}", body: "Content") }
      3.times { |i| other.posts.create(title: "Theirs #{i}", body: "Content") }

      posts = CQL::ActiveRecord::Relations::Collection(Post, Int32).new(
        key: :user_id,
        id: user.id!,
        query: CQL::Query.new(Post.schema).from(Post.table)
      )

      posts.reload.map(&.title).sort!.should eq(["Mine 0", "Mine 1"])
    end

    it "scopes count to the parent even when given an unscoped query" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      other = has_many_isolation_user("Jane Doe", "jane@example.com")
      2.times { |i| user.posts.create(title: "Mine #{i}", body: "Content") }
      3.times { |i| other.posts.create(title: "Theirs #{i}", body: "Content") }

      posts = CQL::ActiveRecord::Relations::Collection(Post, Int32).new(
        key: :user_id,
        id: user.id!,
        query: CQL::Query.new(Post.schema).from(Post.table)
      )

      posts.count.should eq(2)
    end
  end

  describe "existence checks read at most one row" do
    it "answers posts_any? with one LIMIT select scoped to the parent and no COUNT" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      other = has_many_isolation_user("Jane Doe", "jane@example.com")
      3.times { |i| other.posts.create(title: "Theirs #{i}", body: "Content") }

      statements = count_queries { user.posts_any?.should be_false }
      statements.size.should eq(1)
      statements.first.should contain("LIMIT ?")
      statements.first.should_not contain("COUNT(")
      statements.first.scan("user_id = ?").size.should eq(1)

      3.times { |i| user.posts.create(title: "Mine #{i}", body: "Content") }

      statements = count_queries { user.posts_any?.should be_true }
      statements.size.should eq(1)
      statements.first.should contain("LIMIT ?")
      statements.first.should_not contain("COUNT(")
      statements.first.scan("user_id = ?").size.should eq(1)
    end

    it "counts the posts with posts_count without loading them" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      2.times { |i| user.posts.create(title: "Post #{i}", body: "Content") }

      TestUser.find!(user.id!).posts_count.should eq(2)
    end

    it "answers posts_any? from memory when the collection is loaded" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      user.posts.create(title: "Post 1", body: "Content")
      user.posts.reload

      count_queries { user.posts_any?.should be_true }.should be_empty
    end

    it "answers exists? with one LIMIT select scoped to the parent and the condition, without COUNT" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      other = has_many_isolation_user("Jane Doe", "jane@example.com")
      user.posts.create(title: "x", body: "Content")
      user.posts.create(title: "y", body: "Content")
      other.posts.create(title: "z", body: "Content")
      posts = user.posts

      statements = count_queries { posts.exists?(title: "x").should be_true }
      statements.size.should eq(1)
      statements.first.should contain("LIMIT ?")
      statements.first.should_not contain("COUNT(")
      statements.first.scan("user_id = ?").size.should eq(1)
      statements.first.scan("title = ?").size.should eq(1)

      statements = count_queries { posts.exists?(title: "missing").should be_false }
      statements.size.should eq(1)
      statements.first.should contain("LIMIT ?")
    end

    it "does not match another parent's records in exists?" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      other = has_many_isolation_user("Jane Doe", "jane@example.com")
      other.posts.create(title: "x", body: "Content")

      statements = count_queries { user.posts.exists?(title: "x").should be_false }
      statements.size.should eq(1)
      statements.first.scan("user_id = ?").size.should eq(1)

      posts = user.posts
      posts.reload
      posts.exists?(title: "x").should be_false
    end

    it "answers exists? without arguments as not empty?" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      user.posts.exists?.should be_false

      user.posts.create(title: "Post 1", body: "Content")
      user.posts.exists?.should be_true
    end

    it "keeps exists? correct on a loaded collection" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      user.posts.create(title: "x", body: "Content")
      posts = user.posts
      posts.reload

      posts.exists?(title: "x").should be_true
      posts.exists?(title: "missing").should be_false
    end

    it "answers empty? on an unloaded collection with one LIMIT select and stays unloaded" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      3.times { |i| user.posts.create(title: "Post #{i}", body: "Content") }
      posts = user.posts

      statements = count_queries { posts.empty?.should be_false }

      statements.size.should eq(1)
      statements.first.should contain("LIMIT ?")
      statements.first.should_not contain("COUNT(")
      statements.first.scan("user_id = ?").size.should eq(1)
      posts.loaded?.should be_false
    end

    it "answers empty? from memory when the collection is loaded" do
      user = has_many_isolation_user("John Doe", "john@example.com")
      user.posts.create(title: "Post 1", body: "Content")
      posts = user.posts
      posts.reload

      count_queries { posts.empty?.should be_false }.should be_empty
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
