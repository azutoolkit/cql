module CQL
  # Cache statistics tracking
  class CacheStats
    property hits : Int64
    property misses : Int64
    property total_requests : Int64
    property total_cache_time : Float64 # Total time spent on cache operations in seconds
    property total_execution_time : Float64 # Total time spent on block execution in seconds
    property start_time : Int64

    def initialize
      @hits = 0_i64
      @misses = 0_i64
      @total_requests = 0_i64
      @total_cache_time = 0.0
      @total_execution_time = 0.0
      @start_time = Time.utc.to_unix
    end

    def hit_rate : Float64
      return 0.0 if @total_requests == 0
      @hits.to_f / @total_requests.to_f * 100.0
    end

    def miss_rate : Float64
      return 0.0 if @total_requests == 0
      @misses.to_f / @total_requests.to_f * 100.0
    end

    def average_cache_time : Float64
      return 0.0 if @total_requests == 0
      @total_cache_time / @total_requests.to_f
    end

    def average_execution_time : Float64
      return 0.0 if @total_requests == 0
      @total_execution_time / @total_requests.to_f
    end

    def uptime : Time::Span
      Time::Span.new(seconds: Time.utc.to_unix - @start_time)
    end

    def reset
      @hits = 0_i64
      @misses = 0_i64
      @total_requests = 0_i64
      @total_cache_time = 0.0
      @total_execution_time = 0.0
      @start_time = Time.utc.to_unix
    end
  end
end
