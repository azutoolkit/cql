require "./migration_lock"
require "./migrator_config"
require "./migration_table"
require "./schema_dump"

module CQL
  class MigrationRecord
    include DB::Serializable

    getter id : Int32
    getter name : String
    getter version : Int64
    getter? created_at : Time?
    getter? updated_at : Time?

    def initialize(
      @id : Int32,
      @name : String,
      @version : Int64,
      @created_at = Time.local,
      @updated_at = Time.local,
    )
    end
  end

  abstract class BaseMigration
    @@version : Int64 = 0 # Initialize with a default value

    getter schema : CQL::Schema

    # `Migrator` calls `new(schema)` on every registered class, which must resolve even when no
    # migration class exists.
    def initialize(@schema : CQL::Schema); end

    abstract def up
    abstract def down

    # Runs this migration alone, outside the DDL transaction the others share and outside the migration lock, for
    # statements a transaction refuses (PostgreSQL's `CREATE INDEX CONCURRENTLY`). Make it safe to run again: a
    # failure keeps what it did, and two migrators starting at once can both run it.
    macro disable_ddl_transaction!
      def self.ddl_transaction? : Bool
        false
      end
    end

    def self.ddl_transaction? : Bool
      true
    end

    # Class method to access the migration version
    # Subclasses MUST define @@version
    def self.version : Int64
      @@version
    rescue Exception
      raise NotImplementedError.new("#{name} must define @@version as Int64")
    end
  end

  # Migrations are used to manage changes to the database schema over time.
  # Each migration is a subclass of `Migration(V)`, where `V` is its version, and implements `up` and `down`.
  #
  # The `up` method applies the migration, while the `down` method rolls it back.
  # Migrations run in version order. Defining the class registers it with `Migrator`, which applies,
  # rolls back and redoes migrations and lists the applied and pending ones.
  #
  # **Example** Creating a new migration
  #
  # ```
  # class AddPhoneToUsers < CQL::Migration(1)
  #   def up
  #     schema.alter :users do
  #       add_column :phone, String, null: true
  #     end
  #   end
  #
  #   def down
  #     schema.alter :users do
  #       drop_column :phone
  #     end
  #   end
  # end
  # ```
  #
  # **Example** Applying and rolling back migrations
  #
  # ```
  # migrator = CQL::Migrator.new(schema)
  # migrator.up
  # migrator.rollback
  # ```
  abstract class Migration(V) < BaseMigration
    macro inherited
      CQL::Migrator.migrations << {{@type}}
      def self.version : Int64
        V.to_i64
      end

      # Kept per class so `new(schema)` survives a migration that adds its own `initialize` overload.
      def initialize(@schema : CQL::Schema); end
    end
  end

  # The `Migrator` class is used to manage migrations and provides methods to apply,
  # rollback, and redo migrations.
  # The `Migrator` class also provides methods to list applied and pending migrations.
  # It records applied migrations in its own table (`cql_schema_migrations` by default, see `MigratorConfig`),
  # creating it when missing. On PostgreSQL, building it and a run with migrations to apply or roll back first take
  # an advisory lock, so migrators of one table take turns (see `MigratorConfig#lock_timeout`).
  #
  # **Example** Creating a new migrator
  # ```
  # migrator = CQL::Migrator.new(schema)
  # ```
  #
  # **Example** Applying migrations
  # ```
  # migrator.up
  # ```
  class Migrator
    Log = CQL.config.logger

    getter schema : CQL::Schema
    getter config : MigratorConfig
    class_property migrations : Array(BaseMigration.class) = [] of BaseMigration.class
    getter repo : Repository(MigrationRecord, Int32)

    def initialize(@schema : Schema, @config = MigratorConfig.new)
      @lock = MigrationLock.new(@schema, @config)
      reject_duplicate_versions!
      schema.ddl_transaction { @lock.acquire; ensure_schema_migrations_table }
      @repo = Repository(MigrationRecord, Int32).new(schema, @config.migration_table_name)
    end

    # Applies the oldest pending migrations, in version order.
    #  - **@param** steps [Int32] the number of pending migrations to apply (default: all)
    # **Example** Applying migrations
    # ```
    # migrator.up
    # ```
    def up(steps : Int32 = Migrator.migrations.size)
      migrate_up { pending_migrations.first(steps) }
    end

    # Rolls back the newest applied migrations, highest version first.
    # - **@param** steps [Int32] the number of applied migrations to roll back (default: all)
    # **Example** Rolling back migrations
    # ```
    # migrator.down
    # ```
    def down(steps : Int32 = Migrator.migrations.size)
      migrate_down { applied_migration_classes.last(steps) }
    end

    # Rolls back the newest applied migrations.
    # - **@param** steps [Int32] the number of migrations to roll back (default: 1)
    # **Example** Rolling back migrations
    # ```
    # migrator.rollback
    # ```
    #
    def rollback(steps : Int32 = 1)
      down(steps)
    end

    # Redoes the last migration.
    # **Example** Redoing migrations
    # ```
    # migrator.redo
    # ```
    def redo
      rollback
      up
    end

    # Bootstraps the AppSchema.cr file from the current database state.
    # This is useful when starting with an existing database.
    # **Example** Bootstrapping schema from existing database
    # ```
    # migrator.bootstrap_schema
    # ```
    def bootstrap_schema
      Log.info { "Bootstrapping schema from existing database..." }
      update_schema_file
      Log.info { "Schema bootstrapped successfully to #{config.schema_file_path}" }
    end

    # Manually updates the AppSchema.cr file to reflect current database state.
    # **Example** Manually updating schema file
    # ```
    # migrator.update_schema_file
    # ```
    def update_schema_file
      Log.debug { "Updating schema file: #{config.schema_file_path}" }

      begin
        write_schema_file
        Log.info { "Schema file updated: #{config.schema_file_path}" }
      rescue ex : Exception
        Log.error { "Failed to update schema file: #{ex.message}" }
        raise Error.new("Schema update failed: #{ex.message}")
      end
    end

    # Verifies that the current database state matches the AppSchema.cr file.
    # **Example** Verifying schema consistency
    # ```
    # consistent = migrator.verify_schema_consistency
    # ```
    def verify_schema_consistency : Bool
      Log.debug { "Verifying schema consistency..." }

      begin
        current_schema = SchemaDump.open(schema, &.generate_schema_content(config.schema_name, config.schema_symbol, config.schema_url_env))

        if File.exists?(config.schema_file_path)
          existing_schema = File.read(config.schema_file_path)
          consistent = current_schema == existing_schema

          if consistent
            Log.info { "Schema is consistent with database" }
          else
            Log.warn { "Schema file is out of sync with database" }
          end

          consistent
        else
          Log.warn { "Schema file does not exist: #{config.schema_file_path}" }
          false
        end
      rescue ex : Exception
        Log.error { "Failed to verify schema consistency: #{ex.message}" }
        false
      end
    end

    # Returns the last migration.
    # **Example** Listing the last migration
    # ```
    # migrator.last
    # ```
    # - **@return** [BaseMigration.class | Nil]
    def last : BaseMigration.class | Nil
      last_record = repo.last
      return if last_record.nil?

      Migrator.migrations.find { |migration| migration.version == last_record.version }
    rescue DB::NoResultsError | CQL::Schema::ConnectionError
      nil
    end

    # Rolls back every applied migration newer than *version*, which stays applied.
    # - **@param** version [Int64] the version to roll back to
    # - **@raise** [Error] if no migration has *version*
    # **Example** Rolling back to a specific version
    # ```
    # migrator.down_to(1_i64)
    # ```
    def down_to(version : Int64)
      require_registered!(version)
      migrate_down { applied_migration_classes.select { |migration| migration.version > version } }
    end

    # Applies every pending migration up to and including *version*.
    # - **@param** version [Int64] the version to apply up to
    # - **@raise** [Error] if no migration has *version*
    # **Example** Applying to a specific version
    # ```
    # migrator.up_to(1_i64)
    # ```
    def up_to(version : Int64)
      require_registered!(version)
      migrate_up { pending_migrations.select { |migration| migration.version <= version } }
    end

    # Prints the given migrations as rolled back.
    # - **@param** m [Array(BaseMigration.class)] the migrations to print
    # - **@return** [Nil]
    # **Example** Listing rolled back migrations
    # ```
    # migrator.print_rolled_back_migrations(CQL::Migrator.migrations)
    # ```
    def print_rolled_back_migrations(m : Array(BaseMigration.class))
      print_table(m.map { |migration| build_migration_record(migration) }, "✗".colorize.red.to_s)
    end

    # Prints the applied migrations.
    # **Example** Listing applied migrations
    # ```
    # migrator.print_applied_migrations
    # ```
    def print_applied_migrations
      print_table(applied_migrations)
    end

    # Prints the pending migrations.
    # **Example** Listing pending migrations
    # ```
    # migrator.print_pending_migrations
    # ```
    def print_pending_migrations
      print_table(pending_migrations.map { |migration| build_migration_record(migration) }, "⏱".colorize.yellow.to_s)
    end

    # Returns the pending migrations, read with one query of the migrations table that `Migrator.new` ensured.
    # - **@return** [Array(BaseMigration.class)]
    # **Example** Listing pending migrations
    # ```
    # migrator.pending_migrations
    # ```
    def pending_migrations : Array(BaseMigration.class)
      applied = applied_versions
      sorted_migrations.reject { |migration| applied.includes?(migration.version) }
    end

    # Returns the applied migrations.
    # - **@return** [Array(MigrationRecord)]
    # **Example** Listing applied migrations
    # ```
    # migrator.applied_migrations
    # ```
    def applied_migrations : Array(MigrationRecord)
      repo.all
    end

    private def print_table(m : Array(MigrationRecord), status : String = "✔".colorize.green.to_s)
      MigrationTable.new(m, status).print
    end

    private def build_migration_record(migration : BaseMigration.class) : MigrationRecord
      MigrationRecord.new(0, migration.name, migration.version.to_i64)
    end

    private def sorted_migrations
      reject_duplicate_versions!
      Migrator.migrations.sort_by(&.version)
    end

    private def applied_migration_classes : Array(BaseMigration.class)
      applied = applied_versions
      sorted_migrations.select { |migration| applied.includes?(migration.version) }
    end

    private def applied_versions : Set(Int64)
      repo.query.select(:version).all(Int64).to_set
    end

    # The records table keys on the version alone, so a shared version would apply both and record one.
    # Checked again before every run, as the registry is a mutable class property.
    private def reject_duplicate_versions! : Nil
      Migrator.migrations.group_by(&.version).each do |version, migrations|
        next if migrations.size == 1
        names = migrations.map(&.name).join(" and ")
        table = config.migration_table_name
        raise Error.new("Migrations #{names} share version #{version}; renumber the one #{table} does not list. " \
                        "If it already ran, first insert a #{table} row with its full class name and new version, " \
                        "or `up` runs it again")
      end
    end

    private def require_registered!(version : Int64) : Nil
      return if Migrator.migrations.any? { |migration| migration.version == version }
      raise Error.new("No migration with version #{version}")
    end

    # Consecutive migrations share a DDL transaction; one with `disable_ddl_transaction!` runs alone between them.
    private def migrate_up(&pick : -> Array(BaseMigration.class)) : Nil
      pick.call.slice_when { |a, b| !(a.ddl_transaction? && b.ddl_transaction?) }.each do |batch|
        next apply_alone(batch.first) unless batch.first.ddl_transaction?
        with_migration_lock(batch) { oldest_pending(batch).each { |migration| apply(migration) } }
      end

      sync_schema_file if config.auto_sync?
      print_applied_migrations
    end

    # The planned migrations still pending, checked under the lock: a waiter skips what the holder applied meanwhile,
    # and stops instead of passing over an older migration the holder rolled back.
    private def oldest_pending(planned : Array(BaseMigration.class)) : Array(BaseMigration.class)
      pending = pending_migrations
      todo = planned.select { |migration| pending.includes?(migration) }
      return todo if pending.first(todo.size) == todo
      raise Error.new("Another migrator rolled back #{(pending - todo).first.name} while this one waited for the " \
                      "migration lock; #{todo.first.name} and newer were not applied")
    end

    private def apply(migration : BaseMigration.class) : Nil
      migration.new(schema).up
      record_migration(migration)
    end

    # Outside the lock and any transaction of its own (`disable_ddl_transaction!`); recorded under the lock, unless a
    # migrator that ran it at the same time recorded it first.
    private def apply_alone(migration : BaseMigration.class) : Nil
      return if oldest_pending([migration] of BaseMigration.class).empty?
      migration.new(schema).up
      with_migration_lock([migration]) { record_migration(migration) if oldest_pending([migration] of BaseMigration.class).any? }
    end

    private def migrate_down(&pick : -> Array(BaseMigration.class)) : Nil
      newest_first = pick.call.reverse
      with_migration_lock(newest_first) do
        require_unchanged!(newest_first, pick.call.reverse)
        newest_first.each do |migration|
          migration.new(schema).down
          remove_migration_record(migration)
        end
      end

      sync_schema_file if config.auto_sync?
      print_rolled_back_migrations(newest_first)
    end

    # The migrations have committed by now, so a failed dump keeps the old file instead of failing the run.
    private def sync_schema_file : Nil
      write_schema_file
    rescue ex : Exception
      Log.warn { "Schema file #{config.schema_file_path} not updated after migrating: #{ex.message}" }
    end

    private def write_schema_file : Nil
      SchemaDump.open(schema) do |schema_dumper|
        schema_dumper.dump_to_file(config.schema_file_path, config.schema_name, config.schema_symbol, env_var: config.schema_url_env)
      end
    end

    # Picked before the lock, so a run with nothing to pick takes no lock (building the migrator still does).
    private def with_migration_lock(picked : Array(BaseMigration.class), &) : Nil
      return if picked.empty?
      schema.ddl_transaction do
        @lock.acquire
        yield
      end
    end

    # A waiter must not roll back what it did not choose, such as the next-older migration after the holder's rollback.
    private def require_unchanged!(picked : Array(BaseMigration.class), locked : Array(BaseMigration.class)) : Nil
      return if picked == locked
      raise Error.new("Another migrator changed the applied migrations while this one waited for the migration " \
                      "lock; nothing was rolled back")
    end

    private def ensure_schema_migrations_table
      schema.table @config.migration_table_name do
        primary :id, Int32
        column :name, String
        column :version, Int64, unique: true
        # Don't use timestamps macro for SQLite compatibility
        column :created_at, String, null: true
        column :updated_at, String, null: true
      end
      schema.tables[@config.migration_table_name].create!
    end

    # A version another migrator recorded during the run fails it instead of being skipped. Nothing guarantees a unique
    # index on the version (a table from a dumped schema may lack one), so only the migration lock rules out a record
    # that migrator has not committed yet.
    private def record_migration(migration : BaseMigration.class)
      if repo.exists?(version: migration.version)
        raise Error.new("Another migrator recorded #{migration.name} (version #{migration.version}) during this run; " \
                        "the run is rolled back where DDL is transactional")
      end
      repo.create(name: migration.name, version: migration.version)
    end

    private def remove_migration_record(migration : BaseMigration.class)
      repo.delete_by(name: migration.name, version: migration.version)
    end

    class Error < CQL::Error; end
  end
end
