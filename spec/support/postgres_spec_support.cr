require "spec"
require "pg"
require "../../src/postgres"

# Specs that need a real PostgreSQL server (`CQL_POSTGRES_TEST_URL`, default
# postgres://localhost/cql_postgres_test). Without one they are reported as pending.
module PostgresSpec
  @@available : Bool? = nil

  def self.url : String
    ENV["CQL_POSTGRES_TEST_URL"]? || "postgres://localhost/cql_postgres_test"
  end

  def self.available? : Bool
    @@available ||= begin
      DB.open(url) { |db| db.scalar("SELECT 1") }
      true
    rescue
      false
    end
  end

  # Call at the top of an example: marks it pending when Postgres is unreachable.
  macro require!
    pending!("PostgreSQL not reachable at #{PostgresSpec.url}") unless PostgresSpec.available?
  end
end

# Runs the block with `CQL::Postgres.config.env` switched, restoring it afterwards.
def with_postgres_env(env : CQL::Postgres::Environment, &)
  original = CQL::Postgres.config.env
  CQL::Postgres.config.env = env
  begin
    yield
  ensure
    CQL::Postgres.config.env = original
  end
end
