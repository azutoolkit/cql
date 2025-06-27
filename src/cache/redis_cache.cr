require "./cache_interface"
require "redis"
require "json"

module CQL
  module Cache
    # Redis cache implementation with advanced features
    class RedisCache < CacheInterface
      @redis : Redis::PooledClient
      @key_prefix : String
      @stats = {
        "hits"      => 0_i64,
        "misses"    => 0_i64,
        "sets"      => 0_i64,
        "deletes"   => 0_i64,
        "evictions" => 0_i64,
      }
      @mutex = Mutex.new

      # Configuration for Redis connection
      class Config
        property url : String = "redis://localhost:6379/0"
        property key_prefix : String = "cql"
        property connection_pool_size : Int32 = 25
        property connection_timeout : Time::Span = 5.seconds
        property command_timeout : Time::Span = 5.seconds
        property reconnect_attempts : Int32 = 3

        def initialize(@url = "redis://localhost:6379/0", @key_prefix = "cql",
                       @connection_pool_size = 25, @connection_timeout = 5.seconds,
                       @command_timeout = 5.seconds, @reconnect_attempts = 3)
        end
      end

      def initialize(config : Config = Config.new)
        @key_prefix = config.key_prefix
        @redis = Redis::PooledClient.new(
          url: config.url,
          pool_size: config.connection_pool_size,
          pool_timeout: config.connection_timeout.total_seconds
        )
      end

      def initialize(url : String, key_prefix : String = "cql")
        config = Config.new(url: url, key_prefix: key_prefix)
        initialize(config)
      end

      # Basic cache operations
      def get(key : String) : String?
        prefixed_key = prefixed_key(key)
        @mutex.synchronize do
          @stats["hits"] += 1 # Will be corrected if it's a miss
        end

        begin
          result = @redis.get(prefixed_key)
          if result.nil?
            @mutex.synchronize do
              @stats["hits"] -= 1
              @stats["misses"] += 1
            end
          end
          result
        rescue ex : Redis::Error
          @mutex.synchronize do
            @stats["hits"] -= 1
            @stats["misses"] += 1
          end
          nil
        end
      end

      def set(key : String, value : String, ttl : Time::Span? = nil) : Bool
        prefixed_key = prefixed_key(key)
        @mutex.synchronize do
          @stats["sets"] += 1
        end

        begin
          if ttl
            @redis.setex(prefixed_key, ttl.total_seconds.to_i, value)
          else
            @redis.set(prefixed_key, value)
          end
          true
        rescue ex : Redis::Error
          false
        end
      end

      def delete(key : String) : Bool
        prefixed_key = prefixed_key(key)
        @mutex.synchronize do
          @stats["deletes"] += 1
        end

        begin
          result = @redis.del(prefixed_key)
          result > 0
        rescue ex : Redis::Error
          false
        end
      end

      def exists?(key : String) : Bool
        prefixed_key = prefixed_key(key)
        begin
          @redis.exists(prefixed_key) > 0
        rescue ex : Redis::Error
          false
        end
      end

      def clear : Bool
        # Get all keys with our prefix and delete them
        pattern = "#{@key_prefix}:*"
        keys = @redis.keys(pattern)
        if keys.any?
          @redis.del(keys)
        end
        true
      rescue ex : Redis::Error
        false
      end

      # Batch operations for efficiency
      def get_multi(keys : Array(String)) : Hash(String, String?)
        result = {} of String => String?
        return result if keys.empty?

        prefixed_keys = keys.map { |key| prefixed_key(key) }
        begin
          values = @redis.mget(prefixed_keys)
          keys.each_with_index do |original_key, index|
            redis_value = values[index]?
            result[original_key] = redis_value ? redis_value.to_s : nil
          end
        rescue ex : Redis::Error
          # If batch operation fails, fall back to individual gets
          keys.each do |key|
            result[key] = get(key)
          end
        end
        result
      end

      def set_multi(data : Hash(String, String), ttl : Time::Span? = nil) : Bool
        return true if data.empty?

        begin
          if ttl
            # Redis doesn't have msetex, so we need to set them individually
            data.each do |key, value|
              return false unless set(key, value, ttl)
            end
          else
            # Use MSET for atomic multi-set without TTL
            prefixed_data = {} of String => String
            data.each do |key, value|
              prefixed_data[prefixed_key(key)] = value
            end
            @redis.mset(prefixed_data)
          end
          true
        rescue ex : Redis::Error
          false
        end
      end

      def delete_multi(keys : Array(String)) : Int32
        return 0 if keys.empty?

        prefixed_keys = keys.map { |key| prefixed_key(key) }
        begin
          @redis.del(prefixed_keys).to_i32
        rescue ex : Redis::Error
          # If batch operation fails, fall back to individual deletes
          count = 0
          keys.each do |key|
            count += 1 if delete(key)
          end
          count
        end
      end

      # Tag-based invalidation support
      def tag_cache(key : String, tags : Array(String)) : Bool
        return true if tags.empty?

        prefixed_key = prefixed_key(key)
        begin
          # Store tag mappings using Redis sets
          tags.each do |tag|
            tag_key = "#{@key_prefix}:tag:#{tag}"
            @redis.sadd(tag_key, prefixed_key)
          end

          # Also store the tags for this key for reverse lookup
          key_tags_key = "#{prefixed_key}:tags"
          @redis.sadd(key_tags_key, tags)
          true
        rescue ex : Redis::Error
          false
        end
      end

      def invalidate_tags(tags : Array(String)) : Int32
        return 0 if tags.empty?

        total_invalidated = 0
        begin
          tags.each do |tag|
            tag_key = "#{@key_prefix}:tag:#{tag}"

            # Get all keys associated with this tag
            keys = @redis.smembers(tag_key)

            if keys.any?
              # Delete the actual cache entries
              total_invalidated += @redis.del(keys)

              # Clean up tag associations
              keys.each do |key|
                key_tags_key = "#{key}:tags"
                @redis.srem(key_tags_key, tag)
              end
            end

            # Remove the tag key itself
            @redis.del(tag_key)
          end
        rescue ex : Redis::Error
          # Return whatever we managed to invalidate
        end

        @mutex.synchronize do
          @stats["deletes"] += total_invalidated
        end

        total_invalidated
      end

      # Version-based invalidation support
      def get_version(key : String) : Int64?
        version_key = "#{@key_prefix}:version:#{key}"
        begin
          version_str = @redis.get(version_key)
          version_str ? version_str.to_i64? : nil
        rescue ex : Redis::Error
          nil
        end
      end

      def increment_version(key : String) : Int64
        version_key = "#{@key_prefix}:version:#{key}"
        begin
          @redis.incr(version_key)
        rescue ex : Redis::Error
          1_i64
        end
      end

      # Statistics and monitoring
      def stats : Hash(String, String | Int32 | Int64 | Float64)
        @mutex.synchronize do
          hit_rate = @stats["hits"] + @stats["misses"] > 0 ? (@stats["hits"].to_f / (@stats["hits"] + @stats["misses"]).to_f * 100.0) : 0.0

          base_stats = {} of String => String | Int32 | Int64 | Float64
          base_stats["type"] = "redis"
          base_stats["hits"] = @stats["hits"]
          base_stats["misses"] = @stats["misses"]
          base_stats["hit_rate_percent"] = hit_rate
          base_stats["sets"] = @stats["sets"]
          base_stats["deletes"] = @stats["deletes"]
          base_stats["evictions"] = @stats["evictions"]
          base_stats["key_prefix"] = @key_prefix

          # Try to get Redis info
          begin
            redis_info = @redis.info
            # Parse useful Redis stats
            if redis_info.is_a?(String)
              redis_info.each_line do |line|
                next unless line.includes?(":")
                key, value = line.split(":", 2)
                case key.strip
                when "used_memory"
                  base_stats["redis_memory_usage_bytes"] = value.strip.to_i64? || 0_i64
                when "connected_clients"
                  base_stats["redis_connected_clients"] = value.strip.to_i32? || 0
                when "keyspace_hits"
                  base_stats["redis_keyspace_hits"] = value.strip.to_i64? || 0_i64
                when "keyspace_misses"
                  base_stats["redis_keyspace_misses"] = value.strip.to_i64? || 0_i64
                end
              end
            end
          rescue ex : Redis::Error
            # Redis info not available, continue with basic stats
          end

          base_stats
        end
      end

      def size : Int32
        # Count keys with our prefix
        pattern = "#{@key_prefix}:*"
        keys = @redis.keys(pattern)
        # Filter out metadata keys (tags, versions)
        actual_keys = keys.reject do |key|
          key_str = key.to_s
          key_str.includes?(":tag:") || key_str.includes?(":version:") || key_str.ends_with?(":tags")
        end
        actual_keys.size
      rescue ex : Redis::Error
        0
      end

      # Health check method
      def ping : Bool
        @redis.ping == "PONG"
      rescue ex : Redis::Error
        false
      end

      # Get Redis connection info
      def connection_info : String
        "Redis connection: #{@key_prefix} prefix"
      rescue ex : Redis::Error
        "Connection info unavailable: #{ex.message}"
      end

      private def prefixed_key(key : String) : String
        "#{@key_prefix}:#{key}"
      end
    end
  end
end
