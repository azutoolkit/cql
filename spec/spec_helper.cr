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

def postgres_available?
  CQLSpecSupport.postgres_available?
end

def require_postgres!
  pending! "PostgreSQL integration specs require a reachable DATABASE_URL" unless postgres_available?
end

require "./support/**"
