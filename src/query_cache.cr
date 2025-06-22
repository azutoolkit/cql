require "json"
require "digest/md5"
require "db"

module CQL
  # Query cache for storing and retrieving query results
  class QueryCache
    @@cache = {} of String => CacheEntry
    @@enabled = true
    @@default_ttl = 1.hour

    # Cache entry with TTL support
    class CacheEntry
      property value : String # JSON serialized value
      property expires_at : Int64 # Unix timestamp

      def initialize(@value : String, @expires_at : Int64)
      end

      def expired?
        Time.utc.to_unix > @expires_at
      end
    end

    # Cache a query result using a block
    # - **@param** cache_name [String] Unique cache name
    # - **@param** params [Hash] Query parameters for cache key generation
    # - **@param** ttl [Time::Span] Time to live (default: 1 hour)
    # - **@yield** [Void] Block to execute if cache miss
    # - **@return** [T] The cached or computed result
    def self.cache(cache_name : String, params : Hash, ttl : Time::Span = @@default_ttl, &block)
      return yield unless @@enabled

      cache_key = generate_cache_key(cache_name, params)

      # Check if cached and not expired
      if cached_entry = @@cache[cache_key]?
        unless cached_entry.expired?
          return JSON.parse(cached_entry.value)
        else
          @@cache.delete(cache_key)
        end
      end

      # Execute block and cache result
      result = yield
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

    # Generate a unique cache key from name and parameters
    # - **@param** name [String] Cache name
    # - **@param** params [Hash] Query parameters
    # - **@return** [String] Unique cache key
    private def self.generate_cache_key(name : String, params : Hash) : String
      # Convert all values to strings to avoid serialization issues
      string_params = params.transform_values { |v| v.to_s }
      params_hash = string_params.to_json
      "#{name}:#{Digest::MD5.hexdigest(params_hash)}"
    end

    # Get a cached result for the given key
    # - **@param** key [String] The cache key
    # - **@return** [Array(DB::Any)?] The cached result or nil if not found
    def self.get(key : String) : Array(DB::Any)?
      return nil unless @@enabled

      if cached_entry = @@cache[key]?
        unless cached_entry.expired?
          return JSON.parse(cached_entry.value).as_a
        else
          @@cache.delete(key)
        end
      end
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
        unless cached_entry.expired?
          return true
        else
          @@cache.delete(key)
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
      expired_keys = @@cache.select { |key, entry| entry.expired? }.keys
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
  end
end
