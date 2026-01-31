require "../spec_helper"
require "../../src/performance/config"

describe CQL::Performance::Config do
  describe "default values" do
    it "creates a config with default sub-configurations" do
      config = CQL::Performance::Config.new
      config.monitoring.should be_a(CQL::Performance::Config::Monitoring)
      config.profiling.should be_a(CQL::Performance::Config::Profiling)
      config.detection.should be_a(CQL::Performance::Config::Detection)
      config.logging.should be_a(CQL::Performance::Config::Logging)
      config.reporting.should be_a(CQL::Performance::Config::Reporting)
      config.cache.should be_a(CQL::Performance::Config::Cache)
    end
  end

  describe "#enabled?" do
    it "delegates to monitoring.enabled?" do
      config = CQL::Performance::Config.new
      config.enabled?.should eq(config.monitoring.enabled?)
    end

    it "reflects changes to monitoring.enabled" do
      config = CQL::Performance::Config.new
      config.monitoring.enabled = false
      config.enabled?.should be_false

      config.monitoring.enabled = true
      config.enabled?.should be_true
    end
  end

  describe "#development_mode?" do
    it "returns false when no environment is set" do
      ENV.delete("CRYSTAL_ENV")
      ENV.delete("CQL_ENV")
      config = CQL::Performance::Config.new
      config.development_mode?.should be_false
    end

    it "returns true when CRYSTAL_ENV is development" do
      ENV["CRYSTAL_ENV"] = "development"
      config = CQL::Performance::Config.new
      config.development_mode?.should be_true
      ENV.delete("CRYSTAL_ENV")
    end

    it "returns true when CQL_ENV is development" do
      ENV.delete("CRYSTAL_ENV")
      ENV["CQL_ENV"] = "development"
      config = CQL::Performance::Config.new
      config.development_mode?.should be_true
      ENV.delete("CQL_ENV")
    end
  end

  describe "#test_mode?" do
    it "returns false when no environment is set" do
      ENV.delete("CRYSTAL_ENV")
      ENV.delete("CQL_ENV")
      config = CQL::Performance::Config.new
      config.test_mode?.should be_false
    end

    it "returns true when CRYSTAL_ENV is test" do
      ENV["CRYSTAL_ENV"] = "test"
      config = CQL::Performance::Config.new
      config.test_mode?.should be_true
      ENV.delete("CRYSTAL_ENV")
    end

    it "returns true when CQL_ENV is test" do
      ENV.delete("CRYSTAL_ENV")
      ENV["CQL_ENV"] = "test"
      config = CQL::Performance::Config.new
      config.test_mode?.should be_true
      ENV.delete("CQL_ENV")
    end
  end

  describe "#production_mode?" do
    it "returns false when no environment is set" do
      ENV.delete("CRYSTAL_ENV")
      ENV.delete("CQL_ENV")
      config = CQL::Performance::Config.new
      config.production_mode?.should be_false
    end

    it "returns true when CRYSTAL_ENV is production" do
      ENV["CRYSTAL_ENV"] = "production"
      config = CQL::Performance::Config.new
      config.production_mode?.should be_true
      ENV.delete("CRYSTAL_ENV")
    end

    it "returns true when CQL_ENV is production" do
      ENV.delete("CRYSTAL_ENV")
      ENV["CQL_ENV"] = "production"
      config = CQL::Performance::Config.new
      config.production_mode?.should be_true
      ENV.delete("CQL_ENV")
    end
  end

  describe "#configure" do
    it "yields self for DSL-style configuration" do
      config = CQL::Performance::Config.new
      config.configure do |c|
        c.monitoring.enabled = false
        c.profiling.slow_query_threshold = 200.milliseconds
        c.detection.threshold = 5
      end

      config.monitoring.enabled?.should be_false
      config.profiling.slow_query_threshold.should eq(200.milliseconds)
      config.detection.threshold.should eq(5)
    end
  end

  describe "block initializer" do
    it "accepts a configuration block" do
      config = CQL::Performance::Config.new do |c|
        c.monitoring.enabled = false
        c.logging.enabled = true
      end

      config.monitoring.enabled?.should be_false
      config.logging.enabled?.should be_true
    end
  end

  describe "#to_h" do
    it "returns a hash representation of the configuration" do
      config = CQL::Performance::Config.new
      hash = config.to_h

      hash.keys.size.should be >= 5
      hash.keys.should contain("monitoring")
      hash.keys.should contain("profiling")
      hash.keys.should contain("detection")
      hash.keys.should contain("logging")
      hash.keys.should contain("reporting")
    end

    it "includes monitoring settings" do
      config = CQL::Performance::Config.new
      monitoring = hash_value(config.to_h, "monitoring")
      monitoring["enabled"].should eq(config.monitoring.enabled?)
      monitoring["plan_analysis"].should eq(config.monitoring.plan_analysis?)
      monitoring["n_plus_one_detection"].should eq(config.monitoring.n_plus_one_detection?)
      monitoring["query_profiling"].should eq(config.monitoring.query_profiling?)
    end

    it "includes profiling settings with threshold in milliseconds" do
      config = CQL::Performance::Config.new
      profiling = hash_value(config.to_h, "profiling")
      profiling["enabled"].should eq(config.profiling.enabled?)
      profiling["slow_query_threshold_ms"].should eq(config.profiling.slow_query_threshold.total_milliseconds)
      profiling["max_recorded_queries"].should eq(config.profiling.max_recorded_queries)
    end

    it "includes detection settings" do
      config = CQL::Performance::Config.new
      detection = hash_value(config.to_h, "detection")
      detection["enabled"].should eq(config.detection.enabled?)
      detection["threshold"].should eq(config.detection.threshold)
      detection["strict_mode"].should eq(config.detection.strict_mode?)
    end

    it "includes logging settings" do
      config = CQL::Performance::Config.new
      logging = hash_value(config.to_h, "logging")
      logging["enabled"].should eq(config.logging.enabled?)
      logging["colorize"].should eq(config.logging.colorize?)
      logging["pretty_format"].should eq(config.logging.pretty_format?)
    end

    it "includes reporting settings" do
      config = CQL::Performance::Config.new
      reporting = hash_value(config.to_h, "reporting")
      reporting["format"].should eq(config.reporting.format)
      reporting["auto_generate"].should eq(config.reporting.auto_generate?)
      reporting["interval_seconds"].should eq(config.reporting.interval.total_seconds)
    end
  end

  describe ".from_env" do
    # Save and restore environment around each spec
    it "applies environment defaults before env var overrides" do
      ENV.delete("CRYSTAL_ENV")
      ENV.delete("CQL_ENV")
      ENV.delete("CQL_MONITORING_ENABLED")
      ENV.delete("CQL_SQL_LOGGING")
      ENV.delete("CQL_SLOW_QUERY_MS")

      config = CQL::Performance::Config.from_env
      # Without any env set, defaults should apply
      config.monitoring.enabled?.should be_true
      config.profiling.slow_query_threshold.should eq(100.milliseconds)
    end

    it "overrides environment defaults with explicit env vars" do
      ENV.delete("CRYSTAL_ENV")
      ENV.delete("CQL_ENV")
      ENV["CQL_MONITORING_ENABLED"] = "false"
      ENV["CQL_SQL_LOGGING"] = "true"
      ENV["CQL_SLOW_QUERY_MS"] = "250"

      config = CQL::Performance::Config.from_env

      config.monitoring.enabled?.should be_false
      config.logging.enabled?.should be_true
      config.profiling.slow_query_threshold.should eq(250.milliseconds)

      ENV.delete("CQL_MONITORING_ENABLED")
      ENV.delete("CQL_SQL_LOGGING")
      ENV.delete("CQL_SLOW_QUERY_MS")
    end

    it "applies test environment defaults then allows overrides" do
      ENV["CRYSTAL_ENV"] = "test"
      ENV.delete("CQL_ENV")
      ENV["CQL_MONITORING_ENABLED"] = "true"

      config = CQL::Performance::Config.from_env

      # apply_environment_defaults sets monitoring.enabled = false for test,
      # but CQL_MONITORING_ENABLED=true overrides it
      config.monitoring.enabled?.should be_true
      # Logging stays disabled from test defaults (no override)
      config.logging.enabled?.should be_false
      # Profiling threshold set by apply_environment_defaults for test mode
      config.profiling.slow_query_threshold.should eq(10.milliseconds)

      ENV.delete("CRYSTAL_ENV")
      ENV.delete("CQL_MONITORING_ENABLED")
    end

    it "applies production environment defaults" do
      ENV["CRYSTAL_ENV"] = "production"
      ENV.delete("CQL_ENV")
      ENV.delete("CQL_MONITORING_ENABLED")
      ENV.delete("CQL_SQL_LOGGING")
      ENV.delete("CQL_SLOW_QUERY_MS")

      config = CQL::Performance::Config.from_env

      config.monitoring.enabled?.should be_true
      config.logging.enabled?.should be_false
      config.logging.colorize?.should be_false
      config.reporting.include_stack_traces?.should be_false
      config.cache.enabled?.should be_true

      ENV.delete("CRYSTAL_ENV")
    end
  end
end

describe CQL::Performance::Config::Monitoring do
  it "has correct defaults" do
    ENV.delete("CRYSTAL_ENV")
    monitoring = CQL::Performance::Config::Monitoring.new
    monitoring.enabled?.should be_true
    monitoring.plan_analysis?.should be_true
    monitoring.n_plus_one_detection?.should be_true
    monitoring.query_profiling?.should be_true
    monitoring.auto_analyze_slow?.should be_true
    monitoring.context_tracking.should be_false
  end

  it "auto-enables context_tracking in development" do
    ENV["CRYSTAL_ENV"] = "development"
    monitoring = CQL::Performance::Config::Monitoring.new
    monitoring.enabled?.should be_true
    monitoring.auto_analyze_slow?.should be_true
    monitoring.context_tracking.should be_true
    ENV.delete("CRYSTAL_ENV")
  end
end

describe CQL::Performance::Config::Profiling do
  it "has correct defaults" do
    ENV.delete("CRYSTAL_ENV")
    profiling = CQL::Performance::Config::Profiling.new
    profiling.enabled?.should be_true
    profiling.slow_query_threshold.should eq(100.milliseconds)
    profiling.very_slow_threshold.should eq(1.second)
    profiling.max_recorded_queries.should eq(10_000)
    profiling.log_slow_queries?.should be_true
    profiling.log_all_queries?.should be_false
  end

  it "lowers thresholds in test environment" do
    ENV["CRYSTAL_ENV"] = "test"
    profiling = CQL::Performance::Config::Profiling.new
    profiling.slow_query_threshold.should eq(10.milliseconds)
    profiling.max_recorded_queries.should eq(100)
    ENV.delete("CRYSTAL_ENV")
  end
end

describe CQL::Performance::Config::Detection do
  it "has correct defaults" do
    detection = CQL::Performance::Config::Detection.new
    detection.enabled?.should be_true
    detection.threshold.should eq(2)
    detection.strict_mode?.should be_false
    detection.ignore_patterns.should eq(["COMMIT", "BEGIN", "ROLLBACK"])
    detection.detection_window.should eq(10)
  end

  it "allows setting threshold" do
    detection = CQL::Performance::Config::Detection.new
    detection.threshold = 5
    detection.threshold.should eq(5)
  end

  it "allows setting detection_window" do
    detection = CQL::Performance::Config::Detection.new
    detection.detection_window = 20
    detection.detection_window.should eq(20)
  end

  it "allows modifying ignore_patterns" do
    detection = CQL::Performance::Config::Detection.new
    detection.ignore_patterns << "SAVEPOINT"
    detection.ignore_patterns.should contain("SAVEPOINT")
    detection.ignore_patterns.size.should eq(4)
  end
end

describe CQL::Performance::Config::Logging do
  it "has correct defaults" do
    ENV.delete("CRYSTAL_ENV")
    logging = CQL::Performance::Config::Logging.new
    logging.enabled?.should be_false
    logging.colorize?.should be_true
    logging.pretty_format?.should be_true
    logging.include_params?.should be_true
    logging.include_time?.should be_true
    logging.include_rows?.should be_true
    logging.max_sql_length.should eq(500)
    logging.max_param_length.should eq(50)
  end

  it "auto-enables in development" do
    ENV["CRYSTAL_ENV"] = "development"
    logging = CQL::Performance::Config::Logging.new
    logging.enabled?.should be_true
    ENV.delete("CRYSTAL_ENV")
  end
end

describe CQL::Performance::Config::Reporting do
  it "has correct defaults" do
    reporting = CQL::Performance::Config::Reporting.new
    reporting.format.should eq("text")
    reporting.auto_generate?.should be_false
    reporting.interval.should eq(5.minutes)
    reporting.include_stack_traces?.should be_false
  end

  it "allows setting format" do
    reporting = CQL::Performance::Config::Reporting.new
    reporting.format = "json"
    reporting.format.should eq("json")
  end
end

describe CQL::Performance::Config::Cache do
  it "has correct defaults" do
    cache = CQL::Performance::Config::Cache.new
    cache.enabled?.should be_true
    cache.max_size.should eq(1000)
    cache.ttl.should eq(5.minutes)
  end

  it "allows updating properties" do
    cache = CQL::Performance::Config::Cache.new
    cache.enabled = false
    cache.max_size = 500
    cache.ttl = 10.minutes

    cache.enabled?.should be_false
    cache.max_size.should eq(500)
    cache.ttl.should eq(10.minutes)
  end
end

describe CQL::Performance::ConfigPresets do
  describe ".development" do
    it "returns a development-optimized config" do
      config = CQL::Performance::ConfigPresets.development
      config.monitoring.enabled?.should be_true
      config.monitoring.auto_analyze_slow?.should be_true
      config.profiling.enabled?.should be_true
      config.profiling.log_slow_queries?.should be_true
      config.detection.enabled?.should be_true
      config.logging.enabled?.should be_true
      config.logging.colorize?.should be_true
      config.logging.pretty_format?.should be_true
      config.reporting.format.should eq("logger")
    end
  end

  describe ".test" do
    it "returns a config with everything disabled" do
      config = CQL::Performance::ConfigPresets.test
      config.monitoring.enabled?.should be_false
      config.profiling.enabled?.should be_false
      config.detection.enabled?.should be_false
      config.logging.enabled?.should be_false
      config.cache.enabled?.should be_false
    end
  end

  describe ".production" do
    it "returns a production-optimized config" do
      config = CQL::Performance::ConfigPresets.production
      config.monitoring.enabled?.should be_true
      config.monitoring.context_tracking.should be_true
      config.profiling.enabled?.should be_true
      config.profiling.log_all_queries?.should be_false
      config.detection.enabled?.should be_true
      config.detection.strict_mode?.should be_true
      config.logging.enabled?.should be_false
      config.cache.enabled?.should be_true
      config.reporting.auto_generate?.should be_true
      config.reporting.interval.should eq(10.minutes)
    end
  end

  describe ".minimal" do
    it "returns a config with everything disabled" do
      config = CQL::Performance::ConfigPresets.minimal
      config.monitoring.enabled?.should be_false
      config.profiling.enabled?.should be_false
      config.detection.enabled?.should be_false
      config.logging.enabled?.should be_false
      config.cache.enabled?.should be_false
    end
  end
end

# Helper to extract nested hash values with correct type
private def hash_value(h, key)
  h[key]
end
