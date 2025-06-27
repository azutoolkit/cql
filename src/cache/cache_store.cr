require "./cache_interface"
require "./memory_cache"
require "./redis_cache"

module CQL
  module Cache
    # Cache store types
    enum CacheStoreType
      Memory
      Redis
    end

    # Configuration for cache store
    class CacheStoreConfig
      property type : CacheStoreType = CacheStoreType::Memory
      property default_ttl : Time::Span = 1.hour
      property key_prefix : String = "cql"
      property max_size : Int32? = nil

      # Memory cache specific options
      property memory_max_size : Int32? = nil

      # Redis cache specific options
      property redis_url : String = "redis://localhost:6379/0"
      property redis_pool_size : Int32 = 25
      property redis_timeout : Time::Span = 5.seconds

      def initialize(@type = CacheStoreType::Memory, @default_ttl = 1.hour,
                     @key_prefix = "cql", @max_size = nil,
                     @memory_max_size = nil, @redis_url = "redis://localhost:6379/0",
                     @redis_pool_size = 25, @redis_timeout = 5.seconds)
      end

      # Configure from environment variables
      def self.from_env : CacheStoreConfig
        config = new

        # Cache type
        if cache_type = ENV["CQL_CACHE_TYPE"]?
          case cache_type.downcase
          when "redis"
            config.type = CacheStoreType::Redis
          when "memory"
            config.type = CacheStoreType::Memory
          end
        end

        # General settings
        if ttl_str = ENV["CQL_CACHE_TTL"]?
          if ttl_seconds = ttl_str.to_i?
            config.default_ttl = ttl_seconds.seconds
          end
        end

        if prefix = ENV["CQL_CACHE_PREFIX"]?
          config.key_prefix = prefix
        end

        # Redis specific settings
        if redis_url = ENV["CQL_REDIS_URL"]? || ENV["REDIS_URL"]?
          config.redis_url = redis_url
          config.type = CacheStoreType::Redis # Auto-detect Redis when URL is provided
        end

        if pool_size_str = ENV["CQL_REDIS_POOL_SIZE"]?
          if pool_size = pool_size_str.to_i?
            config.redis_pool_size = pool_size
          end
        end

        if timeout_str = ENV["CQL_REDIS_TIMEOUT"]?
          if timeout_seconds = timeout_str.to_i?
            config.redis_timeout = timeout_seconds.seconds
          end
        end

        # Memory specific settings
        if max_size_str = ENV["CQL_MEMORY_CACHE_MAX_SIZE"]?
          if max_size = max_size_str.to_i?
            config.memory_max_size = max_size
          end
        end

        config
      end

      # Create from Hash (useful for configuration files)
      def self.from_hash(hash : Hash(String, String | Int32 | Int64 | Bool)) : CacheStoreConfig
        config = new

        if type_val = hash["type"]?
          case type_val.to_s.downcase
          when "redis"
            config.type = CacheStoreType::Redis
          when "memory"
            config.type = CacheStoreType::Memory
          end
        end

        if ttl_val = hash["default_ttl"]?
          if ttl_val.is_a?(Int32 | Int64)
            config.default_ttl = ttl_val.seconds
          end
        end

        if prefix_val = hash["key_prefix"]?
          config.key_prefix = prefix_val.to_s
        end

        if redis_url_val = hash["redis_url"]?
          config.redis_url = redis_url_val.to_s
        end

        if pool_size_val = hash["redis_pool_size"]?
          if pool_size_val.is_a?(Int32 | Int64)
            config.redis_pool_size = pool_size_val.to_i32
          end
        end

        if timeout_val = hash["redis_timeout"]?
          if timeout_val.is_a?(Int32 | Int64)
            config.redis_timeout = timeout_val.seconds
          end
        end

        if max_size_val = hash["memory_max_size"]?
          if max_size_val.is_a?(Int32 | Int64)
            config.memory_max_size = max_size_val.to_i32
          end
        end

        config
      end
    end

    # Factory class for creating cache store instances
    class CacheStore
      @@instance : CacheInterface?
      @@config : CacheStoreConfig?

      # Configure the cache store globally
      def self.configure(config : CacheStoreConfig)
        @@config = config
        @@instance = nil # Reset instance to use new config
      end

      # Configure from environment variables
      def self.configure_from_env
        configure(CacheStoreConfig.from_env)
      end

      # Configure from hash
      def self.configure_from_hash(hash : Hash(String, String | Int32 | Int64 | Bool))
        configure(CacheStoreConfig.from_hash(hash))
      end

      # Get the singleton cache instance
      def self.instance : CacheInterface
        if instance = @@instance
          return instance
        end

        config = @@config || CacheStoreConfig.new
        @@instance = create_cache(config)
      end

      # Create a new cache instance with specific configuration
      def self.create(config : CacheStoreConfig) : CacheInterface
        create_cache(config)
      end

      # Create cache with string type for convenience
      def self.create(type : String, key_prefix : String? = nil, redis_url : String? = nil, max_size : Int32? = nil, default_ttl : Time::Span? = nil) : CacheInterface
        cache_type = case type.downcase
                     when "redis"
                       CacheStoreType::Redis
                     when "memory"
                       CacheStoreType::Memory
                     else
                       raise ArgumentError.new("Unknown cache type: #{type}")
                     end

        config = CacheStoreConfig.new(type: cache_type)

        # Apply options
        config.key_prefix = key_prefix if key_prefix
        config.default_ttl = default_ttl if default_ttl
        config.redis_url = redis_url if redis_url
        config.memory_max_size = max_size if max_size

        create_cache(config)
      end

      # Reset the singleton instance (useful for testing)
      def self.reset
        @@instance = nil
        @@config = nil
      end

      # Get current configuration
      def self.config : CacheStoreConfig?
        @@config
      end

      private def self.create_cache(config : CacheStoreConfig) : CacheInterface
        case config.type
        when .redis?
          redis_config = RedisCache::Config.new(
            url: config.redis_url,
            key_prefix: config.key_prefix,
            connection_pool_size: config.redis_pool_size,
            connection_timeout: config.redis_timeout
          )
          RedisCache.new(redis_config)
        when .memory?
          MemoryCache.new(config.memory_max_size || config.max_size)
        else
          raise ArgumentError.new("Unsupported cache type: #{config.type}")
        end
      end
    end

    # Convenience methods for global cache access
    module GlobalCache
      # Get the global cache instance
      def self.instance : CacheInterface
        CacheStore.instance
      end

      # Cache a value with automatic key generation
      def self.cache(key : String, ttl : Time::Span? = nil, & : -> T) : T forall T
        cache_key = key

        if cached_value = instance.get(cache_key)
          return T.from_json(cached_value)
        end

        result = yield
        serialized = result.to_json
        instance.set(cache_key, serialized, ttl)
        result
      end

      # Get a cached value
      def self.get(key : String, type : T.class) : T? forall T
        if cached_value = instance.get(key)
          T.from_json(cached_value)
        end
      end

      # Set a cached value
      def self.set(key : String, value : T, ttl : Time::Span? = nil) : Bool forall T
        instance.set(key, value.to_json, ttl)
      end

      # Delete a cached value
      def self.delete(key : String) : Bool
        instance.delete(key)
      end

      # Check if a key exists
      def self.exists?(key : String) : Bool
        instance.exists?(key)
      end

      # Clear all cached values
      def self.clear : Bool
        instance.clear
      end

      # Get cache statistics
      def self.stats
        instance.stats
      end

      # Get cache size
      def self.size : Int32
        instance.size
      end
    end
  end
end
