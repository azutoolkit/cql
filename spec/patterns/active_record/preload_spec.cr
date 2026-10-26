require "./spec_helper"

PreloadMismatchDB = CQL::Schema.define(:preload_mismatch_db, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("preload_mismatch.db")) do
  table :mismatch_owners do
    primary :id, Int64, auto_increment: true
    text :name
  end

  table :mismatch_badges do
    primary :id, Int64, auto_increment: true
    integer :mismatch_owner_id, null: true
  end
end

# The badge's foreign key is Int32 while the owner's key is Int64.
class MismatchBadge
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: PreloadMismatchDB, table: :mismatch_badges

  property mismatch_owner_id : Int32?
end

class MismatchOwner
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: PreloadMismatchDB, table: :mismatch_owners

  property name : String = ""

  has_one :badge, MismatchBadge
end

private def preload_chunk_user(index : Int32) : TestUser
  TestUser.create!(name: "Chunk User #{index}", email: "chunk#{index}@example.com", age: 30, password: "password123", password_confirmation: "password123")
end

describe "Eager Loading / Preload" do
  describe "QueryBuilder#preload" do
    it "returns a new QueryBuilder with preload specs" do
      builder = TestUser.query.preload(:posts)
      builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "chains with where conditions" do
      builder = TestUser.where(age: 25).preload(:posts)
      builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "allows multiple associations to be preloaded" do
      builder = TestUser.preload(:posts, :profile)
      builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe "Queryable.preload" do
    it "provides class-level preload method" do
      builder = TestUser.preload(:posts)
      builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end
  end

  describe "Collection#_inject_preloaded" do
    it "exposes _inject_preloaded method" do
      # Create the collection manually with dummy values
      collection = CQL::ActiveRecord::Relations::Collection(Post, Int32).new(
        key: :user_id,
        id: 1,
        auto_load: false
      )

      # The collection should not be loaded initially
      collection.loaded?.should be_false

      # Inject empty array (no DB access needed)
      preloaded_posts = [] of Post
      collection._inject_preloaded(preloaded_posts)

      # Now the collection should be loaded
      collection.loaded?.should be_true
      collection.size.should eq(0)
    end
  end

  describe "has_many preload methods" do
    it "generates _preload_<name> class method" do
      # Test that the class method exists
      TestUser.responds_to?(:_preload_posts).should be_true
    end
  end

  describe "has_many preload chunking" do
    before_each do
      UserDB.users.create!
      UserDB.posts.create!
    end

    after_each do
      UserDB.posts.drop!
      UserDB.users.drop!
    end

    it "splits the child SELECT into ceil(N/k) chunks and attaches every child" do
      users = (1..7).map { |i| preload_chunk_user(i) }
      users.each_with_index { |user, i| (i % 3).times { |j| Post.create!(title: "P#{i}-#{j}", body: "b", user_id: user.id) } }
      parents = TestUser.order(id: :asc).all

      statements = count_queries { TestUser._preload_posts(parents, chunk_size: 3) }

      statements.size.should eq(3)
      statements.each(&.scan("?").size.should(be <= 3))
      parents.each_with_index do |parent, i|
        parent.posts.loaded?.should be_true
        parent.posts.map(&.title).sort!.should eq((0...(i % 3)).map { |j| "P#{i}-#{j}" })
      end
    end

    it "attaches children once when a parent id repeats across chunks" do
      user = preload_chunk_user(1)
      other = preload_chunk_user(2)
      Post.create!(title: "once", body: "b", user_id: user.id)
      parents = [user, other, user]

      TestUser._preload_posts(parents, chunk_size: 2)

      parents.each { |parent| parent.posts.size.should eq(parent.id == user.id ? 1 : 0) }
    end

    it "keeps the preload when a scope follows it" do
      user = preload_chunk_user(1)
      Post.create!(title: "only", body: "b", user_id: user.id)
      loaded = [] of TestUser

      statements = count_queries { loaded = TestUser.preload(:posts).adults.all }

      statements.size.should eq(2)
      loaded.map(&.posts.size).should eq([1])
    end

    it "uses a single SELECT when the parents fit in one chunk" do
      users = (1..4).map { |i| preload_chunk_user(i) }
      users.each { |user| Post.create!(title: "only", body: "b", user_id: user.id) }
      parents = TestUser.order(id: :asc).all

      statements = count_queries { TestUser._preload_posts(parents, chunk_size: 4) }

      statements.size.should eq(1)
      parents.each(&.posts.size.should(eq(1)))
    end

    it "keeps one child SELECT through the preload dispatcher under the dialect limit" do
      users = (1..4).map { |i| preload_chunk_user(i) }
      users.each { |user| Post.create!(title: "only", body: "b", user_id: user.id) }

      loaded = [] of TestUser
      statements = count_queries { loaded = TestUser.preload(:posts).all }

      statements.size.should eq(2)
      loaded.each(&.posts.size.should(eq(1)))
    end
  end

  describe "belongs_to preload" do
    before_each do
      UserDB.users.create!
      UserDB.posts.create!
    end

    after_each do
      UserDB.posts.drop!
      UserDB.users.drop!
    end

    it "loads every post's user with one extra query" do
      ada = preload_chunk_user(1)
      bob = preload_chunk_user(2)
      Post.create!(title: "A1", body: "b", user_id: ada.id)
      Post.create!(title: "A2", body: "b", user_id: ada.id)
      Post.create!(title: "B1", body: "b", user_id: bob.id)
      Post.create!(title: "None", body: "b", user_id: nil)

      posts = [] of Post
      loading = count_queries { posts = Post.order(id: :asc).preload(:user).all }
      reading = count_queries { posts.map(&.user.try(&.name)) }

      loading.size.should eq(2)
      reading.should be_empty
      posts.map(&.user.try(&.id)).should eq([ada.id, ada.id, bob.id, nil])
    end

    it "splits the user SELECT into chunks of distinct keys" do
      users = (1..3).map { |i| preload_chunk_user(i) }
      users.each { |user| 2.times { Post.create!(title: "P", body: "b", user_id: user.id) } }
      posts = Post.all

      statements = count_queries { Post._preload_user(posts, chunk_size: 2) }

      statements.size.should eq(2)
      posts.each { |post| post.user.not_nil!.id.should eq(post.user_id) }
    end
  end

  describe "has_one preload" do
    before_each do
      UserDB.users.create!
      UserDB.profiles.create!
      UserDB.profile_owners.create!
    end

    after_each do
      UserDB.profile_owners.drop!
      UserDB.profiles.drop!
      UserDB.users.drop!
    end

    owner = ->(index : Int32) do
      ProfileOwner.new("Owner #{index}", "owner#{index}@example.com", 30, "password123", "password123").tap(&.create!)
    end

    it "loads every owner's profile with one extra query" do
      owners = (1..3).map { |i| owner.call(i) }
      owners[0].create_profile(bio: "first", avatar_url: "a")
      owners[1].create_profile(bio: "second", avatar_url: "b")

      loaded = [] of ProfileOwner
      loading = count_queries { loaded = ProfileOwner.order(id: :asc).preload(:profile).all }
      reading = count_queries { loaded.map(&.profile.try(&.bio)) }

      loading.size.should eq(2)
      reading.should be_empty
      loaded.map(&.profile.try(&.bio)).should eq(["first", "second", nil])
    end

    it "splits the profile SELECT into chunks of parent ids" do
      (1..3).each { |i| owner.call(i).create_profile(bio: "bio #{i}", avatar_url: "a") }
      loaded = ProfileOwner.order(id: :asc).all

      count_queries { ProfileOwner._preload_profile(loaded, chunk_size: 2) }.size.should eq(2)
      loaded.map(&.profile.not_nil!.bio).should eq(["bio 1", "bio 2", "bio 3"])
    end

    it "attaches one of several children" do
      first = owner.call(1)
      UserProfile.new("one", "a", first.id).save!
      UserProfile.new("two", "b", first.id).save!

      loaded = ProfileOwner.preload(:profile).all

      ["one", "two"].should contain(loaded.first.profile.not_nil!.bio)
    end

    it "matches keys whose types differ between owner and target" do
      PreloadMismatchDB.mismatch_owners.create!
      PreloadMismatchDB.mismatch_badges.create!
      parent = MismatchOwner.create!(name: "owner")
      MismatchBadge.create!(mismatch_owner_id: parent.id!.to_i32)

      MismatchOwner.preload(:badge).all.first.badge.should_not be_nil
    ensure
      PreloadMismatchDB.mismatch_badges.drop!
      PreloadMismatchDB.mismatch_owners.drop!
    end

    it "raises when the target has no foreign key attribute" do
      preload_chunk_user(1)

      expect_raises(ArgumentError, /test_user_id/) { TestUser.preload(:profile).all }
    end
  end
end
