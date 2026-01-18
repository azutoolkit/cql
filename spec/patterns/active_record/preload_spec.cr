require "./spec_helper"

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
end
