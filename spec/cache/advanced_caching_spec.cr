require "../spec_helper"
require "../../src/cache/cache_interface"
require "../../src/cache/memory_cache"
require "../../src/cache/fragment_cache"
require "../../src/cache/invalidation_strategies"

describe "CQL Advanced Caching" do
  describe "MemoryCache" do
    cache = CQL::Cache::MemoryCache.new

    before_each do
      cache.clear
    end

    describe "basic operations" do
      it "stores and retrieves values" do
        cache.set("key1", "value1").should be_true
        cache.get("key1").should eq("value1")
      end

      it "returns nil for non-existent keys" do
        cache.get("nonexistent").should be_nil
      end

      it "deletes keys" do
        cache.set("key1", "value1")
        cache.delete("key1").should be_true
        cache.get("key1").should be_nil
      end

      it "checks key existence" do
        cache.set("key1", "value1")
        cache.exists?("key1").should be_true
        cache.exists?("nonexistent").should be_false
      end

      it "clears all entries" do
        cache.set("key1", "value1")
        cache.set("key2", "value2")
        cache.clear.should be_true
        cache.size.should eq(0)
      end
    end

    describe "TTL support" do
      it "expires entries after TTL" do
        cache.set("key1", "value1", 0.1.seconds)
        cache.get("key1").should eq("value1")

        sleep(0.2.seconds)
        cache.get("key1").should be_nil
      end

      it "doesn't expire entries without TTL" do
        cache.set("key1", "value1")
        sleep(0.1.seconds)
        cache.get("key1").should eq("value1")
      end
    end

    describe "batch operations" do
      it "gets multiple keys" do
        cache.set("key1", "value1")
        cache.set("key2", "value2")

        results = cache.get_multi(["key1", "key2", "key3"])
        results["key1"].should eq("value1")
        results["key2"].should eq("value2")
        results["key3"].should be_nil
      end

      it "sets multiple keys" do
        data = {"key1" => "value1", "key2" => "value2"}
        cache.set_multi(data).should be_true

        cache.get("key1").should eq("value1")
        cache.get("key2").should eq("value2")
      end

      it "deletes multiple keys" do
        cache.set("key1", "value1")
        cache.set("key2", "value2")
        cache.set("key3", "value3")

        count = cache.delete_multi(["key1", "key3"])
        count.should eq(2)

        cache.get("key1").should be_nil
        cache.get("key2").should eq("value2")
        cache.get("key3").should be_nil
      end
    end

    describe "tag support" do
      it "tags cache entries" do
        cache.set("key1", "value1")
        cache.tag_cache("key1", ["tag1", "tag2"]).should be_true
      end

      it "invalidates by tags" do
        cache.set("key1", "value1")
        cache.set("key2", "value2")
        cache.set("key3", "value3")

        cache.tag_cache("key1", ["user", "profile"])
        cache.tag_cache("key2", ["user", "posts"])
        cache.tag_cache("key3", ["admin"])

        count = cache.invalidate_tags(["user"])
        count.should eq(2)

        cache.get("key1").should be_nil
        cache.get("key2").should be_nil
        cache.get("key3").should eq("value3")
      end
    end

    describe "version support" do
      it "tracks versions" do
        cache.get_version("key1").should be_nil
        version = cache.increment_version("key1")
        version.should eq(1)
        cache.get_version("key1").should eq(1)
      end

      it "increments versions" do
        cache.increment_version("key1")
        version = cache.increment_version("key1")
        version.should eq(2)
      end
    end

    describe "LRU eviction" do
      it "evicts least recently used entries when size limit reached" do
        small_cache = CQL::Cache::MemoryCache.new(max_size: 3)

        small_cache.set("key1", "value1")
        small_cache.set("key2", "value2")
        small_cache.set("key3", "value3")
        small_cache.size.should eq(3)

        # Access key1 to make it more recently used
        small_cache.get("key1")

        # Add key4, should evict key2 (least recently used)
        small_cache.set("key4", "value4")
        small_cache.size.should eq(3)

        small_cache.get("key1").should eq("value1") # Still there
        small_cache.get("key2").should be_nil       # Evicted
        small_cache.get("key3").should eq("value3") # Still there
        small_cache.get("key4").should eq("value4") # New entry
      end
    end

    describe "statistics" do
      it "tracks cache statistics" do
        cache.set("key1", "value1")
        cache.get("key1") # Hit
        cache.get("key2") # Miss

        stats = cache.stats
        stats["hits"].should eq(1)
        stats["misses"].should eq(1)
        stats["sets"].should eq(1)
        stats["hit_rate_percent"].as(Float64).should be > 0
      end
    end
  end

  describe "TimestampInvalidation" do
    strategy = CQL::Cache::TimestampInvalidation.new(max_age: 1.second)

    it "generates timestamp metadata" do
      metadata = strategy.generate_metadata("key1")
      metadata.has_key?("timestamp").should be_true

      Time.parse_rfc3339(metadata["timestamp"]).should be_close(Time.utc, 1.second)
    end

    it "doesn't invalidate fresh entries" do
      metadata = strategy.generate_metadata("key1")
      strategy.should_invalidate?("key1", metadata).should be_false
    end

    it "invalidates old entries" do
      # Create old metadata
      old_time = Time.utc - 2.seconds
      metadata = {"timestamp" => old_time.to_rfc3339}

      strategy.should_invalidate?("key1", metadata).should be_true
    end

    it "invalidates entries with malformed timestamps" do
      metadata = {"timestamp" => "invalid"}
      strategy.should_invalidate?("key1", metadata).should be_true
    end
  end

  describe "VersionInvalidation" do
    it "generates version metadata" do
      strategy = CQL::Cache::VersionInvalidation.new
      metadata = strategy.generate_metadata("key1")
      metadata["version"].should eq("0") # Initial version
    end

    it "doesn't invalidate current version" do
      strategy = CQL::Cache::VersionInvalidation.new
      metadata = strategy.generate_metadata("key1")
      strategy.should_invalidate?("key1", metadata).should be_false
    end

    it "invalidates old versions" do
      strategy = CQL::Cache::VersionInvalidation.new
      # Get initial metadata
      metadata = strategy.generate_metadata("key1")

      # Increment version
      strategy.increment_version("key1")

      # Old metadata should now be invalid
      strategy.should_invalidate?("key1", metadata).should be_true
    end

    it "manages version numbers correctly" do
      # Test with a fresh strategy instance
      fresh_strategy = CQL::Cache::VersionInvalidation.new
      fresh_strategy.get_current_version("key1").should eq(0)

      version1 = fresh_strategy.increment_version("key1")
      version1.should eq(1)

      version2 = fresh_strategy.increment_version("key1")
      version2.should eq(2)

      fresh_strategy.get_current_version("key1").should eq(2)
    end
  end

  describe "TransactionAwareInvalidation" do
    cache = CQL::Cache::MemoryCache.new
    base_strategy = CQL::Cache::TimestampInvalidation.new
    tx_strategy = CQL::Cache::TransactionAwareInvalidation.new(base_strategy)

    before_each do
      cache.clear
      tx_strategy.clear_pending_invalidations
    end

    it "defers invalidation until execution" do
      cache.set("key1", "value1")
      cache.set("key2", "value2")

      tx_strategy.mark_for_invalidation(["key1", "key2"])

      # Values should still be cached
      cache.get("key1").should eq("value1")
      cache.get("key2").should eq("value2")

      # Execute pending invalidations
      tx_strategy.execute_pending_invalidations(cache)

      # Values should now be invalidated
      cache.get("key1").should be_nil
      cache.get("key2").should be_nil
    end

    it "clears pending invalidations on rollback" do
      cache.set("key1", "value1")

      tx_strategy.mark_for_invalidation(["key1"])
      tx_strategy.clear_pending_invalidations

      # No invalidation should happen
      tx_strategy.execute_pending_invalidations(cache)
      cache.get("key1").should eq("value1")
    end

    it "supports tag-based invalidation" do
      cache.set("key1", "value1")
      cache.set("key2", "value2")
      cache.tag_cache("key1", ["user:1"])
      cache.tag_cache("key2", ["user:1"])

      tx_strategy.mark_tags_for_invalidation(["user:1"])

      # Values should still be cached
      cache.get("key1").should eq("value1")
      cache.get("key2").should eq("value2")

      # Execute pending invalidations
      tx_strategy.execute_pending_invalidations(cache)

      # Values should now be invalidated
      cache.get("key1").should be_nil
      cache.get("key2").should be_nil
    end
  end

  describe "FragmentCache" do
    cache = CQL::Cache::MemoryCache.new
    strategy = CQL::Cache::TimestampInvalidation.new
    config = CQL::Cache::CacheConfig.new
    fragment_cache = CQL::Cache::FragmentCache.new(cache, strategy, config)

    before_each do
      cache.clear
    end

    describe "fragment caching" do
      it "caches expensive operations" do
        call_count = 0

        result1 = fragment_cache.cache_fragment("expensive") do
          call_count += 1
          "result"
        end

        result2 = fragment_cache.cache_fragment("expensive") do
          call_count += 1
          "result"
        end

        call_count.should eq(1)
        result1.should eq("result")
        result2.should eq("result")
      end

      it "supports parameters in cache keys" do
        params1 = {"user_id" => 1.as(DB::Any)}
        params2 = {"user_id" => 2.as(DB::Any)}

        result1 = fragment_cache.cache_fragment("user_profile", params1) do
          "profile for user 1"
        end

        result2 = fragment_cache.cache_fragment("user_profile", params2) do
          "profile for user 2"
        end

        result1.should eq("profile for user 1")
        result2.should eq("profile for user 2")

        # Results should be cached separately
        fragment_cache.fragment_cached?("user_profile", params1).should be_true
        fragment_cache.fragment_cached?("user_profile", params2).should be_true
      end

      it "supports tag-based invalidation" do
        tags = ["user", "profile"]

        fragment_cache.cache_fragment("user_profile", tags: tags) do
          "cached profile"
        end

        fragment_cache.fragment_cached?("user_profile").should be_true

        count = fragment_cache.invalidate_tags(["user"])
        count.should eq(1)

        fragment_cache.fragment_cached?("user_profile").should be_false
      end
    end

    describe "query caching" do
      it "caches query results" do
        sql = "SELECT * FROM users WHERE active = ?"
        params = [true.as(DB::Any)]
        call_count = 0

        result1 = fragment_cache.cache_query(sql, params) do
          call_count += 1
          [{"id" => 1, "name" => "John"}, {"id" => 2, "name" => "Jane"}]
        end

        result2 = fragment_cache.cache_query(sql, params) do
          call_count += 1
          [{"id" => 1, "name" => "John"}, {"id" => 2, "name" => "Jane"}]
        end

        call_count.should eq(1)
        result1.should eq(result2)
      end
    end

    describe "cache key generation" do
      it "generates consistent keys for same parameters" do
        params = {"user_id" => 1.as(DB::Any), "type" => "profile".as(DB::Any)}

        key1 = fragment_cache.generate_fragment_key("test", params)
        key2 = fragment_cache.generate_fragment_key("test", params)

        key1.should eq(key2)
      end

      it "generates different keys for different parameters" do
        params1 = {"user_id" => 1.as(DB::Any)}
        params2 = {"user_id" => 2.as(DB::Any)}

        key1 = fragment_cache.generate_fragment_key("test", params1)
        key2 = fragment_cache.generate_fragment_key("test", params2)

        key1.should_not eq(key2)
      end

      it "sorts parameters for consistent ordering" do
        params1 = {"b" => 2.as(DB::Any), "a" => 1.as(DB::Any)}
        params2 = {"a" => 1.as(DB::Any), "b" => 2.as(DB::Any)}

        key1 = fragment_cache.generate_fragment_key("test", params1)
        key2 = fragment_cache.generate_fragment_key("test", params2)

        key1.should eq(key2)
      end
    end
  end

  describe "CacheKeyBuilder" do
    it "builds simple keys" do
      builder = CQL::Cache::CacheKeyBuilder.new("test")
      key = builder.add_component("operation").build
      key.should eq("test:operation")
    end

    it "builds keys with parameters" do
      builder = CQL::Cache::CacheKeyBuilder.new("test")
      key = builder
        .add_component("operation")
        .add_param("user_id", 123.as(DB::Any))
        .build

      key.should start_with("test:operation:")
      key.size.should be > "test:operation:".size
    end

    it "can be reset and reused" do
      builder = CQL::Cache::CacheKeyBuilder.new("test")

      key1 = builder.add_component("op1").build
      key1.should eq("test:op1")

      key2 = builder.reset.add_component("op2").build
      key2.should eq("test:op2")
    end
  end

  describe "Performance characteristics" do
    it "provides significant speedup for repeated operations" do
      cache = CQL::Cache::MemoryCache.new
      strategy = CQL::Cache::TimestampInvalidation.new
      fragment_cache = CQL::Cache::FragmentCache.new(cache, strategy)

      call_count = 0
      expensive_operation = -> {
        call_count += 1
        "expensive_result"
      }

      # First call should execute the expensive operation
      result1 = fragment_cache.cache_fragment("expensive") do
        expensive_operation.call
      end

      # Second call should hit cache and not execute the operation
      result2 = fragment_cache.cache_fragment("expensive") do
        expensive_operation.call
      end

      # Both results should be the same
      result1.should eq("expensive_result")
      result2.should eq("expensive_result")

      # But expensive operation should only have been called once
      call_count.should eq(1)
    end

    it "handles high concurrency without data races" do
      cache = CQL::Cache::MemoryCache.new
      results = Channel(String?).new

      # Spawn multiple fibers accessing cache concurrently
      10.times do |i|
        spawn do
          cache.set("key_#{i}", "value_#{i}")
          value = cache.get("key_#{i}")
          results.send(value)
        end
      end

      # Collect all results
      retrieved_values = [] of String?
      10.times do
        retrieved_values << results.receive
      end

      # All operations should succeed
      retrieved_values.compact.size.should eq(10)
      retrieved_values.should contain("value_0")
      retrieved_values.should contain("value_9")
    end
  end
end
