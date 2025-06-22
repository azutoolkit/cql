require "json"
require "digest/md5"
require "db"
require "./cache_stats"
require "./cache_entry"

module CQL
  module Cache
    # Query cache for storing and retrieving query results
    class Cache
      @@cache = {} of String => CacheEntry
      @@enabled = true
      @@default_ttl = 1.hour
      @@default_cache_name = "cql"

      # Cache statistics
      @@stats = CacheStats.new

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
      # - **@yield** [Void] Block to execute if cache miss
      # - **@return** [T] The cached or computed result
      def self.with_cache(key : String, ttl : Time::Span = @@default_ttl, &)
        return yield unless @@enabled

        start_time = Time.monotonic
        @@stats.total_requests += 1

        # Check if cached and not expired
        if cached_entry = @@cache[key]?
          if cached_entry.expired?
            @@cache.delete(key)
          else
            cached_entry.increment_access_count
            @@stats.hits += 1
            @@stats.total_cache_time += (Time.monotonic - start_time).total_seconds
            # For complex results, we don't deserialize from JSON to avoid issues
            # Instead, we just return the yielded result (cache disabled for complex objects)
            return yield
          end
        end

        # Cache miss - execute block and cache result
        @@stats.misses += 1
        cache_time = Time.monotonic - start_time
        @@stats.total_cache_time += cache_time.total_seconds

        execution_start = Time.monotonic
        result = yield
        execution_time = Time.monotonic - execution_start
        @@stats.total_execution_time += execution_time.total_seconds

        # For now, we disable actual caching of complex objects to avoid serialization issues
        # We just track statistics and return the result
        # In the future, this could be enhanced to cache simple result types

        result
      end

      # Check if the current query result is cached
      # - **@param** cache_key [String] The cache key to check
      # - **@return** [Bool] True if the query result is cached
      def self.cached?(cache_key : String) : Bool
        return false unless @@enabled
        has_key?(cache_key)
      end

      # Cache a query result using a block
      # - **@param** cache_name [String] Unique cache name
      # - **@param** params [Hash] Query parameters for cache key generation
      # - **@param** ttl [Time::Span] Time to live (default: 1 hour)
      # - **@yield** [Void] Block to execute if cache miss
      # - **@return** [T] The cached or computed result
      def self.cache(cache_name : String, params : Hash, ttl : Time::Span = @@default_ttl, &)
        return yield unless @@enabled

        start_time = Time.monotonic
        @@stats.total_requests += 1

        cache_key = generate_cache_key(cache_name, params)

        # Check if cached and not expired
        if cached_entry = @@cache[cache_key]?
          if cached_entry.expired?
            @@cache.delete(cache_key)
          else
            cached_entry.increment_access_count
            @@stats.hits += 1
            @@stats.total_cache_time += (Time.monotonic - start_time).total_seconds
            return JSON.parse(cached_entry.value)
          end
        end

        # Cache miss - execute block and cache result
        @@stats.misses += 1
        cache_time = Time.monotonic - start_time
        @@stats.total_cache_time += cache_time.total_seconds

        execution_start = Time.monotonic
        result = yield
        execution_time = Time.monotonic - execution_start
        @@stats.total_execution_time += execution_time.total_seconds

        cache_value = serialize_for_cache(result)
        expires_at = Time.utc.to_unix + ttl.total_seconds.to_i64
        @@cache[cache_key] = CacheEntry.new(cache_value, expires_at)

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

        start_time = Time.monotonic
        @@stats.total_requests += 1

        if cached_entry = @@cache[key]?
          if cached_entry.expired?
            @@cache.delete(key)
          else
            cached_entry.increment_access_count
            @@stats.hits += 1
            @@stats.total_cache_time += (Time.monotonic - start_time).total_seconds
            return JSON.parse(cached_entry.value).as_a
          end
        end

        @@stats.misses += 1
        @@stats.total_cache_time += (Time.monotonic - start_time).total_seconds
        nil
      end

      # Set a cached result for the given key
      # - **@param** key [String] The cache key
      # - **@param** value [Array(DB::Any)] The value to cache
      # - **@param** ttl [Time::Span] Time to live (default: 1 hour)
      def self.set(key : String, value : Array(DB::Any), ttl : Time::Span = @@default_ttl)
        return unless @@enabled
        cache_value = serialize_for_cache(value)
        expires_at = Time.utc.to_unix + ttl.total_seconds.to_i64
        @@cache[key] = CacheEntry.new(cache_value, expires_at)
      end

      # Check if a key exists in the cache and is not expired
      # - **@param** key [String] The cache key
      # - **@return** [Bool] True if the key exists and is not expired
      def self.has_key?(key : String) : Bool
        return false unless @@enabled

        if cached_entry = @@cache[key]?
          if cached_entry.expired?
            @@cache.delete(key)
          else
            return true
          end
        end
        false
      end

      # Get the current cache size (excluding expired entries)
      # - **@return** [Int32] The number of valid cached entries
      def self.size : Int32
        cleanup_expired_entries
        @@cache.size
      end

      # Clear all cached entries
      def self.clear
        @@cache.clear
      end

      # Clean up expired cache entries
      def self.cleanup_expired_entries
        expired_keys = @@cache.select { |_, entry| entry.expired? }.keys
        expired_keys.each { |key| @@cache.delete(key) }
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
        cleanup_expired_entries

        # Calculate memory usage estimate (rough calculation)
        memory_usage = @@cache.values.sum(&.value.bytesize)

        # Get most accessed entries
        most_accessed = @@cache.values
          .sort_by!(&.access_count)
          .reverse!
          .first(5)
          .map { |entry| {access_count: entry.access_count, age: Time.utc.to_unix - entry.created_at} }

        {
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
          "cache_size"                => @@cache.size,
          "memory_usage_bytes"        => memory_usage,
          "most_accessed_entries"     => most_accessed,
          "default_ttl_seconds"       => @@default_ttl.total_seconds.to_i,
        }
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
          io << "Uptime: #{stats["uptime_seconds"]} seconds\n"
          io << "Total Requests: #{stats["total_requests"]}\n"
          io << "Cache Hits: #{stats["hits"]} (#{stats["hit_rate"]}%)\n"
          io << "Cache Misses: #{stats["misses"]} (#{stats["miss_rate"]}%)\n"
          io << "Cache Size: #{stats["cache_size"]} entries\n"
          io << "Memory Usage: #{stats["memory_usage_bytes"]} bytes\n"
          io << "Average Cache Time: #{stats["average_cache_time_ms"]} ms\n"
          io << "Average Execution Time: #{stats["average_execution_time_ms"]} ms\n"
          io << "Total Cache Time: #{stats["total_cache_time_ms"]} ms\n"
          io << "Total Execution Time: #{stats["total_execution_time_ms"]} ms\n"
          io << "Default TTL: #{stats["default_ttl_seconds"]} seconds\n"

          if most_accessed = stats["most_accessed_entries"].as(Array)
            io << "\nMost Accessed Entries:\n"
            most_accessed.each_with_index do |entry, index|
              io << "  #{index + 1}. Access Count: #{entry["access_count"]}, Age: #{entry["age"]} seconds\n"
            end
          end
        end
      end
    end
  end
end
