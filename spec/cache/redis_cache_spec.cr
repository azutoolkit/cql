require "../spec_helper"
require "../../src/cache/redis_cache"
require "../../src/cache/cache_store"

describe CQL::Cache::RedisCache do
  # Only run Redis tests if Redis is available
  redis_available = begin
    redis = Redis::PooledClient.new(url: "redis://localhost:6379/15")
    redis.ping == "PONG"
  rescue
    false
  end

  if redis_available
    redis_config = CQL::Cache::RedisCache::Config.new(
      url: "redis://localhost:6379/15", # Use test database
      key_prefix: "test"
    )

    redis_cache = CQL::Cache::RedisCache.new(redis_config)

    before_each do
      redis_cache.clear # Clean up before each test
    end

    after_each do
      redis_cache.clear # Clean up after each test
    end

    describe "#set and #get" do
      it "stores and retrieves values" do
        redis_cache.set("test_key", "test_value").should be_true
        redis_cache.get("test_key").should eq("test_value")
      end

      it "stores and retrieves values with TTL" do
        redis_cache.set("ttl_key", "ttl_value", 1.second).should be_true
        redis_cache.get("ttl_key").should eq("ttl_value")

        sleep 1.1.seconds
        redis_cache.get("ttl_key").should be_nil
      end

      it "returns nil for non-existent keys" do
        redis_cache.get("nonexistent").should be_nil
      end
    end

    describe "#exists?" do
      it "returns true for existing keys" do
        redis_cache.set("existing", "value")
        redis_cache.exists?("existing").should be_true
      end

      it "returns false for non-existing keys" do
        redis_cache.exists?("nonexistent").should be_false
      end
    end

    describe "#delete" do
      it "removes existing keys" do
        redis_cache.set("to_delete", "value")
        redis_cache.delete("to_delete").should be_true
        redis_cache.exists?("to_delete").should be_false
      end

      it "returns false for non-existing keys" do
        redis_cache.delete("nonexistent").should be_false
      end
    end

    describe "#clear" do
      it "removes all keys with the prefix" do
        redis_cache.set("key1", "value1")
        redis_cache.set("key2", "value2")
        redis_cache.set("key3", "value3")

        redis_cache.clear.should be_true
        redis_cache.exists?("key1").should be_false
        redis_cache.exists?("key2").should be_false
        redis_cache.exists?("key3").should be_false
      end
    end

    describe "#get_multi and #set_multi" do
      it "handles batch operations" do
        data = {
          "batch1" => "value1",
          "batch2" => "value2",
          "batch3" => "value3",
        }

        redis_cache.set_multi(data).should be_true

        result = redis_cache.get_multi(["batch1", "batch2", "batch3", "nonexistent"])
        result["batch1"].should eq("value1")
        result["batch2"].should eq("value2")
        result["batch3"].should eq("value3")
        result["nonexistent"].should be_nil
      end

      it "handles batch operations with TTL" do
        data = {"ttl_batch" => "ttl_value"}
        redis_cache.set_multi(data, 1.second).should be_true

        redis_cache.get("ttl_batch").should eq("ttl_value")
        sleep 1.1.seconds
        redis_cache.get("ttl_batch").should be_nil
      end
    end

    describe "#delete_multi" do
      it "deletes multiple keys" do
        redis_cache.set("multi1", "value1")
        redis_cache.set("multi2", "value2")
        redis_cache.set("multi3", "value3")

        count = redis_cache.delete_multi(["multi1", "multi2", "nonexistent"])
        count.should eq(2)

        redis_cache.exists?("multi1").should be_false
        redis_cache.exists?("multi2").should be_false
        redis_cache.exists?("multi3").should be_true
      end
    end

    describe "#tag_cache and #invalidate_tags" do
      it "supports tag-based invalidation" do
        redis_cache.set("tagged1", "value1")
        redis_cache.set("tagged2", "value2")
        redis_cache.set("tagged3", "value3")

        redis_cache.tag_cache("tagged1", ["user", "profile"]).should be_true
        redis_cache.tag_cache("tagged2", ["user", "settings"]).should be_true
        redis_cache.tag_cache("tagged3", ["admin", "settings"]).should be_true

        # Invalidate all entries with "user" tag
        count = redis_cache.invalidate_tags(["user"])
        count.should eq(2)

        redis_cache.exists?("tagged1").should be_false
        redis_cache.exists?("tagged2").should be_false
        redis_cache.exists?("tagged3").should be_true
      end
    end

    describe "#get_version and #increment_version" do
      it "supports version-based invalidation" do
        initial_version = redis_cache.get_version("versioned_key")
        initial_version.should be_nil

        new_version = redis_cache.increment_version("versioned_key")
        new_version.should eq(1)

        current_version = redis_cache.get_version("versioned_key")
        current_version.should eq(1)

        incremented = redis_cache.increment_version("versioned_key")
        incremented.should eq(2)
      end
    end

    describe "#stats" do
      it "returns cache statistics" do
        redis_cache.set("stats_test", "value")
        stats = redis_cache.stats

        stats["type"].should eq("redis")
        stats["hits"].should be_a(Int64)
        stats["misses"].should be_a(Int64)
        stats["sets"].should be_a(Int64)
        stats["deletes"].should be_a(Int64)
        stats["key_prefix"].should eq("test")
      end
    end

    describe "#size" do
      it "returns the number of cached entries" do
        initial_size = redis_cache.size

        redis_cache.set("size1", "value1")
        redis_cache.set("size2", "value2")

        redis_cache.size.should eq(initial_size + 2)
      end
    end

    describe "#ping" do
      it "checks Redis connectivity" do
        redis_cache.ping.should be_true
      end
    end

    describe "#connection_info" do
      it "returns connection information" do
        info = redis_cache.connection_info
        info.should_not be_empty
      end
    end

    describe "key prefixing" do
      it "uses the configured key prefix" do
        redis_cache.set("prefixed", "value")

        # Access Redis directly to verify prefix
        raw_redis = Redis::PooledClient.new(url: "redis://localhost:6379/15")
        raw_redis.exists("test:prefixed").should eq(1)
        raw_redis.exists("prefixed").should eq(0)
      end
    end
  else
    pending "Redis cache tests (Redis not available)"
  end
end

describe CQL::Cache::CacheStore do
  describe ".create" do
    it "creates memory cache by default" do
      cache = CQL::Cache::CacheStore.create("memory")
      cache.should be_a(CQL::Cache::MemoryCache)
    end

    it "creates Redis cache when configured" do
      if begin
           redis = Redis::PooledClient.new(url: "redis://localhost:6379/15")
           redis.ping == "PONG"
         rescue
           false
         end
        cache = CQL::Cache::CacheStore.create("redis", redis_url: "redis://localhost:6379/15")
        cache.should be_a(CQL::Cache::RedisCache)
      else
        puts "Redis not available for testing"
      end
    end

    it "raises error for unknown cache type" do
      expect_raises(ArgumentError, "Unknown cache type: unknown") do
        CQL::Cache::CacheStore.create("unknown")
      end
    end
  end

  describe "configuration" do
    it "configures from environment variables" do
      ENV["CQL_CACHE_TYPE"] = "memory"
      ENV["CQL_CACHE_PREFIX"] = "test_env"
      ENV["CQL_CACHE_TTL"] = "7200"

      config = CQL::Cache::CacheStoreConfig.from_env
      config.type.should eq(CQL::Cache::CacheStoreType::Memory)
      config.key_prefix.should eq("test_env")
      config.default_ttl.should eq(7200.seconds)

      # Clean up
      ENV.delete("CQL_CACHE_TYPE")
      ENV.delete("CQL_CACHE_PREFIX")
      ENV.delete("CQL_CACHE_TTL")
    end

    it "configures from hash" do
      hash = {
        "type"        => "redis",
        "key_prefix"  => "test_hash",
        "default_ttl" => 3600,
        "redis_url"   => "redis://localhost:6379/1",
      }

      config = CQL::Cache::CacheStoreConfig.from_hash(hash)
      config.type.should eq(CQL::Cache::CacheStoreType::Redis)
      config.key_prefix.should eq("test_hash")
      config.default_ttl.should eq(3600.seconds)
      config.redis_url.should eq("redis://localhost:6379/1")
    end
  end
end

describe CQL::Cache::GlobalCache do
  before_each do
    CQL::Cache::CacheStore.reset
  end

  it "provides global cache access" do
    CQL::Cache::GlobalCache.set("global_test", "global_value")
    result = CQL::Cache::GlobalCache.get("global_test", String)
    result.should eq("global_value")
  end

  it "supports cache with block execution" do
    call_count = 0

    # First call should execute the block
    result1 = CQL::Cache::GlobalCache.cache("expensive_op", 1.hour) do
      call_count += 1
      "computed_value"
    end

    result1.should eq("computed_value")
    call_count.should eq(1)

    # Second call should hit cache
    result2 = CQL::Cache::GlobalCache.cache("expensive_op", 1.hour) do
      call_count += 1
      "computed_value"
    end

    result2.should eq("computed_value")
    call_count.should eq(1) # Block not executed again
  end

  it "provides basic cache operations" do
    CQL::Cache::GlobalCache.set("exists_test", "value")
    CQL::Cache::GlobalCache.exists?("exists_test").should be_true
    CQL::Cache::GlobalCache.exists?("nonexistent").should be_false

    CQL::Cache::GlobalCache.delete("exists_test").should be_true
    CQL::Cache::GlobalCache.exists?("exists_test").should be_false
  end

  it "provides stats and size information" do
    CQL::Cache::GlobalCache.set("stats_test", "value")

    stats = CQL::Cache::GlobalCache.stats
    stats.should be_a(Hash(String, String | Int32 | Int64 | Float64))

    size = CQL::Cache::GlobalCache.size
    size.should be_a(Int32)
    size.should be >= 0
  end

  it "can clear all cache" do
    CQL::Cache::GlobalCache.set("clear_test1", "value1")
    CQL::Cache::GlobalCache.set("clear_test2", "value2")

    CQL::Cache::GlobalCache.clear.should be_true
    CQL::Cache::GlobalCache.exists?("clear_test1").should be_false
    CQL::Cache::GlobalCache.exists?("clear_test2").should be_false
  end
end
