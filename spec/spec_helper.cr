require "spec"
require "sqlite3"
require "../src/cql"

module CQLSpecSupport
  @@postgres_available : Bool?

  def self.postgres_database_url
    ENV["DATABASE_URL"]? || "postgres://localhost/cql_test"
  end

  def self.sqlite_db_dir
    dir = ENV["CQL_SPEC_DB_DIR"]? || File.join(Dir.tempdir, "cql_spec_dbs")
    Dir.mkdir_p(dir)
    dir
  end

  def self.sqlite_uri(name : String)
    "sqlite3://#{File.join(sqlite_db_dir, name)}"
  end

  def self.postgres_available?
    cached = @@postgres_available
    return cached unless cached.nil?

    @@postgres_available = begin
      DB.open(postgres_database_url) do |database|
        database.scalar("SELECT 1")
        true
      end
    rescue
      false
    end
  end
end

def postgres_database_url
  CQLSpecSupport.postgres_database_url
end

def spec_sqlite_uri(name : String)
  CQLSpecSupport.sqlite_uri(name)
end

# A schema on its own SQLite file; *params* is appended to the URI (e.g. pool settings).
def spec_sqlite_schema(name : String, params : String = "") : CQL::Schema
  CQL::Schema.new(:spec_sqlite, spec_sqlite_uri(name) + params, CQL::Adapter::SQLite)
end

def postgres_available?
  CQLSpecSupport.postgres_available?
end

def require_postgres!
  pending! "PostgreSQL integration specs require a reachable DATABASE_URL" unless postgres_available?
end

# Installs the monitor as the global one for the block, then restores the previous one.
def with_global_monitor(monitor : CQL::Performance::Monitor, &)
  previous = CQL::Performance.monitor
  CQL::Performance.monitor = monitor
  yield
ensure
  CQL::Performance.monitor = previous if previous
end

# Returns the statements of *operation* (SELECT by default) the block ran, in order, so specs can assert query counts.
def count_queries(operation : Symbol = :select, & : ->) : Array(String)
  statements = [] of String
  subscription = "spec_count_queries_#{Random::Secure.hex(4)}"
  CQL::Telemetry.subscribe(subscription) do |event|
    statements << event.sql if event.operation == operation
  end
  begin
    yield
  ensure
    CQL::Telemetry.unsubscribe(subscription)
  end
  statements
end

require "./support/**"
