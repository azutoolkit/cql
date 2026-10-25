require "./spec_helper"

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

      statements = count_queries { TestUser._preload_posts(parents, parents.map(&.id!), chunk_size: 3) }

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

      TestUser._preload_posts(parents, parents.map(&.id!), chunk_size: 2)

      parents.each { |parent| parent.posts.size.should eq(parent.id == user.id ? 1 : 0) }
    end

    it "uses a single SELECT when the parents fit in one chunk" do
      users = (1..4).map { |i| preload_chunk_user(i) }
      users.each { |user| Post.create!(title: "only", body: "b", user_id: user.id) }
      parents = TestUser.order(id: :asc).all

      statements = count_queries { TestUser._preload_posts(parents, parents.map(&.id!), chunk_size: 4) }

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
end
