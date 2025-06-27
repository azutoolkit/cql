require "log"

module CQL
  module Configure
    # 💾 Developer-friendly cache configuration for CQL
    # Use short, memorable property names that developers can easily remember
    class CacheConfig
      # === 🎯 CORE CACHE SETTINGS ===
      # Main cache enable/disable switch
      property on : Bool = false

      # Default time-to-live for cached items
      property ttl : Time::Span = 1.hour

      # Prefix for cache keys (useful for multi-app environments)
      property key_prefix : String = "cql"

      # Cache instance name
      property name : String = "cql"

      # === 💭 MEMORY CACHE ===
      # Enable in-memory caching
      property memory : Bool = true

      # Maximum number of items in memory cache
      property memory_size : Int32? = 1000

      # Track memory cache statistics
      property memory_stats : Bool = true

      # === 🌐 REQUEST CACHE ===
      # Enable per-request query caching (great for web apps)
      property request_cache : Bool = true

      # Maximum items per request cache
      property request_size : Int32 = 1000

      # Auto-clear request cache after each request
      property auto_clear : Bool = true

      # === 🧩 FRAGMENT CACHE ===
      # Enable fragment/partial caching
      property fragments : Bool = false

      # Enable versioning for fragments
      property fragment_versions : Bool = true

      # Enable tagging for fragments
      property fragment_tags : Bool = true

      # === ♻️ INVALIDATION ===
      # Invalidation strategy: "timestamp", "version", "transaction_aware"
      property invalidation : String = "timestamp"

      # Maximum age before automatic invalidation
      property max_age : Time::Span = 1.hour

      # === 📊 MONITORING ===
      # Enable cache statistics collection
      property stats : Bool = true

      # Enable cache operation logging
      property logging : Bool = false

      # Log level for cache operations
      property log_level : Log::Severity = Log::Severity::Debug

      # === 🧹 MAINTENANCE ===
      # Auto-cleanup expired items
      property auto_cleanup : Bool = true

      # How often to run cleanup
      property cleanup_interval : Time::Span = 5.minutes

      # Enable batch operations for better performance
      property batch_ops : Bool = true

      # === 🌐 MIDDLEWARE ===
      # Enable web framework middleware integration
      property middleware : Bool = false

      # HTTP header for request ID
      property request_id_header : String = "X-Request-ID"

      def initialize
        apply_smart_defaults
      end

      # === 🔍 HELPER METHODS (memorable syntax) ===

      # Check if cache is enabled
      def on? : Bool
        @on
      end

      # Check if memory cache is enabled
      def memory? : Bool
        @memory
      end

      # Check if request cache is enabled
      def request_cache? : Bool
        @request_cache
      end

      # Check if fragment cache is enabled
      def fragments? : Bool
        @fragments
      end

      # Check if statistics are enabled
      def stats? : Bool
        @stats
      end

      # Check if logging is enabled
      def logging? : Bool
        @logging
      end

      # Check if auto-cleanup is enabled
      def auto_cleanup? : Bool
        @auto_cleanup
      end

      # Check if middleware integration is enabled
      def middleware? : Bool
        @middleware
      end

      # === 🔧 VALIDATION ===

      def validate! : Nil
        if on?
          if memory_size && memory_size.not_nil! <= 0
            raise ArgumentError.new("memory_size must be positive")
          end

          if request_size <= 0
            raise ArgumentError.new("request_size must be positive")
          end

          unless ["timestamp", "version", "transaction_aware"].includes?(invalidation)
            raise ArgumentError.new("Invalid invalidation strategy: #{invalidation}")
          end

          if ttl.total_seconds <= 0
            raise ArgumentError.new("ttl must be positive")
          end
        end
      end

      # === 🏗️ FACTORY METHODS ===

      # Create CacheInterface configuration object
      def create_cache_interface_config : CQL::Cache::CacheConfig
        CQL::Cache::CacheConfig.new(
          default_ttl: ttl,
          max_size: memory_size,
          enable_versioning: fragment_versions?,
          enable_tagging: fragment_tags?,
          enable_statistics: stats?,
          key_prefix: key_prefix
        )
      end

      # Get invalidation strategy instance
      def create_invalidation_strategy : CQL::Cache::InvalidationStrategy
        case invalidation
        when "timestamp"
          CQL::Cache::TimestampInvalidation.new(max_age)
        when "version"
          CQL::Cache::VersionInvalidation.new
        when "transaction_aware"
          base_strategy = CQL::Cache::TimestampInvalidation.new(max_age)
          CQL::Cache::TransactionAwareInvalidation.new(base_strategy)
        else
          raise ArgumentError.new("Unknown invalidation strategy: #{invalidation}")
        end
      end

      # === ⚙️ SYSTEM SETUP ===

      # Configure the global cache system
      def setup_cache_system : Nil
        return unless on?

        # Configure main cache
        CQL::Cache::Cache.enabled = on?
        CQL::Cache::Cache.default_ttl = ttl
        CQL::Cache::Cache.cache_name = name

        # Configure request query cache
        if request_cache?
          CQL::Cache::RequestQueryCacheHelper.enabled = true
          # Request cache max size is handled internally by RequestQueryCache
        end

        # Enable middleware integration if requested
        if middleware?
          # This would be used by web frameworks to automatically integrate caching
        end
      end

      # === 📊 STATISTICS & MONITORING ===

      # Get comprehensive cache statistics
      def cache_statistics : Hash(String, String | Int32 | Int64 | Float64 | Bool)
        return {"enabled" => false.as(String | Int32 | Int64 | Float64 | Bool)} unless on?

        stats = {} of String => String | Int32 | Int64 | Float64 | Bool
        stats["enabled"] = on?
        stats["ttl_seconds"] = ttl.total_seconds.to_i
        stats["key_prefix"] = key_prefix
        stats["memory_enabled"] = memory?
        stats["request_cache_enabled"] = request_cache?
        stats["fragments_enabled"] = fragments?
        stats["invalidation_strategy"] = invalidation
        stats["stats_enabled"] = stats?

        stats
      end

      # Reset all cache statistics
      def reset_cache_statistics : Nil
        return unless on?

        CQL::Cache::Cache.reset_stats
        CQL::Cache::RequestQueryCacheHelper.clear if request_cache?
      end

      # Performance summary for all cache systems
      def performance_summary : String
        return "💾 Cache system is disabled" unless on?

        String.build do |io|
          io << "=== 💾 CQL Cache Performance Summary ===\n"
          io << "Status: #{on? ? "✅ Enabled" : "❌ Disabled"}\n"
          io << "Key Prefix: #{key_prefix}\n"
          io << "TTL: #{ttl.total_seconds.to_i} seconds\n"
          io << "Invalidation: #{invalidation}\n"
          io << "\n"

          # Main cache performance
          if on?
            io << CQL::Cache::Cache.performance_summary
            io << "\n"
          end

          # Request cache performance
          if request_cache?
            request_stats = CQL::Cache::RequestQueryCacheHelper.stats
            io << "=== 🌐 Request Query Cache ===\n"
            io << "Status: #{request_stats["enabled"]}\n"
            io << "Request ID: #{request_stats["request_id"]}\n"
            io << "Size: #{request_stats["size"]}/#{request_stats["max_size"]}\n"
            io << "Hit Rate: #{request_stats["hit_rate_percent"]}%\n"
          end
        end
      end

      private def apply_smart_defaults
        # Set environment-specific defaults
        env = ENV["CRYSTAL_ENV"]? || "development"

        case env
        when "production"
          @on = false # Disabled by default in production for safety
          @logging = false
          @log_level = Log::Severity::Info
          @memory_size = 5000
          @request_size = 2000
        when "test"
          @on = false # Disabled in tests by default
          @logging = false
          @memory_size = 100
          @request_size = 100
        when "development"
          @on = true
          @logging = true
          @log_level = Log::Severity::Debug
          @memory_size = 1000
          @request_size = 1000
        end
      end
    end
  end
end
