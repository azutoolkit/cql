# CQL Performance Tools
# Main entry point for all performance monitoring features

require "./performance/query_plan_analyzer"
require "./performance/n_plus_one_detector"
require "./performance/query_profiler"
require "./performance/performance_monitor"

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
    def self.setup(schema : Schema, &block : PerformanceConfig ->)
      config = PerformanceConfig.new
      yield config

      monitor = PerformanceMonitor.new
      monitor.initialize_with_schema(schema, config)
      self.monitor = monitor

      Log.info { "CQL Performance monitoring enabled with features: #{enabled_features(config).join(", ")}" }
    end

    # Quick setup with default configuration
    def self.setup(schema : Schema)
      monitor = PerformanceMonitor.new
      monitor.initialize_with_schema(schema)
      self.monitor = monitor

      Log.info { "CQL Performance monitoring enabled with default configuration" }
    end

    private def self.enabled_features(config : PerformanceConfig) : Array(String)
      features = [] of String
      features << "Query Plan Analysis" if config.plan_analysis_enabled
      features << "N+1 Detection" if config.n_plus_one_detection_enabled
      features << "Query Profiling" if config.query_profiling_enabled
      features
    end
  end
end
