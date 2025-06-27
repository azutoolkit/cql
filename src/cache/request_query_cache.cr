require "./cache_interface"
require "digest/md5"
require "db"

module CQL
  module Cache
    # Per-request query cache that automatically stores SQL query results
    # during a single request and clears when a new request begins.
    #
    # Features:
    # - Automatic cache key generation based on SQL + parameters
    # - Per-request lifecycle management
    # - Thread-safe operations
    # - Memory efficient with configurable max size
    # - Statistics and monitoring support
    class RequestQueryCache
      # Cache entry for storing query results
      private class QueryCacheEntry
        property result : String
        property created_at : Int64
        property access_count : Int32

        def initialize(@result : String, @created_at = Time.utc.to_unix)
          @access_count = 0
        end

        def touch
          @access_count += 1
        end
      end

      @cache = {} of String => QueryCacheEntry
      @request_id : String?
      @mutex = Mutex.new
      @max_size : Int32
      @enabled : Bool = true
      @stats = {
        "hits"   => 0_i64,
        "misses" => 0_i64,
        "sets"   => 0_i64,
        "clears" => 0_i64,
      }

      class_getter instance : RequestQueryCache = RequestQueryCache.new

      def initialize(@max_size : Int32 = 1000)
      end

      # Start a new request context - clears existing cache
      def start_request(request_id : String? = nil) : Nil
        @mutex.synchronize do
          @cache.clear
          @request_id = request_id || Random::Secure.hex(16)
          @stats["clears"] += 1
        end
      end

      # End current request context
      def end_request : Nil
        @mutex.synchronize do
          @cache.clear
          @request_id = nil
          @stats["clears"] += 1
        end
      end

      # Get current request ID
      def current_request_id : String?
        @request_id
      end

      # Check if cache is enabled
      def enabled? : Bool
        @enabled
      end

      # Enable/disable the cache
      def enabled=(@enabled : Bool) : Nil
      end

      # Generate cache key from SQL query and parameters
      private def cache_key(sql : String, params : Array(DB::Any)) : String
        # Create a stable hash from SQL + parameters
        content = sql + params.map(&.inspect).join(",")
        "qc:" + Digest::MD5.hexdigest(content)
      end

      # Get cached result for a query
      def get(sql : String, params : Array(DB::Any)) : Array(DB::Any) | DB::Any | Nil
        return nil unless @enabled

        key = cache_key(sql, params)

        @mutex.synchronize do
          if entry = @cache[key]?
            entry.touch
            @stats["hits"] += 1
            return entry.result
          else
            @stats["misses"] += 1
            return nil
          end
        end
      end

      # Store query result in cache
      def set(sql : String, params : Array(DB::Any), result : Array(DB::Any) | DB::Any) : Nil
        return unless @enabled

        key = cache_key(sql, params)

        @mutex.synchronize do
          # Evict old entries if we're at max size
          if @cache.size >= @max_size && !@cache.has_key?(key)
            evict_oldest
          end

          @cache[key] = QueryCacheEntry.new(result)
          @stats["sets"] += 1
        end
      end

      # Clear all cached queries
      def clear : Nil
        @mutex.synchronize do
          @cache.clear
          @stats["clears"] += 1
        end
      end

      # Get cache statistics
      def stats : Hash(String, String | Int32 | Int64 | Float64)
        @mutex.synchronize do
          total_queries = @stats["hits"] + @stats["misses"]
          hit_rate = total_queries > 0 ? (@stats["hits"].to_f / total_queries.to_f * 100.0).round(2) : 0.0

          {
            "enabled"          => @enabled.to_s,
            "request_id"       => @request_id || "none",
            "size"             => @cache.size,
            "max_size"         => @max_size,
            "hits"             => @stats["hits"],
            "misses"           => @stats["misses"],
            "sets"             => @stats["sets"],
            "clears"           => @stats["clears"],
            "hit_rate_percent" => hit_rate,
          }
        end
      end

      # Get cache size
      def size : Int32
        @mutex.synchronize do
          @cache.size
        end
      end

      # Check if a query has been executed before in this request
      def query_executed?(sql : String, params : Array(DB::Any)) : Bool
        return false unless @enabled
        key = cache_key(sql, params)
        @mutex.synchronize do
          @cache.has_key?(key)
        end
      end

      # Mark a query as executed
      def mark_query_executed(sql : String, params : Array(DB::Any)) : Nil
        return unless @enabled
        key = cache_key(sql, params)
        @mutex.synchronize do
          if @cache.has_key?(key)
            @stats["hits"] += 1
            if entry = @cache[key]?
              entry.touch
            end
          else
            @stats["misses"] += 1
            @cache[key] = QueryCacheEntry.new("executed", Time.utc.to_unix)
            @stats["sets"] += 1
          end
        end
      end

      # Simple cache tracking without result storage
      def with_cache(sql : String, params : Array(DB::Any), & : -> T) : T forall T
        return yield unless @enabled

        mark_query_executed(sql, params)
        yield
      end

      private def evict_oldest : Nil
        # Find the oldest entry (lowest access count, then oldest created_at)
        oldest_entry = @cache.min_by? do |_, entry|
          {entry.access_count, entry.created_at}
        end

        if oldest_entry
          key, _ = oldest_entry
          @cache.delete(key)
        end
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
      def self.with_cache(sql : String, params : Array(DB::Any), &block : -> T) : T forall T
        RequestQueryCache.instance.with_cache(sql, params, &block)
      end
    end
  end
end
