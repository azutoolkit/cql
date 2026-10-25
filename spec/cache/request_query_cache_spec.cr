require "../spec_helper"

private RequestCacheDB = CQL::Schema.define(:request_query_cache_spec, spec_sqlite_uri("request_query_cache_spec.db"), CQL::Adapter::SQLite) do
  table :things do
    primary :id, Int64, auto_increment: true
    text :name
  end
end

private NO_PARAMS = [] of DB::Any

private def tracked_stats(cache : CQL::Cache::RequestQueryCache)
  stats = cache.stats
  {stats["hits"], stats["misses"], stats["sets"]}
end

# Runs the block against the process-wide cache and restores its state afterwards.
private def with_singleton_cache(&)
  cache = CQL::Cache::RequestQueryCache.instance
  was_enabled = cache.enabled?
  cache.enabled = false
  begin
    yield cache
  ensure
    cache.end_request
    cache.enabled = was_enabled
  end
end

describe CQL::Cache::RequestQueryCache do
  describe "opt-in tracking" do
    it "is disabled by default and tracks nothing without a request" do
      cache = CQL::Cache::RequestQueryCache.new
      before = tracked_stats(cache)

      cache.with_cache("SELECT 1", NO_PARAMS) { :ran }.should eq(:ran)

      cache.enabled?.should be_false
      cache.size.should eq(0)
      tracked_stats(cache).should eq(before)
    end

    it "tracks nothing for queries run through the normal path when no request is active" do
      RequestCacheDB.exec("DROP TABLE IF EXISTS things")
      RequestCacheDB.exec("CREATE TABLE things (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)")
      RequestCacheDB.insert.into(:things).values(name: "a").commit

      with_singleton_cache do |cache|
        cache.end_request
        before = tracked_stats(cache)

        2.times { RequestCacheDB.query.from(:things).select(:name).all(as: String).should eq(["a"]) }

        cache.size.should eq(0)
        tracked_stats(cache).should eq(before)
      end
    ensure
      RequestCacheDB.exec("DROP TABLE IF EXISTS things")
    end

    it "tracks nothing through the helper when no request is active" do
      with_singleton_cache do |cache|
        cache.end_request
        before = tracked_stats(cache)

        CQL::Cache::RequestQueryCacheHelper.with_cache("SELECT 1", NO_PARAMS) { :ran }.should eq(:ran)

        cache.size.should eq(0)
        tracked_stats(cache).should eq(before)
      end
    end

    it "tracks queries once a request has started" do
      cache = CQL::Cache::RequestQueryCache.new
      cache.start_request("req-1")

      cache.with_cache("SELECT 1", NO_PARAMS) { }
      cache.with_cache("SELECT 1", NO_PARAMS) { }
      cache.with_cache("SELECT 2", NO_PARAMS) { }

      cache.size.should eq(2)
      stats = cache.stats
      stats["hits"].should eq(1)
      stats["misses"].should eq(2)
    end

    it "stops tracking and drops tracked queries when the request ends" do
      cache = CQL::Cache::RequestQueryCache.new
      cache.start_request("req-1")
      cache.with_cache("SELECT 1", NO_PARAMS) { }
      cache.size.should eq(1)

      cache.end_request
      after_end = tracked_stats(cache)

      cache.size.should eq(0)
      cache.with_cache("SELECT 1", NO_PARAMS) { :ran }.should eq(:ran)
      cache.size.should eq(0)
      tracked_stats(cache).should eq(after_end)
    end

    it "can still be enabled explicitly without a request" do
      cache = CQL::Cache::RequestQueryCache.new
      cache.enabled = true

      cache.with_cache("SELECT 1", NO_PARAMS) { }
      cache.with_cache("SELECT 1", NO_PARAMS) { }

      cache.enabled?.should be_true
      cache.size.should eq(1)
      cache.stats["hits"].should eq(1)
      cache.stats["misses"].should eq(1)
    end
  end

  describe "bounded size" do
    it "never holds more than max_size queries within a request" do
      cache = CQL::Cache::RequestQueryCache.new(max_size: 3)
      cache.start_request("req-1")

      10.times do |index|
        cache.with_cache("SELECT #{index}", NO_PARAMS) { }
        cache.size.should be <= 3
      end

      cache.size.should eq(3)
      cache.stats["max_size"].should eq(3)
    end

    it "never holds more than max_size queries when enabled explicitly" do
      cache = CQL::Cache::RequestQueryCache.new(max_size: 2)
      cache.enabled = true

      6.times { |index| cache.with_cache("SELECT 1", [index.to_i64] of DB::Any) { } }

      cache.size.should be <= 2
    end

    it "stays bounded and counts hits for params that are not equal to themselves" do
      cache = CQL::Cache::RequestQueryCache.new(max_size: 3)
      cache.start_request("req-1")

      8.times { cache.with_cache("SELECT ?", [Float64::NAN] of DB::Any) { } }

      cache.size.should be <= 3
      cache.stats["hits"].should eq(7)
      cache.stats["misses"].should eq(1)
    end
  end

  describe "overlapping requests" do
    it "keeps tracking while any request is still active" do
      cache = CQL::Cache::RequestQueryCache.new
      cache.start_request("req-a")
      cache.start_request("req-b")
      cache.with_cache("SELECT 1", NO_PARAMS) { }
      cache.end_request

      cache.enabled?.should be_true
      cache.with_cache("SELECT 2", NO_PARAMS) { }
      cache.size.should eq(2)

      cache.end_request

      cache.enabled?.should be_false
      cache.size.should eq(0)
      cache.with_cache("SELECT 3", NO_PARAMS) { }
      cache.size.should eq(0)
    end

    it "ignores an end_request without a matching start_request" do
      cache = CQL::Cache::RequestQueryCache.new
      cache.end_request
      cache.start_request("req-a")
      cache.with_cache("SELECT 1", NO_PARAMS) { }

      cache.size.should eq(1)
      cache.end_request
      cache.enabled?.should be_false
    end

    it "turns tracking off for every active request when disabled" do
      cache = CQL::Cache::RequestQueryCache.new
      cache.start_request("req-a")
      cache.start_request("req-b")

      cache.enabled = false

      cache.enabled?.should be_false
      cache.with_cache("SELECT 1", NO_PARAMS) { }
      cache.size.should eq(0)
    end
  end

  describe "cache keys" do
    it "hits for equal sql and params and misses for different params" do
      cache = CQL::Cache::RequestQueryCache.new
      cache.start_request("req-1")

      cache.with_cache("SELECT * FROM t WHERE a = ? AND b = ?", [1_i64, "x"] of DB::Any) { }
      cache.with_cache("SELECT * FROM t WHERE a = ? AND b = ?", [1_i64, "x"] of DB::Any) { }
      cache.stats["hits"].should eq(1)
      cache.stats["misses"].should eq(1)

      cache.with_cache("SELECT * FROM t WHERE a = ? AND b = ?", [2_i64, "x"] of DB::Any) { }
      cache.with_cache("SELECT * FROM t WHERE a = ? AND b = ?", [1_i64, "y"] of DB::Any) { }
      cache.stats["hits"].should eq(1)
      cache.stats["misses"].should eq(3)
    end

    it "distinguishes a string param from a number with the same text" do
      cache = CQL::Cache::RequestQueryCache.new
      cache.start_request("req-1")

      cache.with_cache("SELECT ?", ["1"] of DB::Any) { }
      cache.with_cache("SELECT ?", [1_i64] of DB::Any) { }

      cache.stats["hits"].should eq(0)
      cache.stats["misses"].should eq(2)
    end

    it "does not confuse sql text with params that concatenate to the same string" do
      cache = CQL::Cache::RequestQueryCache.new
      cache.start_request("req-1")

      cache.with_cache("SELECT ?", ["x"] of DB::Any) { }
      cache.with_cache(%(SELECT ?"x"), NO_PARAMS) { }

      cache.stats["hits"].should eq(0)
      cache.stats["misses"].should eq(2)
    end
  end

  describe "cache system setup" do
    it "leaves tracking off outside a request when request_cache is on" do
      with_singleton_cache do |cache|
        cache.enabled = false
        config = CQL::Configure::CacheConfig.new
        config.on = true
        config.request_cache = true
        cache_was_enabled = CQL::Cache::Cache.enabled?
        begin
          config.setup_cache_system
          cache.enabled?.should be_false
        ensure
          CQL::Cache::Cache.enabled = cache_was_enabled
        end
      end
    end
  end
end
