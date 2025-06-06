require "../../spec_helper"

describe "ActiveRecord::QueryBuilder" do
  describe "QueryCache" do
    it "stores and retrieves cached queries" do
      cache = CQL::ActiveRecord::Queryable::QueryCache
      cache.clear

      schema = CQL::Schema.new
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
      schema = CQL::Schema.new
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
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(User).from_model(User)
      builder.model_class.should eq(User)
      builder.cache_enabled.should be_true
    end

    it "can disable caching" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(User).from_model(User)
      no_cache_builder = builder.no_cache

      no_cache_builder.cache_enabled.should be_false
    end

    it "chains queries correctly" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(User).from_model(User)

      chained = builder
        .where(active: true)
        .order(name: :asc)
        .limit(10)
        .offset(5)

      chained.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(User))
    end

    it "maintains immutability in query chains" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(User).from_model(User)

      builder1 = builder.where(active: true)
      builder2 = builder.where(role: "admin")

      # Original builder should be unchanged
      builder.should_not eq(builder1)
      builder.should_not eq(builder2)
      builder1.should_not eq(builder2)
    end

    it "generates consistent cache keys" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(User).from_model(User)
      key1 = builder.send(:generate_cache_key, "all")
      key2 = builder.send(:generate_cache_key, "all")

      key1.should eq(key2)
    end

    it "generates different cache keys for different queries" do
      builder = CQL::ActiveRecord::Queryable::QueryBuilder(User).from_model(User)
      key1 = builder.send(:generate_cache_key, "all")
      key2 = builder.where(active: true).send(:generate_cache_key, "all")

      key1.should_not eq(key2)
    end
  end

  describe "Model Integration" do
    before_each do
      User.clear_cache
    end

    it "provides query builder through .query method" do
      builder = User.query
      builder.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(User))
    end

    it "maintains existing API methods" do
      # These should all compile and work
      User.all.should be_a(Array(User))
      User.count.should be_a(Int64)
      User.first.should be_a(User | Nil)
      User.last.should be_a(User | Nil)
    end

    it "provides chainable methods" do
      result = User.where(active: true).order(name: :asc).limit(5)
      result.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(User))
    end

    it "provides cache statistics" do
      stats = User.cache_stats
      stats[:size].should be_a(Int32)
    end

    it "can clear cache" do
      User.where(active: true).all  # This should cache something
      User.cache_stats[:size].should be > 0

      User.clear_cache
      User.cache_stats[:size].should eq(0)
    end
  end



    describe "Performance and Caching" do
    before_each do
      User.clear_cache
    end

    it "caches query results" do
      # First call should create cache entry
      User.all
      cache_size_after_first = User.cache_stats[:size]

      # Second call should use cache
      User.all
      cache_size_after_second = User.cache_stats[:size]

      cache_size_after_first.should eq(cache_size_after_second)
      cache_size_after_first.should be > 0
    end

    it "creates separate cache entries for different queries" do
      User.all
      User.where(active: true).all

      User.cache_stats[:size].should be >= 2
    end

    it "respects no_cache directive" do
      initial_size = User.cache_stats[:size]

      User.query.no_cache.all

      User.cache_stats[:size].should eq(initial_size)
    end
  end

  describe "Additional QueryBuilder Methods" do
    describe "Join methods" do
      it "provides inner_join method" do
        User.query.inner_join(:posts, {id: :user_id}).should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(User))
      end

      it "provides left_join method" do
        User.query.left_join(:posts, {id: :user_id}).should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(User))
      end

      it "provides right_join method" do
        User.query.right_join(:posts, {id: :user_id}).should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(User))
      end
    end

    describe "Query modifiers" do
      it "provides distinct method" do
        User.query.distinct.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(User))
      end

      it "provides none method" do
        User.query.none.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(User))
      end

      it "provides having method" do
        User.query.having { |h| h.count(:id) > 5 }.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(User))
      end
    end

    describe "Collection check methods" do
      it "provides empty? method" do
        User.query.empty?.should be_a(Bool)
      end

      it "provides any? method" do
        User.query.any?.should be_a(Bool)
      end

      it "provides many? method" do
        User.query.many?.should be_a(Bool)
      end

      it "provides size method" do
        User.query.size.should be_a(Int64)
      end
    end

    describe "Aggregate functions" do
      it "provides sum method" do
        User.query.sum(:age).should_not be_nil
      end

      it "provides avg method" do
        User.query.avg(:age).should_not be_nil
      end

      it "provides min method" do
        User.query.min(:age).should_not be_nil
      end

      it "provides max method" do
        User.query.max(:age).should_not be_nil
      end

      it "provides minimum method" do
        User.query.minimum(:age).should_not be_nil
      end

      it "provides maximum method" do
        User.query.maximum(:age).should_not be_nil
      end
    end

    describe "Batch processing" do
      it "provides find_each method" do
        count = 0
        User.query.find_each(batch_size: 10) do |user|
          count += 1
        end
        count.should be >= 0
      end

      it "provides find_in_batches method" do
        batch_count = 0
        User.query.find_in_batches(batch_size: 10) do |batch|
          batch_count += 1
          batch.should be_a(Array(User))
        end
        batch_count.should be >= 0
      end
    end
  end

  describe "Class-level method delegation" do
    it "delegates join methods to class level" do
      User.inner_join(:posts, {id: :user_id}).should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(User))
      User.left_join(:posts, {id: :user_id}).should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(User))
      User.right_join(:posts, {id: :user_id}).should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(User))
    end

    it "delegates query modifiers to class level" do
      User.distinct.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(User))
      User.none.should be_a(CQL::ActiveRecord::Queryable::QueryBuilder(User))
    end

    it "delegates collection checks to class level" do
      User.empty?.should be_a(Bool)
      User.any?.should be_a(Bool)
      User.many?.should be_a(Bool)
      User.size.should be_a(Int64)
    end

    it "delegates aggregate functions to class level" do
      User.sum(:age).should_not be_nil
      User.avg(:age).should_not be_nil
      User.min(:age).should_not be_nil
      User.max(:age).should_not be_nil
    end
  end
end
