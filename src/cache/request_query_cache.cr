require "./cache_interface"
require "db"

module CQL
  module Cache
    # Per-request query cache that tracks SQL queries executed during a request.
    #
    # Tracking is opt-in: it runs while at least one request is active (between
    # `start_request` and `end_request`), or while explicitly enabled through `enabled=`.
    # When disabled, `with_cache` is a plain yield. The cache is process-wide, so
    # overlapping requests share the tracked statements and the counters.
    #
    # Entries are keyed by the SQL text plus a hash of the bound parameters, so no
    # parameter values are retained, and bounded by `max_size`; the oldest entry
    # (insertion order) is evicted first.
    class RequestQueryCache
      alias Key = {String, UInt64}
      alias Result = Array(DB::Any) | DB::Any

      private EXECUTED_MARKER = "executed"

      @cache = {} of Key => Result
      @request_id : String?
      @mutex = CQL::Compat::Mutex.new
      @max_size : Int32
      @explicitly_enabled = false
      @active_requests = 0
      @hits = 0_i64
      @misses = 0_i64
      @sets = 0_i64
      @clears = 0_i64

      class_getter instance : RequestQueryCache = RequestQueryCache.new

      def initialize(@max_size : Int32 = 1000)
      end

      # Starts a request context: clears the cache and enables tracking until the
      # matching `end_request`.
      def start_request(request_id : String? = nil) : Nil
        @mutex.synchronize do
          reset_cache
          @request_id = request_id || Random::Secure.hex(16)
          @active_requests += 1
        end
      end

      # Ends a request context. Once no request is active, clears the cache and stops
      # request-scoped tracking.
      def end_request : Nil
        @mutex.synchronize do
          @active_requests -= 1 if @active_requests > 0
          next unless @active_requests.zero?

          reset_cache
          @request_id = nil
        end
      end

      def current_request_id : String?
        @request_id
      end

      # True while any request is active or the cache was explicitly enabled.
      def enabled? : Bool
        @explicitly_enabled || @active_requests > 0
      end

      # Explicitly enables tracking outside requests; `false` disables tracking entirely,
      # including for requests that are still active.
      def enabled=(enabled : Bool) : Nil
        @mutex.synchronize do
          @explicitly_enabled = enabled
          @active_requests = 0 unless enabled
        end
      end

      # Get cached result for a query. Keys are the SQL plus a hash of the parameters,
      # so a stored result is advisory, not a guaranteed match for these exact values.
      def get(sql : String, params : Array(DB::Any)) : Result?
        return unless enabled?

        key = key_for(sql, params)
        @mutex.synchronize do
          found = true
          result = @cache.fetch(key) { found = false; nil }
          found ? (@hits += 1) : (@misses += 1)
          result
        end
      end

      # Store query result in cache
      def set(sql : String, params : Array(DB::Any), result : Result) : Nil
        return unless enabled?

        key = key_for(sql, params)
        @mutex.synchronize do
          next unless enabled?

          store(key, result)
          @sets += 1
        end
      end

      def clear : Nil
        @mutex.synchronize { reset_cache }
      end

      def stats : Hash(String, String | Int32 | Int64 | Float64)
        @mutex.synchronize do
          total_queries = @hits + @misses
          hit_rate = total_queries > 0 ? (@hits.to_f / total_queries.to_f * 100.0).round(2) : 0.0

          {
            "enabled"          => enabled?.to_s,
            "request_id"       => @request_id || "none",
            "size"             => @cache.size,
            "max_size"         => @max_size,
            "hits"             => @hits,
            "misses"           => @misses,
            "sets"             => @sets,
            "clears"           => @clears,
            "hit_rate_percent" => hit_rate,
          } of String => String | Int32 | Int64 | Float64
        end
      end

      def size : Int32
        @mutex.synchronize { @cache.size }
      end

      # Check if a query has been executed before in this request
      def query_executed?(sql : String, params : Array(DB::Any)) : Bool
        return false unless enabled?

        key = key_for(sql, params)
        @mutex.synchronize { @cache.has_key?(key) }
      end

      # Records a query execution, counting a hit when it was already seen.
      def mark_query_executed(sql : String, params : Array(DB::Any)) : Nil
        return unless enabled?

        key = key_for(sql, params)
        @mutex.synchronize do
          next unless enabled?

          if @cache.has_key?(key)
            @hits += 1
          else
            @misses += 1
            store(key, EXECUTED_MARKER)
            @sets += 1
          end
        end
      end

      # Simple cache tracking without result storage
      def with_cache(sql : String, params : Array(DB::Any), & : -> T) : T forall T
        mark_query_executed(sql, params) if enabled?
        yield
      end

      private def key_for(sql : String, params : Array(DB::Any)) : Key
        {sql, params.hash}
      end

      # Inserts with a single key lookup, then evicts the oldest entry if over the cap.
      private def store(key : Key, result : Result) : Nil
        @cache[key] = result
        @cache.shift? if @cache.size > @max_size
      end

      private def reset_cache : Nil
        @cache.clear
        @clears += 1
      end
    end

    # Convenience methods for the singleton instance
    module RequestQueryCacheHelper
      # Start a new request and clear query cache
      def self.start_request(request_id : String? = nil) : Nil
        RequestQueryCache.instance.start_request(request_id)
      end

      # End current request and clear query cache
      def self.end_request : Nil
        RequestQueryCache.instance.end_request
      end

      # Enable/disable query caching
      def self.enabled=(enabled : Bool) : Nil
        RequestQueryCache.instance.enabled = enabled
      end

      # Check if query caching is enabled
      def self.enabled? : Bool
        RequestQueryCache.instance.enabled?
      end

      # Get cache statistics
      def self.stats : Hash(String, String | Int32 | Int64 | Float64)
        RequestQueryCache.instance.stats
      end

      # Clear the query cache manually
      def self.clear : Nil
        RequestQueryCache.instance.clear
      end

      # Execute a query with caching
      def self.with_cache(sql : String, params : Array(DB::Any), & : -> T) : T forall T
        RequestQueryCache.instance.with_cache(sql, params) { yield }
      end
    end
  end
end
