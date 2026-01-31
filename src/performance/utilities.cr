# Shared utilities for performance monitoring
# Consolidates common functionality to reduce code duplication

require "log"
require "colorize"

module CQL::Performance
  # Timing utilities
  module TimingUtils
    def measure_execution(&)
      start_time = Time.monotonic
      result = yield
      execution_time = Time.monotonic - start_time
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
    def self.normalize_sql(sql : String) : String
      sql.gsub(/\$\d+|\?/, "?")
        .gsub(/\b\d+\b/, "?")
        .gsub(/'.+?'/, "'?'")
        .gsub(/\s+/, " ")
        .strip
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

  # Statistics tracking
  class StatsTracker
    property total_count : Int64 = 0
    property total_time : Time::Span = Time::Span.zero
    property min_time : Time::Span = Time::Span::MAX
    property max_time : Time::Span = Time::Span.zero
    property errors : Int64 = 0

    @mutex : Mutex = Mutex.new

    def record(duration : Time::Span, error : Bool = false)
      @mutex.synchronize do
        @total_count += 1
        @total_time += duration
        @min_time = [@min_time, duration].min
        @max_time = [@max_time, duration].max
        @errors += 1 if error
      end
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
        } of String => String | Int64 | Float64
      end
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
    @mutex : Mutex = Mutex.new

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
