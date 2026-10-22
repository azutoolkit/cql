require "../../support/postgres_spec_support"

private def with_log(threshold : Float64, &)
  backend = Log::MemoryBackend.new
  config = ::CQL::Postgres.config
  original_log, original_ms = config.log, config.slow_query_ms
  config.log = Log.new("cql.postgres.spec", backend, :debug)
  config.slow_query_ms = threshold
  ::CQL::Postgres::Database::SlowQuery.install
  begin
    yield backend
  ensure
    ::CQL::Postgres::Database::SlowQuery.uninstall
    config.log = original_log
    config.slow_query_ms = original_ms
  end
end

private def query_event(ms : Float64)
  ::CQL::Events::QueryEvent.new("SELECT pg_sleep(1)", [] of DB::Any, ms)
end

describe ::CQL::Postgres::Database::SlowQuery do
  it "warns through the configured logger for queries over the threshold" do
    with_log(50.0) do |backend|
      ::CQL::Events.emit(::CQL::Events::QUERY, query_event(75.0))
      backend.entries.size.should eq 1
      backend.entries.first.severity.should eq Log::Severity::Warn
      backend.entries.first.message.should contain "Slow query (75.0ms): SELECT pg_sleep(1)"
    end
  end

  it "ignores fast queries" do
    with_log(50.0) do |backend|
      ::CQL::Events.emit(::CQL::Events::QUERY, query_event(10.0))
      backend.entries.should be_empty
    end
  end

  it "is disabled with a threshold of 0" do
    with_log(0.0) do |backend|
      ::CQL::Events.emit(::CQL::Events::QUERY, query_event(10_000.0))
      backend.entries.should be_empty
    end
  end

  it "installs a single subscriber" do
    ::CQL::Postgres::Database::SlowQuery.install
    ::CQL::Postgres::Database::SlowQuery.install
    ::CQL::Postgres::Database::SlowQuery.installed?.should be_true
    ::CQL::Postgres::Database::SlowQuery.uninstall
    ::CQL::Postgres::Database::SlowQuery.installed?.should be_false
  end
end

describe ::CQL::Postgres::Configuration do
  it "defaults to a quiet, environment-aware setup" do
    config = ::CQL::Postgres::Configuration.new
    config.url.should be_nil
    config.n_plus_one.should eq ::CQL::Postgres::Configuration::NPlusOne::Off
    config.slow_query_ms.should eq 0.0
  end

  it "yields the shared configuration from .configure" do
    original = ::CQL::Postgres.config.pool_size
    ::CQL::Postgres.configure { |c| c.pool_size = 7 }
    ::CQL::Postgres.config.pool_size.should eq 7
    ::CQL::Postgres.config.pool_size = original
  end
end
