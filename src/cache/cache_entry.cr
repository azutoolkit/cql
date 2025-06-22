module CQL
  module Cache
    # Cache entry with TTL support
    class CacheEntry
      property value : String       # JSON serialized value
      property expires_at : Int64   # Unix timestamp
      property created_at : Int64   # Unix timestamp
      property access_count : Int32 # Number of times accessed

      def initialize(@value : String, @expires_at : Int64)
        @created_at = Time.utc.to_unix
        @access_count = 0
      end

      def expired?
        Time.utc.to_unix > @expires_at
      end

      def increment_access_count
        @access_count += 1
      end
    end
  end
end
