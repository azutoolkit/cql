require "./cache_interface"
require "db"

module CQL
  module Cache
    # Per-request query tracker: counts the SQL statements a request runs, so repeated ones (an N+1, a duplicated
    # lookup) show up. It stores and serves no rows: `with_cache` always runs its block.
    #
    # Tracking is opt-in. A request is the fiber that called `start_request`, until its `end_request`: each request
    # fiber has its own request id, statements and counters, so concurrent requests do not see or reset each
    # other's. Queries run by a fiber the request spawns are not tracked (that fiber has no request). Outside a
    # request nothing is tracked, unless tracking is turned on with `enabled = true`; those statements go to one
    # process-wide tracker.
    #
    # Entries are keyed by the SQL text plus a hash of the bound parameters, so no parameter values are retained,
    # and bounded by `max_size` per request; the oldest entry (insertion order) is evicted first.
    #
    # A request fiber that dies without `end_request` leaves its entry behind until the next `start_request` that
    # finds at least `SWEEP_THRESHOLD` entries (or twice as many as the last sweep left, a bound that `end_request`
    # lowers again as entries go), which drops every entry whose fiber is dead.
    class RequestQueryCache
      alias Key = {String, UInt64}
      alias Result = Array(DB::Any) | DB::Any

      private EXECUTED_MARKER = "executed"
      SWEEP_THRESHOLD = 64

      # The statements and counters of one request, or of the process-wide tracker.
      private class Tracker
        getter entries = {} of Key => Result
        property request_id : String?
        property depth = 0
        property hits = 0_i64
        property misses = 0_i64
        property sets = 0_i64
        property clears = 0_i64

        def initialize(@max_size : Int32)
        end

        # Inserts with a single key lookup, then evicts the oldest entry if over the cap.
        def store(key : Key, result : Result) : Nil
          @entries[key] = result
          @entries.shift? if @entries.size > @max_size
        end
      end

      @requests = {} of Fiber => Tracker
      @mutex = CQL::Compat::Mutex.new
      @max_size : Int32
      @explicitly_enabled = false
      @sweep_at = SWEEP_THRESHOLD
      # Totals for the process, what `stats` reports outside a request.
      @hits = 0_i64
      @misses = 0_i64
      @sets = 0_i64
      @clears = 0_i64

      class_getter instance : RequestQueryCache = RequestQueryCache.new

      def initialize(@max_size : Int32 = 1000)
        @unscoped = Tracker.new(@max_size)
      end

      # Starts a request on the current fiber: clears its statements and tracks until the matching
      # `end_request`. A nested `start_request` on the same fiber clears them again and needs its own `end_request`.
      def start_request(request_id : String? = nil) : Nil
        request_id ||= Random::Secure.hex(16)
        @mutex.synchronize do
          sweep_dead_requests if @requests.size >= @sweep_at
          tracker = @requests[Fiber.current] ||= Tracker.new(@max_size)
          reset(tracker)
          tracker.request_id = request_id
          tracker.depth += 1
        end
      end

      # Ends the current fiber's request; once its last `start_request` is matched, drops its state.
      # Does nothing on a fiber without a request.
      def end_request : Nil
        @mutex.synchronize do
          fiber = Fiber.current
          tracker = @requests[fiber]?
          next unless tracker

          tracker.depth -= 1
          next if tracker.depth > 0

          reset(tracker)
          @requests.delete(fiber)
          @sweep_at = Math.min(@sweep_at, sweep_bound)
        end
      end

      # The current fiber's request id; nil outside a request.
      def current_request_id : String?
        @mutex.synchronize { @requests[Fiber.current]?.try &.request_id }
      end

      # The number of request fibers with state: requests in flight, plus fibers that ended without calling
      # `end_request` and have not been swept yet.
      def active_requests : Int32
        @mutex.synchronize { @requests.size }
      end

      # True on a fiber with a request, or everywhere once explicitly enabled.
      def enabled? : Bool
        @mutex.synchronize { !current_tracker.nil? }
      end

      # Explicitly enables tracking outside requests; `false` disables tracking entirely,
      # including for requests that are still active.
      def enabled=(enabled : Bool) : Nil
        @mutex.synchronize do
          @explicitly_enabled = enabled
          next if enabled

          @requests.clear
          @sweep_at = SWEEP_THRESHOLD
        end
      end

      # Get cached result for a query. Keys are the SQL plus a hash of the parameters,
      # so a stored result is advisory, not a guaranteed match for these exact values.
      def get(sql : String, params : Array(DB::Any)) : Result?
        key = key_for(sql, params)
        @mutex.synchronize do
          tracker = current_tracker
          next unless tracker

          found = true
          result = tracker.entries.fetch(key) { found = false; nil }
          found ? count_hit(tracker) : count_miss(tracker)
          result
        end
      end

      # Store query result in cache
      def set(sql : String, params : Array(DB::Any), result : Result) : Nil
        key = key_for(sql, params)
        @mutex.synchronize do
          tracker = current_tracker
          next unless tracker

          tracker.store(key, result)
          count_set(tracker)
        end
      end

      # Drops the current request's statements (outside a request, the process-wide tracker's); keeps the id.
      def clear : Nil
        @mutex.synchronize { reset(@requests[Fiber.current]? || @unscoped) }
      end

      # Inside a request, its id, size and counters. Outside one, `request_id` is "none", `size` is the
      # process-wide tracker's, and `hits`, `misses`, `sets` and `clears` are totals for the process.
      def stats : Hash(String, String | Int32 | Int64 | Float64)
        @mutex.synchronize do
          request = @requests[Fiber.current]?
          hits, misses, sets, clears = request ? {request.hits, request.misses, request.sets, request.clears} : {@hits, @misses, @sets, @clears}
          total_queries = hits + misses
          hit_rate = total_queries > 0 ? (hits.to_f / total_queries.to_f * 100.0).round(2) : 0.0

          {
            "enabled"          => (!current_tracker.nil?).to_s,
            "request_id"       => request.try(&.request_id) || "none",
            "size"             => (request || @unscoped).entries.size,
            "max_size"         => @max_size,
            "hits"             => hits,
            "misses"           => misses,
            "sets"             => sets,
            "clears"           => clears,
            "hit_rate_percent" => hit_rate,
          } of String => String | Int32 | Int64 | Float64
        end
      end

      # Statements tracked for the current request (outside a request, by the process-wide tracker).
      def size : Int32
        @mutex.synchronize { (@requests[Fiber.current]? || @unscoped).entries.size }
      end

      # Check if a query has been executed before in this request
      def query_executed?(sql : String, params : Array(DB::Any)) : Bool
        key = key_for(sql, params)
        @mutex.synchronize { current_tracker.try(&.entries.has_key?(key)) || false }
      end

      # Records a query execution, counting a hit when it was already seen.
      def mark_query_executed(sql : String, params : Array(DB::Any)) : Nil
        key = key_for(sql, params)
        @mutex.synchronize do
          tracker = current_tracker
          next unless tracker

          if tracker.entries.has_key?(key)
            count_hit(tracker)
          else
            count_miss(tracker)
            tracker.store(key, EXECUTED_MARKER)
            count_set(tracker)
          end
        end
      end

      # Simple cache tracking without result storage
      def with_cache(sql : String, params : Array(DB::Any), & : -> T) : T forall T
        mark_query_executed(sql, params) if tracking_anywhere?
        yield
      end

      # A lock-free first check, so a query outside any request does not take the lock. Both reads are unlocked:
      # `@explicitly_enabled` is a single Bool, and `Hash#empty?` is `@size == 0`, one aligned Int32 read (`[]=`,
      # `delete`, `clear` and a rehash update `@size` with single stores), so neither can tear. Either can be stale: that costs one lock taken for nothing, or briefly misses a
      # tracker another fiber just added (a query on that fiber itself sees its own entry). `mark_query_executed`
      # decides under the lock.
      private def tracking_anywhere? : Bool
        @explicitly_enabled || !@requests.empty?
      end

      private def key_for(sql : String, params : Array(DB::Any)) : Key
        {sql, params.hash}
      end

      # The tracker of the current fiber's request, else the process-wide one when explicitly enabled. Call it
      # under the lock.
      private def current_tracker : Tracker?
        @requests[Fiber.current]? || (@explicitly_enabled ? @unscoped : nil)
      end

      private def sweep_dead_requests : Nil
        @requests.reject! { |fiber, _| fiber.dead? }
        @sweep_at = sweep_bound
      end

      private def sweep_bound : Int32
        Math.max(SWEEP_THRESHOLD, @requests.size * 2)
      end

      private def reset(tracker : Tracker) : Nil
        tracker.entries.clear
        tracker.clears += 1
        @clears += 1
      end

      private def count_hit(tracker : Tracker) : Nil
        tracker.hits += 1
        @hits += 1
      end

      private def count_miss(tracker : Tracker) : Nil
        tracker.misses += 1
        @misses += 1
      end

      private def count_set(tracker : Tracker) : Nil
        tracker.sets += 1
        @sets += 1
      end
    end

    # Convenience methods for the singleton instance
    module RequestQueryCacheHelper
      # Start a new request and clear query cache
      def self.start_request(request_id : String? = nil) : Nil
        RequestQueryCache.instance.start_request(request_id)
      end

      # End current request and clear query cache
      def self.end_request : Nil
        RequestQueryCache.instance.end_request
      end

      # Enable/disable query caching
      def self.enabled=(enabled : Bool) : Nil
        RequestQueryCache.instance.enabled = enabled
      end

      # Check if query caching is enabled
      def self.enabled? : Bool
        RequestQueryCache.instance.enabled?
      end

      # Get cache statistics
      def self.stats : Hash(String, String | Int32 | Int64 | Float64)
        RequestQueryCache.instance.stats
      end

      # Clear the query cache manually
      def self.clear : Nil
        RequestQueryCache.instance.clear
      end

      # Execute a query with caching
      def self.with_cache(sql : String, params : Array(DB::Any), & : -> T) : T forall T
        RequestQueryCache.instance.with_cache(sql, params) { yield }
      end
    end
  end
end
