require "../compat"

module CQL
  module Cache
    # Interface defining the contract for cache implementations
    # Provides a common API for different cache backends (memory, Redis, etc.)
    abstract class CacheInterface
      # Basic cache operations
      abstract def get(key : String) : String?
      abstract def set(key : String, value : String, ttl : Time::Span? = nil) : Bool
      abstract def delete(key : String) : Bool
      abstract def exists?(key : String) : Bool
      abstract def clear : Bool

      # Batch operations for efficiency
      abstract def get_multi(keys : Array(String)) : Hash(String, String?)
      abstract def set_multi(data : Hash(String, String), ttl : Time::Span? = nil) : Bool
      abstract def delete_multi(keys : Array(String)) : Int32

      # Tag-based invalidation support
      abstract def tag_cache(key : String, tags : Array(String)) : Bool
      abstract def invalidate_tags(tags : Array(String)) : Int32

      # Version-based invalidation support
      abstract def get_version(key : String) : Int64?
      abstract def increment_version(key : String) : Int64

      # Statistics and monitoring
      abstract def stats : Hash(String, String | Int32 | Int64 | Float64)
      abstract def size : Int32
    end

    # Configuration for cache behavior
    class CacheConfig
      property default_ttl : Time::Span = 1.hour
      property max_size : Int32? = nil
      property enable_versioning : Bool = true
      property enable_tagging : Bool = true
      property enable_statistics : Bool = true
      property key_prefix : String = "cql"

      def initialize(@default_ttl = 1.hour, @max_size = nil,
                     @enable_versioning = true, @enable_tagging = true,
                     @enable_statistics = true, @key_prefix = "cql")
      end
    end
  end
end
