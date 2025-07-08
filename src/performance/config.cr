# Performance configuration with nested structure
# Provides intuitive API with sensible defaults

require "json"

module CQL::Performance
  # Nested configuration groups for better organization
  class Config
    # Monitoring configuration
    class Monitoring
      property? enabled : Bool = true
      property? plan_analysis : Bool = true
      property? n_plus_one_detection : Bool = true
      property? query_profiling : Bool = true
      property? auto_analyze_slow : Bool = true
      property context_tracking : Bool = false

      def initialize
        # Auto-enable in development
        if ENV["CRYSTAL_ENV"]? == "development"
          @enabled = true
          @auto_analyze_slow = true
          @context_tracking = true
        end
      end
    end

    # Query profiling configuration
    class Profiling
      property? enabled : Bool = true
      property slow_query_threshold : Time::Span = 100.milliseconds
      property very_slow_threshold : Time::Span = 1.second
      property max_recorded_queries : Int32 = 10_000
      property? log_slow_queries : Bool = true
      property? log_all_queries : Bool = false

      def initialize
        # Lower thresholds in test environment
        if ENV["CRYSTAL_ENV"]? == "test"
          @slow_query_threshold = 10.milliseconds
          @max_recorded_queries = 100
        end
      end
    end

    # N+1 detection configuration
    class Detection
      property? enabled : Bool = true
      property threshold : Int32 = 2
      property? strict_mode : Bool = false
      property ignore_patterns : Array(String) = ["COMMIT", "BEGIN", "ROLLBACK"]
    end

    # SQL logging configuration
    class Logging
      property? enabled : Bool = false
      property? colorize : Bool = true
      property? pretty_format : Bool = true
      property? include_params : Bool = true
      property? include_time : Bool = true
      property? include_rows : Bool = true
      property max_sql_length : Int32 = 500
      property max_param_length : Int32 = 50

      def initialize
        # Auto-enable in development
        if ENV["CRYSTAL_ENV"]? == "development"
          @enabled = true
        end
      end
    end

    # Reporting configuration
    class Reporting
      property format : String = "text"
      property? auto_generate : Bool = false
      property interval : Time::Span = 5.minutes
      property? include_stack_traces : Bool = false
    end

    # Cache configuration
    class Cache
      property? enabled : Bool = true
      property max_size : Int32 = 1000
      property ttl : Time::Span = 5.minutes
    end

    # Main configuration properties
    property monitoring = Monitoring.new
    property profiling = Profiling.new
    property detection = Detection.new
    property logging = Logging.new
    property reporting = Reporting.new
    property cache = Cache.new

    def initialize(&block : self -> _)
      block.call(self)
    end

    def initialize
      # Default initialization without block
    end

    # Convenience methods
    def enabled? : Bool
      monitoring.enabled?
    end

    def development_mode? : Bool
      ENV["CRYSTAL_ENV"]? == "development" || ENV["CQL_ENV"]? == "development"
    end

    def test_mode? : Bool
      ENV["CRYSTAL_ENV"]? == "test" || ENV["CQL_ENV"]? == "test"
    end

    def production_mode? : Bool
      ENV["CRYSTAL_ENV"]? == "production" || ENV["CQL_ENV"]? == "production"
    end

    # Configure with a DSL
    def configure(&)
      yield self
    end

    # Apply environment-specific defaults
    def apply_environment_defaults
      case
      when development_mode?
        # Development optimizations
        monitoring.enabled = true
        logging.enabled = true
        reporting.auto_generate = false
        detection.strict_mode = false
      when test_mode?
        # Test optimizations
        monitoring.enabled = false
        logging.enabled = false
        reporting.auto_generate = false
        profiling.slow_query_threshold = 10.milliseconds
      when production_mode?
        # Production optimizations
        monitoring.enabled = true
        logging.enabled = false
        logging.colorize = false
        reporting.include_stack_traces = false
        cache.enabled = true
      end
    end

    # Load from environment variables
    def self.from_env : self
      config = new

      # Override with environment variables if present
      if val = ENV["CQL_MONITORING_ENABLED"]?
        config.monitoring.enabled = val.downcase == "true"
      end

      if val = ENV["CQL_SQL_LOGGING"]?
        config.logging.enabled = val.downcase == "true"
      end

      if val = ENV["CQL_SLOW_QUERY_MS"]?
        config.profiling.slow_query_threshold = val.to_i.milliseconds
      end

      config.apply_environment_defaults
      config
    end

    # Export to hash for serialization
    def to_h
      {
        "monitoring" => {
          "enabled"              => monitoring.enabled?,
          "plan_analysis"        => monitoring.plan_analysis?,
          "n_plus_one_detection" => monitoring.n_plus_one_detection?,
          "query_profiling"      => monitoring.query_profiling?,
        },
        "profiling" => {
          "enabled"                 => profiling.enabled?,
          "slow_query_threshold_ms" => profiling.slow_query_threshold.total_milliseconds,
          "max_recorded_queries"    => profiling.max_recorded_queries,
        },
        "detection" => {
          "enabled"     => detection.enabled?,
          "threshold"   => detection.threshold,
          "strict_mode" => detection.strict_mode?,
        },
        "logging" => {
          "enabled"       => logging.enabled?,
          "colorize"      => logging.colorize?,
          "pretty_format" => logging.pretty_format?,
        },
        "reporting" => {
          "format"           => reporting.format,
          "auto_generate"    => reporting.auto_generate?,
          "interval_seconds" => reporting.interval.total_seconds,
        },
      }
    end
  end

  # Quick configuration presets
  module ConfigPresets
    def self.development : Config
      Config.new do |config|
        config.monitoring.enabled = true
        config.monitoring.auto_analyze_slow = true
        config.profiling.enabled = true
        config.profiling.log_slow_queries = true
        config.detection.enabled = true
        config.logging.enabled = true
        config.logging.colorize = true
        config.logging.pretty_format = true
        config.reporting.format = "logger"
      end
    end

    def self.test : Config
      Config.new do |config|
        config.monitoring.enabled = false
        config.profiling.enabled = false
        config.detection.enabled = false
        config.logging.enabled = false
        config.cache.enabled = false
      end
    end

    def self.production : Config
      Config.new do |config|
        config.monitoring.enabled = true
        config.monitoring.context_tracking = true
        config.profiling.enabled = true
        config.profiling.log_all_queries = false
        config.detection.enabled = true
        config.detection.strict_mode = true
        config.logging.enabled = false
        config.cache.enabled = true
        config.reporting.auto_generate = true
        config.reporting.interval = 10.minutes
      end
    end

    def self.minimal : Config
      Config.new do |config|
        config.monitoring.enabled = false
        config.profiling.enabled = false
        config.detection.enabled = false
        config.logging.enabled = false
        config.cache.enabled = false
      end
    end
  end
end
