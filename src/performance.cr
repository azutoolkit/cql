# CQL Performance Tools
# Main entry point for all performance monitoring features

require "./performance/query_plan_analyzer"
require "./performance/n_plus_one_detector"
require "./performance/query_profiler"
require "./performance/performance_monitor"
require "./performance/sql_log_formatter"

module CQL
  # Performance monitoring utilities
  module Performance
    # Quick setup for performance monitoring
    #
    # **Example** Basic setup
    # ```
    # CQL::Performance.setup(MySchema) do |config|
    #   config.query_profiling = true
    #   config.n_plus_one_detection = true
    #   config.plan_analysis = true
    # end
    # ```
    def self.setup(schema : Schema, & : PerformanceConfig ->)
      config = PerformanceConfig.new
      yield config

      monitor = PerformanceMonitor.new
      monitor.initialize_with_schema(schema, config)
      self.monitor = monitor

      # Initialize SQL logging in development
      setup_sql_logging if config.query_profiling_enabled?

      Log.info { "CQL Performance monitoring enabled with features: #{enabled_features(config).join(", ")}" }
    end

    # Quick setup with default configuration
    def self.setup(schema : Schema)
      monitor = PerformanceMonitor.new
      monitor.initialize_with_schema(schema)
      self.monitor = monitor

      # Enable async processing in development for auto-reporting
      env = ENV["CRYSTAL_ENV"]? || ENV["CQL_ENV"]? || "development"
      if env.downcase == "development"
        monitor.configure do |config|
          config.async_processing = true
        end
      end

      # Initialize SQL logging in development by default
      setup_sql_logging

      Log.info { "CQL Performance monitoring enabled with default configuration" }
    end

    private def self.enabled_features(config : PerformanceConfig) : Array(String)
      features = [] of String
      features << "Query Plan Analysis" if config.plan_analysis_enabled?
      features << "N+1 Detection" if config.n_plus_one_detection_enabled?
      features << "Query Profiling" if config.query_profiling_enabled?
      features
    end

    private def self.setup_sql_logging
      # Initialize SQL logging for development environment
      env = ENV["CRYSTAL_ENV"]? || ENV["CQL_ENV"]? || "development"
      if env.downcase == "development"
        CQL.enable_sql_logging do |config|
          config.enabled = true
          config.colorize_output = true
          config.async_processing = false  # Use sync processing for immediate SQL output
        end

        # Subscribe SQL logger to performance monitor events
        if m = monitor
          m.subscribe(CQL.sql_logger)
        end

        Log.info { "SQL logging enabled for development environment (immediate output)" }
      end
    end
  end
end
