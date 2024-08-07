module Cql
  abstract class Migration
    getter schema : Schema

    macro inherited
      class_getter version : Int64 = 0_i64

      def self.version=(number : Int64)
        @@version = number
      end
      Cql::Migrator.migrations << {{@type}}
    end

    def initialize(@schema : Schema)
    end

    abstract def up
    abstract def down
  end

  class Migrator
    Log = ::Log.for(self)

    class AppliedMigration
      include DB::Serializable

      getter id : Int64
      getter version : Int64
      getter created_at : Time
      getter updated_at : Time

      def initialize(
        @id : Int64,
        @version : Int64,
        @created_at = Time.local,
        @updated_at = Time.local
      )
      end
    end

    getter schema : Schema
    class_property migrations : Array(Migration.class) = [] of Migration.class
    getter repo : Repository(AppliedMigration)

    def initialize(@schema : Schema)
      ensure_schema_migrations_table
      @repo = Repository(AppliedMigration).new(schema, :schema_migrations)
    end

    # Apply all pending migrations
    def up(steps : Int32 = Migrator.migrations.size)
      sorted_migrations.each do |migration_class|
        unless migration_applied?(migration_class.version)
          migration = migration_class.new(schema)
          migration.up
          record_migration(migration_class.version)
          Log.info { "#{migration_class.version} - #{migration_class} - Applied" }
        end
      end
    end

    # Rollback all applied migrations
    def down(steps : Int32 = Migrator.migrations.size)
      sorted_migrations.reverse[0..steps - 1].each do |migration_class|
        if migration_applied?(migration_class.version)
          Log.info { "Rolling back: #{migration_class.version} - #{migration_class}" }
          migration = migration_class.new(schema)
          migration.down
          remove_migration_record(migration_class.version)
        end
      end
    end

    # Rollback the last N migrations
    # @param steps : Int32 = 1
    def rollback(steps : Int32 = 1)
      down(steps)
    end

    # Redo the last migration
    def redo
      rollback
      up
    end

    # Get last applied migration
    def last : Migration.class | Nil
      Migrator.migrations.find { |m| m.version == repo.last.version }
    rescue DB::NoResultsError
      nil
    end

    # Get list of pending migrations
    def pending : Array(Migration.class)
      Migration.migrations.map(&.version) - applied_migrations.map(&.version)
    end

    def applied_migrations : Array(AppliedMigration)
      repo.all
    end

    private def sorted_migrations
      Migrator.migrations.sort_by(&.version)
    end

    private def ensure_schema_migrations_table
      schema.table :schema_migrations do
        primary :id, Int32
        column :version, Int64, index: true, unique: true
        timestamps
      end

      schema.schema_migrations.create!
    end

    private def migration_applied?(version)
      repo.exists?(version: version)
    rescue DB::NoResultsError
      false
    end

    private def record_migration(version)
      repo.create(version: version)
    end

    private def remove_migration_record(version)
      repo.delete_by(version: version)
    end
  end
end
