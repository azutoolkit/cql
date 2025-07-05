require "./schema_dump"

module CQL
  # Migrations are used to manage changes to the database schema over time.
  # Each migration is a subclass of `Migration` and must implement the `up` and `down` methods.
  #
  # The `up` method is used to apply the migration, while the `down` method is used to rollback the migration.
  # Migrations are executed in their version order defined.
  # The `Migrator` class is used to manage migrations and provides methods to apply, rollback, and redo migrations.
  # The `Migrator` class also provides methods to list applied and pending migrations.
  #
  # **Example** Creating a new migration
  #
  # ```
  # class CreateUsersTable < CQL::Migration(1)
  #   def up
  #     schema.alter :users do
  #       add_column :name, String
  #       add_column :age, Int32
  #     end
  #   end
  #
  #   def down
  #     schema.alter :users do
  #       drop_column :name
  #       drop_column :age
  #     end
  #   end
  # end
  # ```
  #
  # **Example** Applying migrations
  #
  # ```
  # migrator = CQL::Migrator.new(schema)
  # migrator.up
  # ```
  #
  # **Example** Rolling back migrations
  # ```
  # migrator.down
  # ```
  #
  # **Example** Redoing migrations
  # ```
  # migrator.redo
  # ```
  #
  # **Example** Rolling back to a specific version
  # ```
  # migrator.down_to(1_i64)
  # ```
  #
  # **Example** Applying to a specific version
  # ```
  # migrator.up_to(1_i64)
  # ```
  #
  # **Example** Listing applied migrations
  # ```
  # migrator.print_applied_migrations
  # ```
  #
  # **Example** Listing pending migrations
  # ```
  # migrator.print_pending_migrations
  # ```
  #
  # **Example** Listing rolled back migrations
  # ```
  # migrator.print_rolled_back_migrations
  # ```
  #
  # **Example** Listing the last migration
  # ```
  # migrator.last
  # ```
  #

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

    abstract def up
    abstract def down

    # Class method to access the migration version
    # Subclasses MUST define @@version
    def self.version : Int64
      @@version
    rescue ex : Exception
      raise NotImplementedError.new("#{self.name} must define @@version as Int64")
    end
  end

  abstract class Migration(V) < BaseMigration
    macro inherited
      getter schema : CQL::Schema

      CQL::Migrator.migrations << {{@type}}
      def self.version : Int64
        V
      end

      def initialize(@schema : CQL::Schema); end
    end
  end

  # Configuration for schema synchronization
  struct MigratorConfig
    property schema_file_path : String
    property schema_name : Symbol
    property schema_symbol : Symbol
    property migration_table_name : Symbol
    property? auto_sync : Bool = true

    def initialize(
      @schema_file_path : String = "src/schemas/app_schema.cr",
      @schema_name : Symbol = :AppSchema,
      @schema_symbol : Symbol = :app_schema,
      @migration_table_name : Symbol = :cql_schema_migrations,
      @auto_sync : Bool? = true,
    )
    end
  end

  # The `Migrator` class is used to manage migrations and provides methods to apply,
  # rollback, and redo migrations.
  # The `Migrator` class also provides methods to list applied and pending migrations.
  # **Example** Creating a new migrator
  # ```
  # schema = CQL::Schema.define(:northwind, "sqlite3://db.sqlite3") do |s|
  #   table :schema_migrations do
  #     primary :id, Int32
  #     column :name, String
  #     column :version, Int32, index: true, unique: true
  #     timestamps
  #   end
  # end
  # migrator = CQL::Migrator.new(schema)
  # ```
  #
  # **Example** Applying migrations
  # ```
  # migrator.up
  # ```
  class Migrator
    Log = CQL.config.logger

    # Represents a migration record.
    # @field id [Int32] the migration record id
    # @field name [String] the migration.name
    # @field version [Int32] the migration version
    # @field created_at [Time] the creation time
    # @field updated_at [Time] the update time
    # **Example** Creating a migration record
    # ```
    # record = CQL::MigrationRecord.new(0, "CreateUsersTable", 1)
    # ```

    getter schema : CQL::Schema
    getter config : MigratorConfig
    class_property migrations : Array(BaseMigration.class) = [] of BaseMigration.class
    getter repo : Repository(MigrationRecord, Int32)

    def initialize(@schema : Schema, @config = MigratorConfig.new)
      bootstrap_schema if @config.auto_sync?
      ensure_schema_migrations_table
      @repo = Repository(MigrationRecord, Int32).new(schema, @config.migration_table_name)
    end

    # Applies the pending migrations.
    #  - **@param** steps [Int32] the number of migrations to apply (default: all)
    # **Example** Applying migrations
    # ```
    # migrator.up
    # ```
    def up(steps : Int32 = Migrator.migrations.size)
      schema.exec_query do |conn|
        conn.transaction do
          sorted_migrations[0, steps].each do |migration_class|
            unless migration_applied?(migration_class.version)
              migration_class.new(schema).up
              record_migration(migration_class)
            end
          end
        end
      end

      # Update schema file after migrations
      update_schema_file if config.auto_sync?
      print_applied_migrations
    end

    # Rolls back the last migration.
    # - **@param** steps [Int32] the number of migrations to roll back (default: 1)
    # **Example** Rolling back migrations
    # ```
    # migrator.down
    # ```
    def down(steps : Int32 = Migrator.migrations.size)
      rolled_back_migrations = [] of BaseMigration.class
      schema.exec_query do |conn|
        conn.transaction do
          sorted_migrations.reverse[0, steps].each do |migration_class|
            if migration_applied?(migration_class.version)
              migration_class.new(schema).down
              remove_migration_record(migration_class)
              rolled_back_migrations << migration_class
            end
          end
        end
      end

      # Update schema file after rollback
      update_schema_file if config.auto_sync?
      # Pass the actually rolled back migrations to the print method
      print_rolled_back_migrations(rolled_back_migrations)
    end

    # Rolls back the last migration.
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
        schema_dumper = SchemaDump.new(schema.adapter, schema.uri)
        schema_dumper.dump_to_file(
          config.schema_file_path,
          config.schema_name,
          config.schema_symbol
        )
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
        schema_dumper = SchemaDump.new(schema.adapter, schema.uri)
        current_schema = schema_dumper.generate_schema_content(config.schema_name, config.schema_symbol)

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
    # @return [Migration.class | Nil]
    def last : BaseMigration.class | Nil
      last_record = repo.last
      return nil if last_record.nil?

      Migrator.migrations.find { |migration| migration.version == last_record.version }
    rescue DB::NoResultsError | CQL::Schema::ConnectionError
      nil
    end

    # Rolls back to a specific migration version.
    # - **@param** version [Int32] the version to roll back to
    # **Example** Rolling back to a specific version
    # ```
    # migrator.down_to(1)
    # ```
    def down_to(version : Int64)
      index = sorted_migrations.index { |migration| migration.version == version }
      down(index ? index + 1 : 0) if index
    end

    # Applies migrations up to a specific version.
    # - **@param** version [Int32] the version to apply up to
    # **Example** Applying to a specific version
    # ```
    # migrator.up_to(1)
    # ```
    def up_to(version : Int64)
      index = sorted_migrations.index { |migration| migration.version == version }
      up(index ? index + 1 : 0) if index
    end

    # Prints the rolled back migrations.
    # - **@param** m [Array(Migration.class)] the migrations to print
    # - **@return** [Nil]
    # **Example** Listing rolled back migrations
    # ```
    # migrator.print_rolled_back_migrations
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

    # Returns the pending migrations.
    # - **@return** [Array(MigrationRecord)]
    # **Example** Listing pending migrations
    # ```
    # migrator.pending_migrations
    # ```
    def pending_migrations : Array(BaseMigration.class)
      sorted_migrations.reject { |migration| migration_applied?(migration.version) }
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
      return if m.empty?

      # Calculate dynamic column widths
      status_width = 6 # Reduced from 8 for better fit
      version_width = [7, m.max_of?(&.version.to_s.size) || 7].max
      name_width = [20, m.max_of?(&.name.size) || 20].max

      # Ensure reasonable limits
      name_width = [name_width, 45].min # Reduced max width

      # Table header
      puts
      puts "┌#{"─" * (status_width + 2)}┬#{"─" * (name_width + 2)}┬#{"─" * (version_width + 2)}┐"
      puts "│ #{"Status".center(status_width)} │ #{"Migration".ljust(name_width)} │ #{"Version".rjust(version_width)} │"
      puts "├#{"─" * (status_width + 2)}┼#{"─" * (name_width + 2)}┼#{"─" * (version_width + 2)}┤"

      # Table rows
      m.each do |migration|
        # Format migration.name (truncate if too long)
        formatted_name = migration.name

        # Center status within exact width
        formatted_status = status.center(status_width)

        # Right-align version numbers for better readability
        formatted_version = migration.version.to_s.rjust(version_width)

        puts "│ #{formatted_status} │ #{formatted_name} │ #{formatted_version} │"
      end

      # Table footer
      puts "└#{"─" * (status_width + 2)}┴#{"─" * (name_width + 2)}┴#{"─" * (version_width + 2)}┘"
      puts
    end

    private def build_migration_record(migration : BaseMigration.class) : MigrationRecord
      MigrationRecord.new(0, migration.name, migration.version.to_i64)
    end

    private def sorted_migrations
      Migrator.migrations.sort_by(&.version)
    end

    private def ensure_schema_migrations_table
      # Table doesn't exist, create it
      schema.table @config.migration_table_name do
        primary :id, Int32
        column :name, String
        column :version, Int64, index: true, unique: true
        # Don't use timestamps macro for SQLite compatibility
        column :created_at, String, null: true
        column :updated_at, String, null: true
      end
      schema.tables[@config.migration_table_name].create!
    end

    private def migration_applied?(version)
      # Ensure the schema_migrations table exists before checking
      ensure_schema_migrations_table

      begin
        repo.exists?(version: version)
      rescue DB::NoResultsError | CQL::Schema::ConnectionError
        false
      end
    end

    private def record_migration(migration : BaseMigration.class)
      # Check if the migration already exists to avoid unique constraint errors
      unless migration_applied?(migration.version)
        repo.create(name: migration.name, version: migration.version)
      end
    end

    private def remove_migration_record(migration : BaseMigration.class)
      repo.delete_by(name: migration.name, version: migration.version)
    end

    class Error < Exception; end
  end
end
