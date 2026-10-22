module CQL::Postgres
  # Zero-boilerplate database access.
  #
  # ```
  # require "cql/postgres"
  # CQL::Postgres.configure { |c| c.url = ENV["DATABASE_URL"] } # optional
  # ```
  #
  # The connection pool is opened lazily on first use (or on `Database.boot`) and the
  # schema is populated from the `CQL::Postgres::Model` classes. Slow-query warnings are
  # driven by `CQL::Events`, so any other consumer (dashboards, tracers) can subscribe
  # to the same events without this layer knowing about it.
  module Database
    @@mutex = Mutex.new
    @@schema : ::CQL::Schema? = nil
    @@pending_check : Proc(Int32)? = nil

    def self.config : Configuration
      ::CQL::Postgres.config
    end

    # Connection URL after applying configuration, environment and conventions.
    def self.url : String
      URLResolver.resolve(config, config.env, URLResolver.app_slug(PROGRAM_NAME))
    end

    # True when the app opted into a database (a model exists or a URL is configured).
    def self.configured? : Bool
      Registry.any? || !config.url.nil? || !ENV["DATABASE_URL"]?.nil?
    end

    def self.connected? : Bool
      !@@schema.nil?
    end

    # The shared CQL schema (connects on first call, thread-safe).
    def self.schema : ::CQL::Schema
      @@schema || @@mutex.synchronize { @@schema ||= connect }
    end

    # Replaces the schema (tests, multiple environments). Closes nothing.
    def self.schema=(schema : ::CQL::Schema?)
      @@mutex.synchronize { @@schema = schema }
    end

    # Opens the pool, installs instrumentation and verifies connectivity.
    def self.boot : Nil
      return unless configured?
      schema
      ping!
      config.log.info { "Database connected: #{URLResolver.redact(url)}" }
      warn_pending_migrations
    end

    # True if `SELECT 1` succeeds. Never raises, usable in health endpoints.
    def self.healthy? : Bool
      ping!
      true
    rescue
      false
    end

    def self.ping! : Nil
      schema.raw_readonly("SELECT 1", 1)
    rescue ex : ConnectionError
      raise ex
    rescue ex
      raise ConnectionError.new(connection_help(ex))
    end

    # Pool counters, or nil before the first connection.
    def self.pool : ::CQL::PoolStats?
      return unless connected?
      schema.pool_stats
    end

    @@seeds = [] of Proc(Nil)

    # Registers seed data, run by `Tasks.seed` (and `Tasks.setup` / `Tasks.reset`). Typically in db/seeds.cr:
    #
    # ```
    # ::CQL::Postgres::Database.seed do
    #   User.create!(email: "admin@example.com", name: "Admin")
    # end
    # ```
    def self.seed(&block : ->) : Nil
      @@seeds << block
    end

    def self.run_seeds : Int32
      @@seeds.each(&.call)
      @@seeds.size
    end

    def self.clear_seeds : Nil
      @@seeds.clear
    end

    # Set by `::CQL::Postgres::Migrator`: returns how many migrations are pending.
    def self.pending_check=(check : Proc(Int32)?)
      @@pending_check = check
    end

    private def self.connect : ::CQL::Schema
      resolved = url
      schema = begin
        ::CQL::Schema.new(:postgres, resolved, ::CQL::Adapter::Postgres)
      rescue ex
        raise ConnectionError.new(connection_help(ex))
      end
      Registry.apply_all(schema)
      Registry.listener = ->(table : Symbol) { sync_table(table) }
      SlowQuery.install
      schema
    end

    private def self.sync_table(table : Symbol) : Nil
      if current = @@schema
        Registry.apply(current, table)
      end
    end

    private def self.warn_pending_migrations : Nil
      return unless config.env.development?
      return unless check = @@pending_check
      pending = check.call
      config.log.warn { "#{pending} pending migration(s): run `Tasks.migrate`" } if pending > 0
    rescue
      nil
    end

    private def self.connection_help(ex : Exception) : String
      <<-MSG
      Cannot connect to the database (#{URLResolver.redact(url)}): #{ex.message}
        - Is PostgreSQL running and reachable?
        - Create the database with `CQL::Postgres::Database::Tasks.create` (or `createdb`).
        - Point CQL at it with DATABASE_URL or `CQL::Postgres.configure { |c| c.url = "postgres://..." }`.
      MSG
    end
  end
end
