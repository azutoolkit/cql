require "./cache_interface"

module CQL
  module Cache
    # Base interface for cache invalidation strategies
    abstract class InvalidationStrategy
      abstract def should_invalidate?(key : String, metadata : Hash(String, String)) : Bool
      abstract def generate_metadata(key : String) : Hash(String, String)
    end

    # Timestamp-based invalidation strategy
    # Invalidates cache entries based on their age
    class TimestampInvalidation < InvalidationStrategy
      @max_age : Time::Span

      def initialize(@max_age = 1.hour)
      end

      def should_invalidate?(key : String, metadata : Hash(String, String)) : Bool
        return true unless timestamp_str = metadata["timestamp"]?

        begin
          timestamp = Time.parse_rfc3339(timestamp_str)
          Time.utc - timestamp > @max_age
        rescue Time::Format::Error
          true # Invalidate if timestamp is malformed
        end
      end

      def generate_metadata(key : String) : Hash(String, String)
        {"timestamp" => Time.utc.to_rfc3339}
      end
    end

    # Version-based invalidation strategy
    # Uses version numbers to invalidate cache entries
    class VersionInvalidation < InvalidationStrategy
      @version_store = {} of String => Int64
      @mutex = Mutex.new

      def should_invalidate?(key : String, metadata : Hash(String, String)) : Bool
        return true unless cached_version_str = metadata["version"]?

        begin
          cached_version = cached_version_str.to_i64
          current_version = get_current_version(key)
          cached_version < current_version
        rescue ArgumentError
          true # Invalidate if version is malformed
        end
      end

      def generate_metadata(key : String) : Hash(String, String)
        version = get_current_version(key)
        {"version" => version.to_s}
      end

      def increment_version(key : String) : Int64
        @mutex.synchronize do
          @version_store[key] = (@version_store[key]? || 0_i64) + 1_i64
        end
      end

      def get_current_version(key : String) : Int64
        @mutex.synchronize do
          @version_store[key]? || 0_i64
        end
      end

      def reset_version(key : String) : Nil
        @mutex.synchronize do
          @version_store.delete(key)
        end
      end
    end

    # Transaction-aware invalidation strategy
    # Defers invalidation until after transaction commits
    class TransactionAwareInvalidation
      @pending_invalidations = Set(String).new
      @pending_tag_invalidations = Set(String).new
      @mutex = Mutex.new
      @base_strategy : InvalidationStrategy

      def initialize(@base_strategy : InvalidationStrategy)
      end

      # Mark keys for invalidation after transaction commits
      def mark_for_invalidation(keys : Array(String))
        @mutex.synchronize do
          keys.each { |key| @pending_invalidations << key }
        end
      end

      def mark_for_invalidation(key : String)
        mark_for_invalidation([key])
      end

      # Mark tags for invalidation after transaction commits
      def mark_tags_for_invalidation(tags : Array(String))
        @mutex.synchronize do
          tags.each { |tag| @pending_tag_invalidations << tag }
        end
      end

      # Execute pending invalidations (called after transaction commit)
      def execute_pending_invalidations(cache : CacheInterface)
        keys_to_invalidate = [] of String
        tags_to_invalidate = [] of String

        @mutex.synchronize do
          keys_to_invalidate = @pending_invalidations.to_a
          tags_to_invalidate = @pending_tag_invalidations.to_a
          @pending_invalidations.clear
          @pending_tag_invalidations.clear
        end

        # Invalidate keys
        cache.delete_multi(keys_to_invalidate) unless keys_to_invalidate.empty?

        # Invalidate tags
        cache.invalidate_tags(tags_to_invalidate) unless tags_to_invalidate.empty?

        Log.debug { "Transaction-aware invalidation: invalidated #{keys_to_invalidate.size} keys and #{tags_to_invalidate.size} tags" } unless keys_to_invalidate.empty? && tags_to_invalidate.empty?
      end

      # Clear pending invalidations (called on transaction rollback)
      def clear_pending_invalidations
        @mutex.synchronize do
          @pending_invalidations.clear
          @pending_tag_invalidations.clear
        end
      end

      # Check if the base strategy would invalidate
      def should_invalidate?(key : String, metadata : Hash(String, String)) : Bool
        @base_strategy.should_invalidate?(key, metadata)
      end

      def generate_metadata(key : String) : Hash(String, String)
        @base_strategy.generate_metadata(key)
      end
    end
  end
end
