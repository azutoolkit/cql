require "tallboy"
require "colorize"

module Cql
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
  # class CreateUsersTable < Cql::Migration
  #   self.version = 1_i64
  #
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
  # schema = Cql::Schema.define(:northwind, "sqlite3://db.sqlite3") do |s|
  #   table :schema_migrations do
  #     primary :id, Int32
  #     column :name, String
  #     column :version, Int64, index: true, unique: true
  #     timestamps
  #   end
  # end
  # migrator = Cql::Migrator.new(schema)
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

  abstract class BaseMigration
    abstract def up
    abstract def down
  end

  abstract class Migration(V) < BaseMigration
    macro inherited
      getter schema : Cql::Schema

      Cql::Migrator.migrations << {{@type}}
      def self.version : Int32
        V
      end

      def initialize(@schema : Cql::Schema); end
    end
  end

  # The `Migrator` class is used to manage migrations and provides methods to apply,
  # rollback, and redo migrations.
  # The `Migrator` class also provides methods to list applied and pending migrations.
  # **Example** Creating a new migrator
  # ```
  # schema = Cql::Schema.define(:northwind, "sqlite3://db.sqlite3") do |s|
  #   table :schema_migrations do
  #     primary :id, Int32
  #     column :name, String
  #     column :version, Int64, index: true, unique: true
  #     timestamps
  #   end
  # end
  # migrator = Cql::Migrator.new(schema)
  # ```
  #
  # **Example** Applying migrations
  # ```
  # migrator.up
  # ```
  class Migrator
    Log = ::Log.for(self)

    # Represents a migration record.
    # @field id [Int64] the migration record id
    # @field name [String] the migration name
    # @field version [Int64] the migration version
    # @field created_at [Time] the creation time
    # @field updated_at [Time] the update time
    # **Example** Creating a migration record
    # ```
    # record = Cql::MigrationRecord.new(0_i64, "CreateUsersTable", 1_i64)
    # ```
    class MigrationRecord
      include DB::Serializable

      getter id : Int64
      getter name : String
      getter version : Int32
      getter created_at : Time
      getter updated_at : Time

      def initialize(
        @id : Int64,
        @name : String,
        @version : Int32,
        @created_at = Time.local,
        @updated_at = Time.local
      )
      end
    end

    getter schema : Schema
    class_property migrations : Array(BaseMigration.class) = [] of BaseMigration.class
    getter repo : Repository(MigrationRecord, Int32)

    def initialize(@schema : Schema)
      ensure_schema_migrations_table
      @repo = Repository(MigrationRecord, Int32).new(schema, :schema_migrations)
    end

    # Applies the pending migrations.
    #  - **@param** steps [Int32] the number of migrations to apply (default: all)
    # **Example** Applying migrations
    # ```
    # migrator.up
    # ```
    def up(steps : Int32 = Migrator.migrations.size)
      sorted_migrations[0, steps].each do |migration_class|
        unless migration_applied?(migration_class.version)
          migration_class.new(schema).up
          record_migration(migration_class)
        end
      end
      print_applied_migrations
    end

    # Rolls back the last migration.
    # - **@param** steps [Int32] the number of migrations to roll back (default: 1)
    # **Example** Rolling back migrations
    # ```
    # migrator.down
    # ```
    def down(steps : Int32 = Migrator.migrations.size)
      sorted_migrations.reverse[0, steps].each do |migration_class|
        if migration_applied?(migration_class.version)
          migration_class.new(schema).down
          remove_migration_record(migration_class)
        end
      end
      print_rolled_back_migrations(sorted_migrations.reverse[0, steps])
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

    # Returns the last migration.
    # **Example** Listing the last migration
    # ```
    # migrator.last
    # ```
    # @return [Migration.class | Nil]
    def last : BaseMigration.class | Nil
      Migrator.migrations.find { |m| m.version == repo.last.version }
    rescue DB::NoResultsError
      nil
    end

    # Rolls back to a specific migration version.
    # - **@param** version [Int64] the version to roll back to
    # **Example** Rolling back to a specific version
    # ```
    # migrator.down_to(1_i64)
    # ```
    def down_to(version : Int64)
      index = sorted_migrations.index { |m| m.version == version }
      down(index ? index + 1 : 0) if index
    end

    # Applies migrations up to a specific version.
    # - **@param** version [Int64] the version to apply up to
    # **Example** Applying to a specific version
    # ```
    # migrator.up_to(1_i64)
    # ```
    def up_to(version : Int64)
      index = sorted_migrations.index { |m| m.version == version }
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
      print_table(pending_migrations.map { |m| build_migration_record(m) }, "⏱".colorize.yellow.to_s)
    end

    # Returns the pending migrations.
    # - **@return** [Array(MigrationRecord)]
    # **Example** Listing pending migrations
    # ```
    # migrator.pending_migrations
    # ```
    def pending_migrations : Array(BaseMigration.class)
      sorted_migrations.reject { |m| migration_applied?(m.version) }
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
      records = m.map { |migration| [status, migration.name, migration.version] }
      table = Tallboy.table do
        columns do
          add "", width: 3, align: :center
          add "Migration"
          add "Version"
        end
        header
        rows records
      end
      puts table
    end

    private def build_migration_record(migration : BaseMigration.class) : MigrationRecord
      MigrationRecord.new(0, migration.name, migration.version)
    end

    private def sorted_migrations
      Migrator.migrations.sort_by(&.version)
    end

    private def ensure_schema_migrations_table
      schema.table :schema_migrations do
        primary :id, Int32
        column :name, String
        column :version, Int32, index: true, unique: true
        timestamps
      end
      schema.schema_migrations.create!
    end

    private def migration_applied?(version)
      repo.exists?(version: version)
    rescue DB::NoResultsError
      false
    end

    private def record_migration(migration : BaseMigration.class)
      repo.create(name: migration.name, version: migration.version)
    end

    private def remove_migration_record(migration : BaseMigration.class)
      repo.delete_by(name: migration.name, version: migration.version)
    end
  end
end
