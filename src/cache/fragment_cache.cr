require "./cache_interface"
require "./invalidation_strategies"
require "digest/md5"
require "json"
require "db"

module CQL
  module Cache
    # Fragment caching for arbitrary parts of queries or result sets
    # Provides flexible caching with custom key generation and tag support
    class FragmentCache
      @cache : CacheInterface
      @strategy : InvalidationStrategy
      @config : CacheConfig

      def initialize(@cache : CacheInterface, @strategy : InvalidationStrategy, @config : CacheConfig = CacheConfig.new)
      end

      # Cache a fragment with automatic key generation
      def cache_fragment(fragment_name : String,
                         params : Hash(String, DB::Any) = {} of String => DB::Any,
                         tags : Array(String) = [] of String,
                         ttl : Time::Span? = nil,
                         &block : -> String) : String?
        cache_key = generate_fragment_key(fragment_name, params)
        cache_with_key(cache_key, tags, ttl || @config.default_ttl, &block)
      end

      # Cache with explicit key
      def cache_with_key(cache_key : String,
                         tags : Array(String) = [] of String,
                         ttl : Time::Span = @config.default_ttl,
                         &block : -> String) : String?
        # Check if already cached and valid
        if cached_value = get_cached(cache_key)
          return cached_value
        end

        # Execute the block and cache the result
        result = block.call
        result_string = result.to_s
        set_cached(cache_key, result_string, tags, ttl)
        result_string
      end

      # Get a cached fragment
      def get_fragment(fragment_name : String,
                       params : Hash(String, DB::Any) = {} of String => DB::Any) : String?
        cache_key = generate_fragment_key(fragment_name, params)
        get_cached(cache_key)
      end

      # Check if a fragment is cached
      def fragment_cached?(fragment_name : String,
                           params : Hash(String, DB::Any) = {} of String => DB::Any) : Bool
        cache_key = generate_fragment_key(fragment_name, params)
        cached?(cache_key)
      end

      # Delete a specific fragment
      def delete_fragment(fragment_name : String,
                          params : Hash(String, DB::Any) = {} of String => DB::Any) : Bool
        cache_key = generate_fragment_key(fragment_name, params)
        @cache.delete(cache_key)
      end

      # Invalidate fragments by tags
      def invalidate_tags(tags : Array(String)) : Int32
        @cache.invalidate_tags(tags)
      end

      # Generate cache key with consistent hashing
      def generate_fragment_key(fragment_name : String,
                                params : Hash(String, DB::Any) = {} of String => DB::Any) : String
        key_parts = [@config.key_prefix, "fragment", fragment_name]

        unless params.empty?
          # Sort params for consistent key generation
          sorted_params = params.to_a.sort_by(&.[0])
          param_string = sorted_params.map { |k, v| "#{k}=#{v}" }.join("&")
          param_hash = Digest::MD5.hexdigest(param_string)
          key_parts << param_hash
        end

        key_parts.join(":")
      end

      # Query fragment caching for database results
      def cache_query(sql : String,
                      query_params : Array(DB::Any) = [] of DB::Any,
                      cache_tags : Array(String) = [] of String,
                      ttl : Time::Span = @config.default_ttl,
                      &)
        # Generate key from SQL and parameters
        cache_key = generate_query_key(sql, query_params)

        if cached_json = get_cached(cache_key)
          begin
            parsed_result = JSON.parse(cached_json).as_a.map do |item|
              item.as_h.transform_values do |v|
                case v
                when .as_s?    then v.as_s
                when .as_i?    then v.as_i.to_i32
                when .as_i64?  then v.as_i64
                when .as_f?    then v.as_f
                when .as_f32?  then v.as_f32
                when .as_bool? then v.as_bool
                when .nil?     then nil
                else
                  v.to_s
                end.as(DB::Any)
              end
            end
            return parsed_result
          rescue JSON::ParseException
            # If cached data is malformed, fall through to execute query
          end
        end

        # Execute query and cache result
        result = yield
        result_json = result.to_json
        set_cached(cache_key, result_json, cache_tags, ttl)
        result
      end

      # Generate cache key for SQL queries
      def generate_query_key(sql : String, params : Array(DB::Any) = [] of DB::Any) : String
        query_signature = sql + params.map(&.to_s).join(",")
        query_hash = Digest::MD5.hexdigest(query_signature)
        "#{@config.key_prefix}:query:#{query_hash}"
      end

      # Statistics about fragment cache usage
      def stats : Hash(String, String | Int32 | Int64 | Float64)
        base_stats = @cache.stats
        base_stats.merge({
          "fragment_cache_enabled" => true,
          "invalidation_strategy"  => @strategy.class.name.split("::").last,
        })
      end

      private def get_cached(cache_key : String) : String?
        @cache.get(cache_key)
      end

      private def set_cached(cache_key : String, value : String, tags : Array(String), ttl : Time::Span) : Bool
        # Store the actual value
        result = @cache.set(cache_key, value, ttl)

        # Tag the cache entry if tags are provided
        @cache.tag_cache(cache_key, tags) unless tags.empty?

        result
      end

      private def cached?(cache_key : String) : Bool
        @cache.exists?(cache_key)
      end

      private def get_metadata(cache_key : String) : Hash(String, String)?
        metadata_key = "#{cache_key}:metadata"
        if metadata_json = @cache.get(metadata_key)
          begin
            JSON.parse(metadata_json).as_h.transform_values(&.as_s)
          rescue JSON::ParseException
            nil
          end
        end
      end

      private def set_metadata(cache_key : String, metadata : Hash(String, String)) : Bool
        metadata_key = "#{cache_key}:metadata"
        @cache.set(metadata_key, metadata.to_json)
      end
    end

    # Cache key builder for complex scenarios
    class CacheKeyBuilder
      @components : Array(String) = [] of String
      @params : Hash(String, DB::Any) = {} of String => DB::Any
      @prefix : String

      def initialize(@prefix = "cql")
      end

      # Add a component to the cache key
      def add_component(component : String) : self
        @components << component
        self
      end

      # Add a parameter that will be hashed into the key
      def add_param(key : String, value : DB::Any) : self
        @params[key] = value
        self
      end

      # Build the final cache key
      def build : String
        key_parts = [@prefix] + @components

        unless @params.empty?
          sorted_params = @params.to_a.sort_by(&.[0])
          param_string = sorted_params.map { |k, v| "#{k}=#{v}" }.join("&")
          param_hash = Digest::MD5.hexdigest(param_string)
          key_parts << param_hash
        end

        key_parts.join(":")
      end

      # Reset the builder for reuse
      def reset : self
        @components.clear
        @params.clear
        self
      end
    end
  end
end
