require "../spec_helper"
require "log/spec"
require "../../src/postgres"

private def with_crystal_env(env : String, &)
  previous = ENV["CRYSTAL_ENV"]?
  ENV["CRYSTAL_ENV"] = env
  CQL.reset_config!
  yield
ensure
  previous ? (ENV["CRYSTAL_ENV"] = previous) : ENV.delete("CRYSTAL_ENV")
  CQL.reset_config!
end

private def without_crystal_env(&)
  previous = ENV["CRYSTAL_ENV"]?
  ENV.delete("CRYSTAL_ENV")
  CQL.reset_config!
  yield
ensure
  ENV["CRYSTAL_ENV"] = previous if previous
  CQL.reset_config!
end

describe "CQL.configure" do
  after_each do
    CQL.reset_config!
    CQL::Performance.disable_sql_logging
  end

  describe "environment defaults" do
    it "sizes the pool per environment" do
      {"development" => 5, "test" => 1, "production" => 25}.each do |env, size|
        with_crystal_env(env) { CQL.config.pool.size.should eq(size) }
      end
    end

    it "logs SQL in development unless told otherwise" do
      with_crystal_env("development") do
        CQL.config.sql_logging?.should be_true
        CQL.configure(&.sql_logging=(false))
        CQL.config.sql_logging?.should be_false
      end
    end

    it "does not log SQL when CRYSTAL_ENV is unset" do
      without_crystal_env do
        CQL.config.env.should eq("development")
        CQL.config.sql_logging?.should be_false
      end
    end

    it "logs SQL when development is declared in the configure block" do
      without_crystal_env do
        CQL.configure(&.env=("development"))
        CQL.config.sql_logging?.should be_true
      end
    end

    it "logs SQL when asked to even with CRYSTAL_ENV unset" do
      without_crystal_env do
        CQL.configure(&.sql_logging=(true))
        CQL.config.sql_logging?.should be_true
      end
    end

    it "honors CQL_NO_SQL_LOG when development is declared in the configure block" do
      ENV["CQL_NO_SQL_LOG"] = "1"
      without_crystal_env do
        CQL.configure(&.env=("development"))
        CQL.config.sql_logging?.should be_false
      end
    ensure
      ENV.delete("CQL_NO_SQL_LOG")
    end

    it "follows the environment when it is changed after the defaults were applied" do
      with_crystal_env("development") do
        CQL.configure(&.env=("production"))
        CQL.config.sql_logging?.should be_false
      end
    end

    it "honors CQL_NO_SQL_LOG in development" do
      ENV["CQL_NO_SQL_LOG"] = "1"
      with_crystal_env("development") { CQL.config.sql_logging?.should be_false }
    ensure
      ENV.delete("CQL_NO_SQL_LOG")
    end

    it "defaults the test environment to an in-memory SQLite URL that parses and opens" do
      with_crystal_env("test") do
        CQL.config.db.should eq("sqlite3::memory:")
        url = CQL.config.full_db_url
        URI.parse(url).scheme.should eq("sqlite3")
        DB.open(url, &.scalar("SELECT 1").should(eq(1)))
        File.exists?("[:memory:]").should be_false
      end
    end

    it "does not log SQL in production by default" do
      with_crystal_env("production") { CQL.config.sql_logging?.should be_false }
    end
  end

  describe "validation" do
    it "rejects a non-positive pool size" do
      expect_raises(ArgumentError, /pool_size/) { CQL.configure(&.pool_size=(0)) }
    end

    it "rejects an unsupported database scheme" do
      expect_raises(ArgumentError, /Unsupported database URL/) { CQL.configure(&.db=("oracle://x")) }
    end
  end

  describe "pool_size" do
    it "keeps pool.size in step" do
      CQL.configure(&.pool_size=(7))
      CQL.config.pool.size.should eq(7)
    end

    it "never leaves the initial or idle pool larger than the maximum" do
      with_crystal_env("development") do
        CQL.configure(&.pool_size=(1))
        CQL.config.pool.initial_size.should eq(1)
        CQL.config.pool.max_idle_size.should eq(1)
      end
    end
  end

  describe "pool.query_timeout" do
    it "is unset by default and reaches the URL as query_timeout only when set" do
      CQL.configure(&.db=("postgres://u@localhost/app"))
      CQL.config.pool.query_timeout.should be_nil
      CQL.config.full_db_url.should_not contain("query_timeout")
      CQL.config.pool.query_timeout = 1.5.seconds
      CQL.config.full_db_url.should contain("query_timeout=1.5")
      CQL.config.db = "cockroachdb://u@localhost/app"
      CQL.config.full_db_url.should contain("query_timeout=1.5")
      expect_raises(ArgumentError, /query_timeout needs PostgreSQL/) { CQL.configure(&.db=("sqlite3://./app.db")) }
      expect_raises(ArgumentError, "query_timeout must be positive") { CQL.configure(&.pool.query_timeout=(-1.seconds)) }
    end

    it "logs a warning when another driver (the pg shard, linked in the specs) takes postgres://, as it ignores the key" do
      with_crystal_env("development") do
        CQL.config.pool.query_timeout = 1.second
        Log.capture("*", level: :warn) do |logs|
          CQL.configure(&.db=("postgres://u@localhost/app"))
          logs.check(:warn, %r{pool\.query_timeout is ignored by schemas opened through crystal-db\b.*PG::Driver handles postgres://})
        end
      end
    end
  end

  describe "fragment_cache" do
    it "builds a FragmentCache with each invalidation strategy" do
      {"timestamp" => "TimestampInvalidation", "version" => "VersionInvalidation", "transaction_aware" => "TransactionAwareInvalidation"}.each do |strategy, name|
        CQL.configure(&.cache.invalidation=(strategy))
        CQL.fragment_cache.stats["invalidation_strategy"].should eq(name)
      end
    end
  end

  describe "full_db_url" do
    it "opens through the native PostgreSQL driver without unknown startup parameters" do
      {"postgres://u@localhost/app", "cockroachdb://root@localhost:26257/defaultdb"}.each do |url|
        CQL.configure(&.db=(url))

        driver_config = CQL::Postgres::Config.from_uri(
          URI.parse(CQL.config.full_db_url),
          ignoring: CQL::Postgres::Driver::DB_OWNED_KEYS)
        driver_config.startup_options.should be_empty
      end
    end

    it "carries pool and SQLite settings" do
      CQL.configure do |config|
        config.db = "sqlite3://./x.db"
        config.pool_size = 3
        config.sqlite.busy_timeout = 1234
      end

      url = CQL.config.full_db_url
      url.should contain("max_pool_size=3")
      url.should contain("busy_timeout=1234")
    end

    it "lets params already in the URL win" do
      CQL.configure { |config| config.db = "sqlite3://./x.db?max_pool_size=9" }
      CQL.config.full_db_url.should contain("max_pool_size=9")
      CQL.config.full_db_url.should_not contain("max_pool_size=10")
    end
  end

  describe ".verify_schema" do
    it "reports a stale schema file without rewriting it, and rewrites it with auto_fix" do
      schema_dir = File.join(Dir.tempdir, "cql_verify_schema_#{Process.pid}_#{Random::Secure.hex(4)}")
      db_file = File.join(Dir.tempdir, "cql_verify_schema_#{Process.pid}_#{Random::Secure.hex(4)}.db")
      CQL.configure do |config|
        config.db = "sqlite3://#{db_file}"
        config.schema_dir = schema_dir
        config.auto_sync = true
      end
      schema = CQL::Schema.new(:verify_schema_spec, "sqlite3://#{db_file}", CQL::Adapter::SQLite)
      Dir.mkdir_p(schema_dir)
      File.write(CQL.config.schema_path, "# stale\n")

      begin
        CQL.verify_schema(schema).should be_false
        File.read(CQL.config.schema_path).should eq("# stale\n")

        CQL.verify_schema(schema, auto_fix: true).should be_true
        CQL.verify_schema(schema).should be_true
      ensure
        schema.close
        FileUtils.rm_rf(schema_dir)
        File.delete(db_file) if File.exists?(db_file)
      end
    end
  end

  describe ".build_schema" do
    it "defines tables with the schema DSL and applies the configured connection settings" do
      with_crystal_env("test") do
        CQL.configure do |config|
          config.db = CQLSpecSupport.sqlite_uri("configure_build_schema.db")
          config.sqlite.busy_timeout = 4321
        end

        schema = CQL.build_schema(:configured) do
          table :things do
            primary :id, Int64
            text :name
          end
        end

        schema.tables.has_key?(:things).should be_true
        schema.exec_query(&.scalar("PRAGMA busy_timeout")).should eq(4321)
      end
    end

    it "leaves the performance monitor off when CRYSTAL_ENV is unset" do
      disabled = CQL::Performance::Config.new
      disabled.monitoring.enabled = false

      with_global_monitor(CQL::Performance::Monitor.new(config: disabled)) do
        without_crystal_env do
          CQL.configure { |config| config.db = CQLSpecSupport.sqlite_uri("configure_build_schema_unset.db") }

          CQL.build_schema(:configured_unset) { }
          CQL::Performance.monitor.enabled?.should be_false
        end
      end
    end

    it "sets up SQL logging in development without raising" do
      disabled = CQL::Performance::Config.new
      disabled.monitoring.enabled = false

      with_global_monitor(CQL::Performance::Monitor.new(config: disabled)) do
        with_crystal_env("development") do
          CQL.configure { |config| config.db = CQLSpecSupport.sqlite_uri("configure_build_schema_dev.db") }

          CQL.build_schema(:configured_dev) { }.should be_a(CQL::Schema)
          logging_enabled = false
          CQL::Performance.monitor.configure { |performance| logging_enabled = performance.logging.enabled? }
          logging_enabled.should be_true
        end
      end
    end
  end
end
