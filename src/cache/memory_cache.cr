require "./cache_interface"
require "json"

module CQL
  module Cache
    # In-memory cache implementation with advanced features
    class MemoryCache < CacheInterface
      # Cache entry with metadata
      private class CacheEntry
        property value : String
        property expires_at : Int64?
        property created_at : Int64
        property tags : Array(String)
        property access_count : Int32

        def initialize(@value : String, ttl : Time::Span?, @tags = [] of String)
          @created_at = Time.utc.to_unix_ms
          @expires_at = ttl ? @created_at + (ttl.total_milliseconds.to_i64) : nil
          @access_count = 0
        end

        def expired? : Bool
          if expires_at = @expires_at
            Time.utc.to_unix_ms > expires_at
          else
            false
          end
        end

        def touch : Nil
          @access_count += 1
        end
      end

      @entries = {} of String => CacheEntry
      @access_order = [] of String # Track access order for O(1) LRU eviction
      @tag_index = {} of String => Set(String)
      @version_store = {} of String => Int64
      @mutex = CQL::Compat::Mutex.new
      @max_size : Int32?
      @stats = {
        "hits"      => 0_i64,
        "misses"    => 0_i64,
        "sets"      => 0_i64,
        "deletes"   => 0_i64,
        "evictions" => 0_i64,
      }

      def initialize(@max_size : Int32? = nil)
      end

      # Basic cache operations
      def get(key : String) : String?
        @mutex.synchronize do
          if entry = @entries[key]?
            if entry.expired?
              remove_entry(key)
              @stats["misses"] += 1
              return nil
            end

            entry.touch
            update_access_order(key)
            @stats["hits"] += 1
            entry.value
          else
            @stats["misses"] += 1
            nil
          end
        end
      end

      def set(key : String, value : String, ttl : Time::Span? = nil) : Bool
        @mutex.synchronize do
          # Track if this is a new entry
          is_new = !@entries.has_key?(key)

          # Check size limits and evict if necessary
          if max_size = @max_size
            if @entries.size >= max_size && is_new
              evict_lru
            end
          end

          @entries[key] = CacheEntry.new(value, ttl)

          # Update access order tracking
          if is_new
            @access_order << key
          else
            update_access_order(key)
          end

          @stats["sets"] += 1
          true
        end
      end

      def delete(key : String) : Bool
        @mutex.synchronize do
          if @entries.delete(key)
            remove_from_tag_index(key)
            @stats["deletes"] += 1
            true
          else
            false
          end
        end
      end

      def exists?(key : String) : Bool
        @mutex.synchronize do
          if entry = @entries[key]?
            if entry.expired?
              remove_entry(key)
              false
            else
              true
            end
          else
            false
          end
        end
      end

      def clear : Bool
        @mutex.synchronize do
          @entries.clear
          @access_order.clear
          @tag_index.clear
          @version_store.clear
          @stats = {
            "hits"      => 0_i64,
            "misses"    => 0_i64,
            "sets"      => 0_i64,
            "deletes"   => 0_i64,
            "evictions" => 0_i64,
          }
          true
        end
      end

      # Batch operations
      def get_multi(keys : Array(String)) : Hash(String, String?)
        result = {} of String => String?
        keys.each do |key|
          result[key] = get(key)
        end
        result
      end

      def set_multi(data : Hash(String, String), ttl : Time::Span? = nil) : Bool
        data.each do |key, value|
          return false unless set(key, value, ttl)
        end
        true
      end

      def delete_multi(keys : Array(String)) : Int32
        count = 0
        keys.each do |key|
          count += 1 if delete(key)
        end
        count
      end

      # Tag-based operations
      def tag_cache(key : String, tags : Array(String)) : Bool
        @mutex.synchronize do
          if entry = @entries[key]?
            entry.tags.concat(tags)
            tags.each do |tag|
              @tag_index[tag] ||= Set(String).new
              @tag_index[tag] << key
            end
            true
          else
            false
          end
        end
      end

      def invalidate_tags(tags : Array(String)) : Int32
        @mutex.synchronize do
          keys_to_delete = Set(String).new

          tags.each do |tag|
            if tag_keys = @tag_index[tag]?
              keys_to_delete.concat(tag_keys)
              @tag_index.delete(tag)
            end
          end

          count = 0
          keys_to_delete.each do |key|
            if @entries.delete(key)
              remove_from_tag_index(key)
              count += 1
            end
          end

          @stats["deletes"] += count
          count
        end
      end

      # Version-based operations
      def get_version(key : String) : Int64?
        @mutex.synchronize do
          @version_store[key]?
        end
      end

      def increment_version(key : String) : Int64
        @mutex.synchronize do
          @version_store[key] = (@version_store[key]? || 0_i64) + 1_i64
        end
      end

      # Statistics and monitoring
      def stats : Hash(String, String | Int32 | Int64 | Float64)
        @mutex.synchronize do
          memory_usage = @entries.values.sum(&.value.bytesize)
          hit_rate = @stats["hits"] + @stats["misses"] > 0 ? (@stats["hits"].to_f / (@stats["hits"] + @stats["misses"]).to_f * 100.0) : 0.0

          {
            "type"               => "memory",
            "size"               => @entries.size,
            "max_size"           => @max_size || -1,
            "memory_usage_bytes" => memory_usage,
            "hits"               => @stats["hits"],
            "misses"             => @stats["misses"],
            "hit_rate_percent"   => hit_rate,
            "sets"               => @stats["sets"],
            "deletes"            => @stats["deletes"],
            "evictions"          => @stats["evictions"],
            "tags_count"         => @tag_index.size,
            "versions_count"     => @version_store.size,
          }
        end
      end

      def size : Int32
        cleanup_expired
        @mutex.synchronize do
          @entries.size
        end
      end

      # Maintenance operations
      def cleanup_expired : Int32
        @mutex.synchronize do
          expired_keys = [] of String
          @entries.each do |key, entry|
            expired_keys << key if entry.expired?
          end

          expired_keys.each do |key|
            remove_entry(key)
          end

          expired_keys.size
        end
      end

      private def remove_entry(key : String) : Nil
        @entries.delete(key)
        @access_order.delete(key)
        remove_from_tag_index(key)
      end

      private def remove_from_tag_index(key : String) : Nil
        @tag_index.each do |tag, keys|
          keys.delete(key)
          @tag_index.delete(tag) if keys.empty?
        end
      end

      # Move key to end of access order (most recently used)
      private def update_access_order(key : String) : Nil
        @access_order.delete(key)
        @access_order << key
      end

      # O(1) LRU eviction - take from front of access_order
      private def evict_lru : Nil
        while !@access_order.empty?
          key = @access_order.shift # Remove from front (least recently used)

          # Verify entry still exists (might have been deleted via tags or TTL)
          if @entries.has_key?(key)
            @entries.delete(key)
            remove_from_tag_index(key)
            @stats["evictions"] += 1
            return
          end
        end
      end
    end
  end
end
