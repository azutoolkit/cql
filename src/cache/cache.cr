require "json"
require "digest/md5"
require "db"
require "./cache_stats"
require "./cache_entry"
require "./cache_store"
require "./request_query_cache"
require "./middleware"

module CQL
  module Cache
    # Enhanced Query cache for storing and retrieving query results
    # Now supports multiple cache backends (Memory, Redis) via CacheStore
    class Cache
      @@enabled = true
      @@default_ttl = 1.hour
      @@default_cache_name = "cql"
      @@cache_store : CacheInterface?

      # Cache statistics
      @@stats = CacheStats.new

      # Configure cache store
      def self.configure(config : CacheStoreConfig)
        CacheStore.configure(config)
        @@cache_store = nil # Reset to pick up new configuration
      end

      # Configure from environment variables
      def self.configure_from_env
        CacheStore.configure_from_env
        @@cache_store = nil
      end

      # Get the cache store instance
      private def self.cache_store : CacheInterface
        @@cache_store ||= CacheStore.instance
      end

      # Set default cache name
      # - **@param** name [String] The default cache name to use
      def self.cache_name=(name : String)
        @@default_cache_name = name
      end

      # Get default cache name
      # - **@return** [String] The default cache name
      def self.cache_name : String
        @@default_cache_name
      end

      # Generate a cache key for SQL query and parameters
      # - **@param** sql [String] The SQL query
      # - **@param** params [Array] The query parameters
      # - **@param** cache_name [String?] Optional cache name (uses default if nil)
      # - **@return** [String] Unique cache key for the query
      def self.generate_cache_key(sql : String, params : Array, cache_name : String? = nil) : String
        # Convert params to strings to avoid serialization issues
        string_params = params.map(&.to_s)
        params_hash = string_params.to_json
        name = cache_name || @@default_cache_name
        "#{name}:#{Digest::MD5.hexdigest(sql + params_hash)}"
      end

      # Helper to run a block with caching if enabled
      # - **@param** key [String] The cache key
      # - **@param** ttl [Time::Span] Time to live (default: 1 hour)
      # - **@param** as_kind [Class] Type to cast the result to (optional)
      # - **@yield** [Void] Block to execute if cache miss
      # - **@return** [T] The cached or computed result
      def self.with_cache(key : String, ttl : Time::Span = @@default_ttl, as_kind : Class? = nil, &)
        return yield unless @@enabled

        start_time = Time.instant
        @@stats.total_requests += 1

        # Check if cached
        if cached_value = cache_store.get(key)
          @@stats.hits += 1
          @@stats.total_cache_time += (Time.instant - start_time).total_seconds
          begin
            return JSON.parse(cached_value)
          rescue JSON::ParseException
            # If cached data is malformed, fall through to execute block
          end
        end

        # Cache miss - execute block and cache result
        @@stats.misses += 1
        cache_time = Time.instant - start_time
        @@stats.total_cache_time += cache_time.total_seconds

        execution_start = Time.instant
        result = yield
        execution_time = Time.instant - execution_start
        @@stats.total_execution_time += execution_time.total_seconds

        # Cache the result
        cache_value = serialize_for_cache(result)
        cache_store.set(key, cache_value, ttl)

        result
      end

      # Check if the current query result is cached
      # - **@param** cache_key [String] The cache key to check
      # - **@return** [Bool] True if the query result is cached
      def self.cached?(cache_key : String) : Bool
        return false unless @@enabled
        cache_store.exists?(cache_key)
      end

      # Cache a query result using a block
      # - **@param** cache_name [String] Unique cache name
      # - **@param** params [Hash] Query parameters for cache key generation
      # - **@param** ttl [Time::Span] Time to live (default: 1 hour)
      # - **@yield** [Void] Block to execute if cache miss
      # - **@return** [T] The cached or computed result
      def self.cache(cache_name : String, params : Hash, ttl : Time::Span = @@default_ttl, &)
        return yield unless @@enabled

        start_time = Time.instant
        @@stats.total_requests += 1

        cache_key = generate_cache_key(cache_name, params)

        # Check if cached
        if cached_value = cache_store.get(cache_key)
          @@stats.hits += 1
          @@stats.total_cache_time += (Time.instant - start_time).total_seconds
          begin
            return JSON.parse(cached_value)
          rescue JSON::ParseException
            # If cached data is malformed, fall through to execute block
          end
        end

        # Cache miss - execute block and cache result
        @@stats.misses += 1
        cache_time = Time.instant - start_time
        @@stats.total_cache_time += cache_time.total_seconds

        execution_start = Time.instant
        result = yield
        execution_time = Time.instant - execution_start
        @@stats.total_execution_time += execution_time.total_seconds

        cache_value = serialize_for_cache(result)
        cache_store.set(cache_key, cache_value, ttl)

        result
      end

      # Serialize a value for caching
      # - **@param** value [T] The value to serialize
      # - **@return** [String] JSON string representation
      private def self.serialize_for_cache(value) : String
        case value
        when String, Int32, Int64, Float32, Float64, Bool, Nil
          value.to_json
        when Array, Hash
          String.build { |io| value.to_json(io) }
        else
          # For complex objects, try to convert to hash first
          if value.responds_to?(:to_h)
            String.build { |io| value.to_h.to_json(io) }
          else
            value.to_s.to_json
          end
        end
      end

      # Generate a unique cache key from name and parameters (for backward compatibility)
      # - **@param** name [String] Cache name
      # - **@param** params [Hash] Query parameters
      # - **@return** [String] Unique cache key
      private def self.generate_cache_key(name : String, params : Hash) : String
        # Convert all values to strings to avoid serialization issues
        string_params = params.transform_values(&.to_s)
        params_hash = string_params.to_json
        "#{name}:#{Digest::MD5.hexdigest(params_hash)}"
      end

      # Get a cached result for the given key
      # - **@param** key [String] The cache key
      # - **@return** [Array(DB::Any)?] The cached result or nil if not found
      def self.get(key : String) : Array(DB::Any)?
        return nil unless @@enabled

        start_time = Time.instant
        @@stats.total_requests += 1

        if cached_value = cache_store.get(key)
          @@stats.hits += 1
          @@stats.total_cache_time += (Time.instant - start_time).total_seconds
          begin
            parsed = JSON.parse(cached_value).as_a
            return parsed.map do |item|
              case item
              when .as_s?
                item.as_s.as(DB::Any)
              when .as_i?
                item.as_i.as(DB::Any)
              when .as_i64?
                item.as_i64.as(DB::Any)
              when .as_f?
                item.as_f.as(DB::Any)
              when .as_bool?
                item.as_bool.as(DB::Any)
              else
                nil.as(DB::Any)
              end
            end
          rescue JSON::ParseException
            @@stats.hits -= 1
            @@stats.misses += 1
            return nil
          end
        end

        @@stats.misses += 1
        @@stats.total_cache_time += (Time.instant - start_time).total_seconds
        nil
      end

      # Set a cached result for the given key
      # - **@param** key [String] The cache key
      # - **@param** value [Array(DB::Any)] The value to cache
      # - **@param** ttl [Time::Span] Time to live (default: 1 hour)
      def self.set(key : String, value : Array(DB::Any), ttl : Time::Span = @@default_ttl)
        return unless @@enabled
        cache_value = serialize_for_cache(value)
        cache_store.set(key, cache_value, ttl)
      end

      # Check if a key exists in the cache
      # - **@param** key [String] The cache key
      # - **@return** [Bool] True if the key exists
      def self.has_key?(key : String) : Bool
        return false unless @@enabled
        cache_store.exists?(key)
      end

      # Get the current cache size
      # - **@return** [Int32] The number of cached entries
      def self.size : Int32
        cache_store.size
      end

      # Clear all cached entries
      def self.clear
        cache_store.clear
      end

      # Enable or disable caching
      # - **@param** enabled [Bool] Whether to enable caching
      def self.enabled=(enabled : Bool)
        @@enabled = enabled
      end

      # Check if caching is enabled
      # - **@return** [Bool] True if caching is enabled
      def self.enabled? : Bool
        @@enabled
      end

      # Set default TTL for cache entries
      # - **@param** ttl [Time::Span] Default time to live
      def self.default_ttl=(ttl : Time::Span)
        @@default_ttl = ttl
      end

      # Get default TTL
      # - **@return** [Time::Span] Default time to live
      def self.default_ttl : Time::Span
        @@default_ttl
      end

      # Get cache statistics
      # - **@return** [CacheStats] Current cache statistics
      def self.stats : CacheStats
        @@stats
      end

      # Get detailed cache statistics as a hash
      # - **@return** [Hash] Detailed statistics
      def self.statistics : Hash
        # Merge our stats with cache store stats
        cache_store_stats = cache_store.stats

        base_stats = {
          "enabled"                   => @@enabled,
          "total_requests"            => @@stats.total_requests,
          "hits"                      => @@stats.hits,
          "misses"                    => @@stats.misses,
          "hit_rate"                  => @@stats.hit_rate.round(2),
          "miss_rate"                 => @@stats.miss_rate.round(2),
          "average_cache_time_ms"     => (@@stats.average_cache_time * 1000).round(2),
          "average_execution_time_ms" => (@@stats.average_execution_time * 1000).round(2),
          "total_cache_time_ms"       => (@@stats.total_cache_time * 1000).round(2),
          "total_execution_time_ms"   => (@@stats.total_execution_time * 1000).round(2),
          "uptime_seconds"            => @@stats.uptime.total_seconds.to_i,
          "cache_size"                => cache_store.size,
          "default_ttl_seconds"       => @@default_ttl.total_seconds.to_i,
          "cache_store_type"          => cache_store_stats["type"]? || "unknown",
        }

        # Merge cache store specific stats
        base_stats.merge(cache_store_stats)
      end

      # Reset cache statistics
      def self.reset_stats
        @@stats.reset
      end

      # Get cache performance summary as a formatted string
      # - **@return** [String] Formatted performance summary
      def self.performance_summary : String
        stats = statistics

        String.build do |io|
          io << "=== CQL Query Cache Performance Summary ===\n"
          io << "Status: #{stats["enabled"] ? "Enabled" : "Disabled"}\n"
          io << "Cache Store: #{stats["cache_store_type"]}\n"
          io << "Uptime: #{stats["uptime_seconds"]} seconds\n"
          io << "Total Requests: #{stats["total_requests"]}\n"
          io << "Cache Hits: #{stats["hits"]} (#{stats["hit_rate"]}%)\n"
          io << "Cache Misses: #{stats["misses"]} (#{stats["miss_rate"]}%)\n"
          io << "Cache Size: #{stats["cache_size"]} entries\n"

          if memory_usage = stats["memory_usage_bytes"]?
            io << "Memory Usage: #{memory_usage} bytes\n"
          end

          if redis_memory = stats["redis_memory_usage_bytes"]?
            io << "Redis Memory Usage: #{redis_memory} bytes\n"
          end

          io << "Average Cache Time: #{stats["average_cache_time_ms"]} ms\n"
          io << "Average Execution Time: #{stats["average_execution_time_ms"]} ms\n"
          io << "Total Cache Time: #{stats["total_cache_time_ms"]} ms\n"
          io << "Total Execution Time: #{stats["total_execution_time_ms"]} ms\n"
          io << "Default TTL: #{stats["default_ttl_seconds"]} seconds\n"
        end
      end

      # Direct access to underlying cache store for advanced usage
      def self.cache_store : CacheInterface
        cache_store
      end
    end
  end
end
