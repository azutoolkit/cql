require "pg"
require "../spec_helper"

# Two migrators racing on one PostgreSQL database: the second waits for the first's lock. Pending without a server
# reachable through DATABASE_URL.

private COUNTER         = "cql_lock_counter_#{Random::Secure.hex(4)}"
private MIGRATION_TABLE = :cql_lock_spec_migrations # a Symbol, so fixed: dropped before and after the run

class LockSpecCreateCounter < CQL::Migration(20990301000001)
  def up
    schema.exec("CREATE TABLE #{COUNTER} (n INTEGER NOT NULL)")
    schema.exec("INSERT INTO #{COUNTER} (n) VALUES (0)")
  end

  def down
    schema.exec("DROP TABLE #{COUNTER}")
  end
end

# Each direction sleeps, holding the run open while the other migrator starts.
class LockSpecIncrementCounter < CQL::Migration(20990301000002)
  def up
    schema.exec("UPDATE #{COUNTER} SET n = n + 1")
    schema.exec("SELECT pg_sleep(0.5)")
  end

  def down
    schema.exec("UPDATE #{COUNTER} SET n = n - 1")
    schema.exec("SELECT pg_sleep(0.5)")
  end
end

private LOCK_HELD = Channel(Nil).new(1)

# Oldest, so `up(1)` applies it alone: holds the run (and its lock) open for 2 s, saying when the lock is taken.
class LockSpecHoldLock < CQL::Migration(20990301000000)
  def up
    LOCK_HELD.send(nil)
    schema.exec("SELECT pg_sleep(2)")
  end

  def down
  end
end

# Newest: records the lock_timeout its run applies it under.
class LockSpecReadLockTimeout < CQL::Migration(20990301000003)
  class_property seen : String?

  def up
    self.class.seen = schema.exec_query(&.query_one("SELECT current_setting('lock_timeout')", as: String))
  end

  def down
  end
end

# `CQL::Migration(V)` registers globally: keep these out of every other spec's registry.
CQL::Migrator.migrations.reject!(&.in?(LockSpecCreateCounter, LockSpecIncrementCounter, LockSpecHoldLock, LockSpecReadLockTimeout))

# Two schemas (separate pools, so separate connections) with only the lock-spec migrations registered and no
# migrations table yet; restores the registry and drops the tables afterwards.
private def with_lock_spec_migrations(url = postgres_database_url, &)
  original = CQL::Migrator.migrations
  schemas = {1, 2}.map { CQL::Schema.new(:migrator_lock, url, CQL::Adapter::Postgres) }
  begin
    schemas[0].exec("DROP TABLE IF EXISTS #{MIGRATION_TABLE}")
    CQL::Migrator.migrations = [LockSpecCreateCounter, LockSpecIncrementCounter] of CQL::BaseMigration.class
    yield schemas, CQL::MigratorConfig.new(auto_sync: false, migration_table_name: MIGRATION_TABLE)
  ensure
    CQL::Migrator.migrations = original
    schemas[0].exec("DROP TABLE IF EXISTS #{COUNTER}, #{MIGRATION_TABLE}")
    schemas.each(&.close)
  end
end

# Runs the block on every item at once, each in its own fiber, and returns the errors raised.
private def race(items : Enumerable(T), &block : T -> _) : Array(Exception) forall T
  outcomes = Channel(Exception?).new
  items.each do |item|
    spawn do
      block.call(item)
      outcomes.send(nil)
    rescue error
      outcomes.send(error)
    end
  end
  Array.new(items.size) { outcomes.receive }.compact
end

private def recorded_versions(schema : CQL::Schema) : Array(Int64)
  schema.exec_query(&.query_all("SELECT version FROM #{MIGRATION_TABLE} ORDER BY version", as: Int64))
end

describe "CQL::Migrator's migration lock on PostgreSQL" do
  it "lets two first-boot migrators create the table and apply each migration exactly once" do
    require_postgres!
    with_lock_spec_migrations do |schemas, config|
      errors = race(schemas) { |schema| CQL::Migrator.new(schema, config).up }

      errors.map { |error| "#{error.class}: #{error.message}" }.should be_empty
      schemas[0].exec_query(&.scalar("SELECT n FROM #{COUNTER}")).should eq(1)
      recorded_versions(schemas[0]).size.should eq(2)
    end
  end

  it "rolls back one migration for two concurrent rollbacks, and the waiter raises instead of taking the older one" do
    require_postgres!
    with_lock_spec_migrations do |schemas, config|
      CQL::Migrator.new(schemas[0], config).up
      migrators = schemas.map { |schema| CQL::Migrator.new(schema, config) } # built first: building waits on the lock

      errors = race(migrators, &.rollback(1))

      errors.map(&.class).should eq([CQL::Migrator::Error])
      recorded_versions(schemas[0]).should eq([LockSpecCreateCounter.version])
      schemas[0].exec_query(&.scalar("SELECT n FROM #{COUNTER}")).should eq(0)
    end
  end

  it "gives up after lock_timeout while another migrator holds the lock, applying nothing until it is free" do
    require_postgres!
    with_lock_spec_migrations do |schemas, config|
      CQL::Migrator.migrations.unshift(LockSpecHoldLock)
      impatient = CQL::MigratorConfig.new(auto_sync: false, migration_table_name: MIGRATION_TABLE, lock_timeout: 0.5.seconds)
      waiter = CQL::Migrator.new(schemas[1], impatient) # built first: building waits on the lock
      holder = CQL::Migrator.new(schemas[0], config)
      waited = Time::Span.zero
      errors = race({holder, waiter}) do |migrator|
        next migrator.up(1) if migrator.same?(holder)
        LOCK_HELD.receive
        waited = Time.measure do
          error = expect_raises(CQL::Migrator::Error, /lock_timeout/) { migrator.up }
          error.message.to_s.should contain(MIGRATION_TABLE.to_s)
        end
        expect_raises(CQL::Migrator::Error, /lock_timeout/) { CQL::Migrator.new(schemas[1], impatient) }
      end

      errors.map { |error| "#{error.class}: #{error.message}" }.should be_empty
      (0.45.seconds...2.seconds).should contain(waited) # the holder's run lasts 2 s: an earlier error is the timeout's
      recorded_versions(schemas[1]).should eq([LockSpecHoldLock.version])
      waiter.up # the same connections, once the lock is free
      recorded_versions(schemas[1]).size.should eq(3)
      schemas[1].exec_query(&.scalar("SELECT n FROM #{COUNTER}")).should eq(1)
    end
  end

  it "bounds only the lock wait: migrations run under the connection's own lock_timeout, which the run leaves as it was" do
    require_postgres!
    single = "#{postgres_database_url}#{postgres_database_url.includes?('?') ? '&' : '?'}max_pool_size=1&initial_pool_size=1"
    with_lock_spec_migrations(single) do |(schema, _), config|
      CQL::Migrator.migrations = [LockSpecReadLockTimeout] of CQL::BaseMigration.class
      schema.exec("SET lock_timeout = '7s'") # on the pool's only connection
      config.lock_timeout = 0.5.seconds
      CQL::Migrator.new(schema, config).up

      LockSpecReadLockTimeout.seen.should eq("7s")
      schema.exec_query(&.query_one("SELECT current_setting('lock_timeout')", as: String)).should eq("7s")
    end
  end

  it "refuses a REPEATABLE READ or SERIALIZABLE transaction, whose snapshot predates the lock wait" do
    require_postgres!
    with_lock_spec_migrations do |(schema, _), config|
      migrator = CQL::Migrator.new(schema, config)
      {"REPEATABLE READ", "SERIALIZABLE"}.each do |level|
        expect_raises(CQL::Migrator::Error, /READ COMMITTED, not #{level}/) do
          schema.transaction do
            schema.exec("SET TRANSACTION ISOLATION LEVEL #{level}")
            migrator.up
          end
        end
      end
      recorded_versions(schema).should be_empty
      schema.exec_query(&.scalar("SELECT to_regclass('#{COUNTER}') IS NULL")).should be_true
    end
  end
end
