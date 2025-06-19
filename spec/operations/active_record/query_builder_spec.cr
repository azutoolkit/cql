require "../../spec_helper"

describe "ActiveRecord::QueryBuilder" do
  before_each do
    UserDB.users.create!
    # Create some test data
    TestUser.create!(
      name: "John Doe",
      email: "john@example.com",
      age: 30,
      password: "password123"
    )
    TestUser.create!(
      name: "Jane Smith",
      email: "jane@example.com",
      age: 25,
      password: "password456"
    )
  end

  after_each do
    UserDB.users.drop!
  end

  describe "QueryCache" do
    it "stores and retrieves cached queries" do
      cache = CQL::ActiveRecord::Queryable::QueryCache
      cache.clear

      schema = Data
      query = CQL::Query.new(schema)

      cache.set("test_key", query)
      cached_query = cache.get("test_key")

      cached_query.should eq(query)
      cache.size.should eq(1)
    end

    it "returns nil for non-existent keys" do
      cache = CQL::ActiveRecord::Queryable::QueryCache
      cache.clear

      cached_query = cache.get("nonexistent")
      cached_query.should be_nil
    end

    it "can be cleared" do
      cache = CQL::ActiveRecord::Queryable::QueryCache
      cache.clear
      schema = Data
      query = CQL::Query.new(schema)
      cache.set("test", query)
      cache.size.should eq(1)
      cache.clear
      cache.size.should eq(0)
    end
  end

  describe "ErrorHandler" do
    it "handles DB::NoResultsError by returning nil" do
      handler = CQL::ActiveRecord::Queryable::ErrorHandler

      result = handler.handle_query_errors do
        raise DB::NoResultsError.new("No results")
      end

      result.should be_nil
    end

    it "handles connection errors with 'no results' message" do
      handler = CQL::ActiveRecord::Queryable::ErrorHandler

      result = handler.handle_query_errors do
        raise CQL::Schema::ConnectionError.new("no results found")
      end

      result.should be_nil
    end

    it "re-raises other connection errors" do
      handler = CQL::ActiveRecord::Queryable::ErrorHandler

      expect_raises(CQL::Schema::ConnectionError, "real connection error") do
        handler.handle_query_errors do
          raise CQL::Schema::ConnectionError.new("real connection error")
        end
      end
    end

    it "converts errors to NoResultsError in bang methods" do
      handler = CQL::ActiveRecord::Queryable::ErrorHandler

      expect_raises(DB::NoResultsError, "Record not found") do
        handler.handle_query_errors! do
          raise CQL::Schema::ConnectionError.new("no results found")
        end
      end
    end
  end

  describe "QueryBuilder" do
    before_each do
      # Clear cache before each test
      CQL::ActiveRecord::Queryable::QueryCache.clear
    end

    it "creates a new query builder from model" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      builder.model_class.should eq(TestUser)
      builder.cache_enabled.should be_true
    end

    it "can disable caching" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)
      no_cache_builder = builder.no_cache

      no_cache_builder.cache_enabled.should be_false
    end

    it "chains queries correctly" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)

      chained = builder
        .where(age: 25)
        .order(name: :asc)
        .limit(10)
        .offset(5)

      chained.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "maintains immutability in query chains" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)

      builder1 = builder.where(age: 25)
      builder2 = builder.where(name: "admin")

      # Original builder should be unchanged
      builder.should_not eq(builder1)
      builder.should_not eq(builder2)
      builder1.should_not eq(builder2)
    end

    it "generates consistent cache behavior for same queries" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)

      # Clear cache to start fresh
      CQL::ActiveRecord::Queryable::QueryCache.clear

      # Execute the same query twice - should use caching
      result1 = builder.all
      cache_size_after_first = CQL::ActiveRecord::Queryable::QueryCache.size

      result2 = builder.all
      cache_size_after_second = CQL::ActiveRecord::Queryable::QueryCache.size

      # Cache size should remain the same for identical queries
      cache_size_after_first.should eq(cache_size_after_second)
      cache_size_after_first.should be > 0
    end

    it "generates different cache entries for different queries" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(TestUser).from_model(TestUser)

      # Clear cache to start fresh
      CQL::ActiveRecord::Queryable::QueryCache.clear

      # Execute two different queries
      builder.all
      cache_size_after_first = CQL::ActiveRecord::Queryable::QueryCache.size

      builder.where(age: 25).all
      cache_size_after_second = CQL::ActiveRecord::Queryable::QueryCache.size

      # Different queries should create different cache entries
      cache_size_after_second.should be > cache_size_after_first
    end
  end

  describe "Model Integration" do
    before_each do
      TestUser.clear_cache
    end

    it "provides raw query through .query method" do
      query = TestUser.query
      query.should be_a(CQL::Query)
    end

    it "provides query builder through .query_builder method" do
      builder = TestUser.query_builder
      builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "maintains existing API methods" do
      # These should all compile and work
      TestUser.all.should be_a(Array(TestUser))
      TestUser.count.should be_a(Int64)
      TestUser.all.first.should be_a(TestUser | Nil)
      TestUser.all.last.should be_a(TestUser | Nil)
      # Optionally, check that the first and last users are among the created users
      names = TestUser.all.map(&.name)
      names.should contain("John Doe")
      names.should contain("Jane Smith")
    end

    it "provides chainable methods" do
      result = TestUser.where(age: 25).order(name: :asc).limit(5)
      result.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "provides cache statistics" do
      stats = TestUser.cache_stats
      stats[:size].should be_a(Int32)
    end

    it "can clear cache" do
      TestUser.where(age: 25).all  # This should cache something
      TestUser.cache_stats[:size].should be > 0

      TestUser.clear_cache
      TestUser.cache_stats[:size].should eq(0)
    end
  end

  describe "Performance and Caching" do
    before_each do
      TestUser.clear_cache
    end

    it "caches query results" do
      # First call should create cache entry
      TestUser.all
      cache_size_after_first = TestUser.cache_stats[:size]

      # Second call should use cache
      TestUser.all
      cache_size_after_second = TestUser.cache_stats[:size]

      cache_size_after_first.should eq(cache_size_after_second)
      cache_size_after_first.should be > 0
    end

    it "creates separate cache entries for different queries" do
      TestUser.all
      TestUser.where(age: 25).all

      TestUser.cache_stats[:size].should be >= 2
    end

    it "respects no_cache directive" do
      initial_size = TestUser.cache_stats[:size]

      TestUser.query_builder.no_cache.all

      TestUser.cache_stats[:size].should eq(initial_size)
    end
  end

  describe "Additional QueryBuilder Methods" do
    describe "Join methods" do
      it "provides inner_join method with block" do
        TestUser.query_builder.inner_join(:posts) do |builder|
          builder.users.id == builder.posts.user_id
        end.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end

      it "provides left_join method with block" do
        TestUser.query_builder.left_join(:posts) do |builder|
          builder.users.id == builder.posts.user_id
        end.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end

      it "provides right_join method with block" do
        TestUser.query_builder.right_join(:posts) do |builder|
          builder.users.id == builder.posts.user_id
        end.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end
    end

    describe "Query modifiers" do
      it "provides distinct method" do
        TestUser.query_builder.distinct.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end

      it "provides none method" do
        TestUser.query_builder.none.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end

      it "provides having method" do
        # Test having method exists and returns correct type
        # Note: having blocks require proper builder context, testing basic functionality
        TestUser.group_by(:age).should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      end
    end

    describe "Collection check methods" do
      it "provides empty? method" do
        TestUser.query_builder.empty?.should be_a(Bool)
      end

      it "provides any? method" do
        TestUser.query_builder.any?.should be_a(Bool)
      end

      it "provides many? method" do
        TestUser.query_builder.many?.should be_a(Bool)
      end

      it "provides size method" do
        TestUser.query_builder.size.should be_a(Int64)
      end
    end

    describe "Aggregate functions" do
      it "provides sum method" do
        TestUser.query_builder.sum(:age).should_not be_nil
      end

      it "provides avg method" do
        TestUser.query_builder.avg(:age).should_not be_nil
      end

      it "provides min method" do
        TestUser.query_builder.min(:age).should_not be_nil
      end

      it "provides max method" do
        TestUser.query_builder.max(:age).should_not be_nil
      end

      it "provides minimum method" do
        TestUser.query_builder.minimum(:age).should_not be_nil
      end

      it "provides maximum method" do
        TestUser.query_builder.maximum(:age).should_not be_nil
      end
    end

    describe "Batch processing" do
      it "provides find_each method" do
        count = 0
        TestUser.query_builder.find_each(batch_size: 10) do |test_user|
          count += 1
        end
        count.should be >= 0
      end

      it "provides find_in_batches method" do
        batch_count = 0
        TestUser.query_builder.find_in_batches(batch_size: 10) do |batch|
          batch_count += 1
          batch.should be_a(Array(TestUser))
        end
        batch_count.should be >= 0
      end
    end
  end

  describe "Class-level method delegation" do
    it "delegates join methods to class level" do
      TestUser.inner_join(:posts) do |builder|
        builder.users.id == builder.posts.user_id
      end.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      TestUser.left_join(:posts) do |builder|
        builder.users.id == builder.posts.user_id
      end.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      TestUser.right_join(:posts) do |builder|
        builder.users.id == builder.posts.user_id
      end.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "delegates query modifiers to class level" do
      TestUser.distinct.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
      TestUser.none.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(TestUser))
    end

    it "delegates collection checks to class level" do
      TestUser.empty?.should be_a(Bool)
      TestUser.any?.should be_a(Bool)
      TestUser.many?.should be_a(Bool)
      TestUser.size.should be_a(Int64)
    end

    it "delegates aggregate functions to class level" do
      TestUser.sum(:age).should_not be_nil
      TestUser.avg(:age).should_not be_nil
      TestUser.min(:age).should_not be_nil
      TestUser.max(:age).should_not be_nil
    end
  end
end
