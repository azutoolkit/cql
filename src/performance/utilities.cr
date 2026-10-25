# Shared utilities for performance monitoring
# Consolidates common functionality to reduce code duplication

require "log"
require "colorize"
require "../compat"

module CQL::Performance
  # Timing utilities
  module TimingUtils
    def measure_execution(&)
      start_time = Time.instant
      result = yield
      execution_time = Time.instant - start_time
      {result, execution_time}
    end

    def format_duration(duration : Time::Span) : String
      ms = duration.total_milliseconds
      case ms
      when .>=(1000)
        "#{(ms / 1000).round(2)}s"
      when .>=(1)
        "#{ms.round(2)}ms"
      else
        "#{(ms * 1000).round(2)}μs"
      end
    end

    def categorize_duration(duration : Time::Span,
                            slow_threshold : Time::Span = 100.milliseconds,
                            very_slow_threshold : Time::Span = 1.second) : Symbol
      case duration
      when .>=(very_slow_threshold)
        :very_slow
      when .>=(slow_threshold)
        :slow
      else
        :fast
      end
    end
  end

  # SQL normalization and formatting
  module SQLUtils
    # One pass over the original four rewrites (placeholders, bare numbers, quoted literals,
    # whitespace runs). Each alternative starts with a distinct character class, so leftmost
    # matching reproduces the sequential output exactly. `\$\d+` must stay before `\b\d+\b`
    # so the digits of a `$1` placeholder are not matched as a bare number. A literal `?` is
    # already its own replacement and needs no alternative.
    NORMALIZABLE_TOKEN = /\$\d+|\b\d+\b|'.+?'|\s+/

    NORMALIZED_CACHE_LIMIT = 512

    @@normalized = {} of String => String
    @@normalized_lock = CQL::Compat::Mutex.new

    # Queries repeat the same SQL text (values are bound), so each text is normalized once; at
    # most `NORMALIZED_CACHE_LIMIT` are kept, the oldest inserted dropped first.
    def self.normalize_sql(sql : String) : String
      if cached = @@normalized_lock.synchronize { @@normalized[sql]? }
        return cached
      end
      normalized = sql.gsub(NORMALIZABLE_TOKEN) { |token| normalized_token(token) }.strip
      @@normalized_lock.synchronize do
        @@normalized[sql]? || begin
          @@normalized.shift if @@normalized.size >= NORMALIZED_CACHE_LIMIT
          @@normalized[sql] = normalized
        end
      end
    end

    def self.normalized_cache_size : Int32
      @@normalized_lock.synchronize { @@normalized.size }
    end

    private def self.normalized_token(token : String) : String
      case token[0]
      when '\''         then "'?'"
      when .whitespace? then " "
      else                   "?"
      end
    end

    def self.truncate_sql(sql : String, max_length : Int32 = 100) : String
      if sql.size > max_length
        "#{sql[0...max_length]}..."
      else
        sql
      end
    end

    def self.format_params(params : Array(DB::Any), max_length : Int32 = 50) : String
      return "[]" if params.empty?

      formatted = params.map do |param|
        str = param.to_s
        str.size > max_length ? "#{str[0...max_length]}..." : str
      end

      "[#{formatted.join(", ")}]"
    end
  end

  # Fixed-size log-linear histogram of durations: whole microseconds below `SUB_BUCKETS` get a
  # bucket each, every power of two above splits into `SUB_BUCKETS`, sub-microsecond samples
  # land in bucket 0 and samples of `RANGE` or more in `OVERFLOW_INDEX`.
  struct LatencyHistogram
    private SUB_BUCKET_BITS         = 2
    private SUB_BUCKETS             = 1 << SUB_BUCKET_BITS
    private RANGE_BITS              = 26
    private RANGE                   = (1_i64 << RANGE_BITS).microseconds
    private OVERFLOW_INDEX          = (RANGE_BITS - SUB_BUCKET_BITS + 1) * SUB_BUCKETS
    private BUCKET_COUNT            = OVERFLOW_INDEX + 1
    private MICROSECONDS_PER_SECOND = 1_000_000_i64

    @counts = StaticArray(Int64, BUCKET_COUNT).new(0_i64)

    # Counts *duration* in its bucket in O(1), without allocating.
    def record(duration : Time::Span) : Nil
      @counts[bucket_index(duration)] += 1
    end

    # Upper bound of the bucket holding rank `ceil(q * count)`, clamped to *min*..*max*.
    def percentile(q : Float64, count : Int64, min : Time::Span, max : Time::Span) : Time::Span
      raise ArgumentError.new("quantile must be in 0.0..1.0, got #{q}") unless (0.0..1.0).includes?(q)
      return Time::Span.zero if count == 0
      rank = Math.max(1_i64, (q * count).ceil.to_i64)
      seen = 0_i64
      @counts.each_with_index do |bucket_count, index|
        seen += bucket_count
        return upper_bound(index).clamp(min, max) if seen >= rank
      end
      max
    end

    # Clears every bucket.
    def reset : Nil
      @counts.fill(0_i64)
    end

    private def bucket_index(duration : Time::Span) : Int32
      span = duration.clamp(Time::Span.zero, RANGE)
      micros = span.to_i * MICROSECONDS_PER_SECOND + span.microseconds
      octave = 63 - micros.leading_zeros_count
      shift = Math.max(octave - SUB_BUCKET_BITS, 0)
      ((shift << SUB_BUCKET_BITS) + (micros >> shift)).to_i
    end

    private def upper_bound(index : Int32) : Time::Span
      return Time::Span::MAX if index == OVERFLOW_INDEX
      shift = Math.max((index >> SUB_BUCKET_BITS) - 1, 0)
      top = index - (shift << SUB_BUCKET_BITS)
      ((top + 1).to_i64 << shift).microseconds
    end
  end

  # Statistics tracking
  class StatsTracker
    property total_count : Int64 = 0
    property total_time : Time::Span = Time::Span.zero
    property min_time : Time::Span = Time::Span::MAX
    property max_time : Time::Span = Time::Span.zero
    property errors : Int64 = 0

    @mutex : CQL::Compat::Mutex = CQL::Compat::Mutex.new
    @histogram : LatencyHistogram = LatencyHistogram.new

    def record(duration : Time::Span, error : Bool = false)
      @mutex.synchronize do
        @total_count += 1
        @total_time += duration
        @min_time = Math.min(@min_time, duration)
        @max_time = Math.max(@max_time, duration)
        @errors += 1 if error
        @histogram.record(duration)
      end
    end

    # Estimated *q* quantile of the recorded durations; zero when none are recorded. Raises ArgumentError outside 0.0..1.0.
    def percentile(q : Float64) : Time::Span
      @mutex.synchronize { unsafe_percentile(q) }
    end

    def avg_time : Time::Span
      @mutex.synchronize { unsafe_avg_time }
    end

    def error_rate : Float64
      @mutex.synchronize { unsafe_error_rate }
    end

    def reset
      @mutex.synchronize do
        @total_count = 0
        @total_time = Time::Span.zero
        @min_time = Time::Span::MAX
        @max_time = Time::Span.zero
        @errors = 0
        @histogram.reset
      end
    end

    def to_h : Hash(String, String | Int64 | Float64)
      @mutex.synchronize do
        {
          "total_count"   => @total_count,
          "total_time_ms" => @total_time.total_milliseconds,
          "avg_time_ms"   => unsafe_avg_time.total_milliseconds,
          "min_time_ms"   => @min_time == Time::Span::MAX ? 0.0 : @min_time.total_milliseconds,
          "max_time_ms"   => @max_time.total_milliseconds,
          "error_count"   => @errors,
          "error_rate"    => unsafe_error_rate,
          "p50_time_ms"   => unsafe_percentile(0.5).total_milliseconds,
          "p95_time_ms"   => unsafe_percentile(0.95).total_milliseconds,
          "p99_time_ms"   => unsafe_percentile(0.99).total_milliseconds,
        } of String => String | Int64 | Float64
      end
    end

    private def unsafe_percentile(q : Float64) : Time::Span
      @histogram.percentile(q, @total_count, @min_time, @max_time)
    end

    private def unsafe_avg_time : Time::Span
      return Time::Span.zero if @total_count == 0
      @total_time / @total_count
    end

    private def unsafe_error_rate : Float64
      return 0.0 if @total_count == 0
      (@errors.to_f64 / @total_count) * 100
    end
  end

  # Base performance component with common functionality
  abstract class BasePerformanceComponent
    include TimingUtils

    Log = ::Log.for(self)

    getter stats : StatsTracker = StatsTracker.new
    property? enabled : Bool = true

    def reset
      @stats.reset
    end

    def healthy? : Bool
      @stats.error_rate < 5.0
    end
  end

  # Cache implementation for query results
  class Cache(K, V)
    @cache : Hash(K, V) = {} of K => V
    @max_size : Int32
    @access_order : Array(K) = [] of K
    @mutex : CQL::Compat::Mutex = CQL::Compat::Mutex.new

    def initialize(@max_size : Int32 = 1000)
    end

    def get(key : K, &) : V
      @mutex.synchronize do
        if value = @cache[key]?
          # Move to end for LRU
          @access_order.delete(key)
          @access_order << key
          return value
        end
      end

      value = yield

      @mutex.synchronize do
        unsafe_set(key, value)
      end

      value
    end

    def set(key : K, value : V) : Void
      @mutex.synchronize { unsafe_set(key, value) }
    end

    def clear
      @mutex.synchronize do
        @cache.clear
        @access_order.clear
      end
    end

    def size : Int32
      @mutex.synchronize { @cache.size }
    end

    private def unsafe_set(key : K, value : V) : Void
      if @cache.size >= @max_size && !@cache.has_key?(key)
        if oldest = @access_order.shift?
          @cache.delete(oldest)
        end
      end

      @cache[key] = value
      @access_order.delete(key)
      @access_order << key
    end
  end

  # Colorization helper
  module ColorUtils
    def colorize_by_severity(text : String, severity : Symbol) : String
      return text unless Colorize.enabled?

      case severity
      when :critical, :error
        text.colorize(:red).bold.to_s
      when :high, :warning
        text.colorize(:yellow).to_s
      when :medium
        text.colorize(:light_yellow).to_s
      when :low, :info
        text.colorize(:blue).to_s
      else
        text
      end
    end

    def colorize_duration(duration : Time::Span,
                          slow_threshold : Time::Span = 100.milliseconds,
                          very_slow_threshold : Time::Span = 1.second) : String
      text = format_duration(duration)
      return text unless Colorize.enabled?

      case categorize_duration(duration, slow_threshold, very_slow_threshold)
      when :very_slow
        text.colorize(:red).bold.to_s
      when :slow
        text.colorize(:yellow).to_s
      else
        text.colorize(:green).to_s
      end
    end
  end
end
