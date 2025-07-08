# CQL Performance Monitoring Module (Optimized)
# API with direct method calls and optional components

require "./performance/utilities"
require "./performance/config"
require "./performance/sql_formatter"
require "./performance/query_profiler"
require "./performance/n_plus_one_detector"
require "./performance/unified_report_generator"
require "./performance/monitor"

# Example usage:
# ```
# # Quick setup
# CQL::Performance.enable_development_mode!
#
# # Or custom configuration
# CQL::Performance.configure do |config|
#   config.monitoring.enabled = true
#   config.profiling.slow_query_threshold = 50.milliseconds
#   config.detection.threshold = 3
#   config.logging.colorize = true
# end
#
# # CQL Query integration - queries are automatically tracked
# schema = CQL::Schema.define do
#   table :users do
#     primary :id, Int64
#     column :name, String
#     column :email, String
#   end
# end
#
# # All query executions are monitored
# users = schema.query.from(:users).where(active: true).all(User)
#
# # Track with context for better insights
# CQL::Performance.with_context("UserController#index") do
#   @users = schema.query.from(:users)
#     .where(active: true)
#     .order(created_at: :desc)
#     .limit(20)
#     .all(User)
# end
#
# # Manual tracking for non-CQL queries
# result = CQL::Performance.track("SELECT * FROM users WHERE id = ?", [1]) do
#   db.query_one("SELECT * FROM users WHERE id = ?", 1, as: User)
# end
#
# # Generate performance report
# puts CQL::Performance.report("console")
# ```
module CQL::Performance
  # Make concrete implementations available as shortcuts
  def self.create_profiler(config : Config::Profiling = Config::Profiling.new)
    QueryProfiler.new(config)
  end

  def self.create_detector(config : Config::Detection = Config::Detection.new)
    NPlusOneDetector.new(config)
  end

  # Export config presets for easy use
  def self.development_config : Config
    ConfigPresets.development
  end

  def self.test_config : Config
    ConfigPresets.test
  end

  def self.production_config : Config
    ConfigPresets.production
  end

  def self.minimal_config : Config
    ConfigPresets.minimal
  end

  # Quick setup methods
  def self.enable_development_mode!
    self.monitor = Monitor.new(development_config)
  end

  def self.enable_production_mode!
    self.monitor = Monitor.new(production_config)
  end

  def self.disable!
    self.monitor = Monitor.new(minimal_config)
  end

  # SQL logging convenience
  def self.enable_sql_logging(colorize : Bool = true, pretty : Bool = true)
    configure do |config|
      config.logging.enabled = true
      config.logging.colorize = colorize
      config.logging.pretty_format = pretty
    end
  end

  def self.disable_sql_logging
    configure do |config|
      config.logging.enabled = false
    end
  end

  # Integration helpers for CQL
  module QueryMethods
    # Wrap query execution with monitoring
    macro monitor_query(sql, params = [] of DB::Any)
      CQL::Performance.track({{sql}}, {{params}}) do
        # Original query execution
        yield
      end
    end
  end

  # Integration with CQL Active Record for N+1 detection
  module ActiveRecordIntegration
    # Hook for relation loading tracking
    macro track_relation_loading(relation_name, model_class)
      CQL::Performance.start_relation_loading({{relation_name.stringify}}, {{model_class.stringify}})
      begin
        yield
      ensure
        CQL::Performance.end_relation_loading
      end
    end
  end
end
