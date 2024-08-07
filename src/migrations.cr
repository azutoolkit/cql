module Cql
   abstract class Migration
    getter schema : Schema

    macro inherited
      class_property version : Int64 = 0_i64
      Cql::Migrator.migrations << {{@type}}
    end

    def initialize(@schema : Schema)
    end

    abstract def up
    abstract def down
  end

  class Migrator

    class Migrated
      include DB::Serializable

      getter version : Int64
      getter created_at : Time
      getter updated_at : Time

      def initialize(
        @version : Int64,
        @created_at = Time.local,
        @updated_at = Time.local)
      end
    end

    getter schema : Schema
    class_property migrations : Array(Migration.class) = [] of Migration.class

    def initialize(@schema : Schema)
      ensure_schema_migrations_table
    end

    # Apply all pending migrations
    def migrate_up
      Migrator.migrations.sort_by(&.version).each do |migration_class|
        unless migration_applied?(migration_class.version)
          migration = migration_class.new(schema)
          migration.up
          record_migration(migration_class.version)
          puts "Applied migration: #{migration_class}"
        end
      end
    end

    # Rollback all applied migrations
    def migrate_down
      Migration.migrations.sort_by(&.version).reverse_each do |migration_class|
        if migration_applied?(migration_class.version)
          migration = migration_class.new(schema)
          migration.down
          remove_migration_record(migration.version)
          puts "Rolled back migration: #{migration_class}"
        end
      end
    end

    # Rollback the last N migrations
    # @param steps : Int32 = 1
    def rollback!(steps : Int32 = 1)
      Migration.migrations.sort_by(&.version).reverse.last(steps).each do |migration_class|
        if migration_applied?(migration_class.version)
          migration = migration_class.new(schema)
          migration.down
          remove_migration_record(migration.version)
          puts "Rolled back migration: #{migration_class}"
        end
      end
    end

    # Redo the last migration
    def redo
      rollback!
      migrate_up
    end

    # Get last applied migration
    def last : Migration.class | Nil
      schema.query
        .from(:schema_migrations)
        .order(version: :desc)
        .limit(1)
        .first!(Migrated)
    end

    # Get list of pending migrations
    def pending : Array(Migration.class)
      Migration.migrations.map(&.version) - applied_migrations.map(&.version)
    end

    def applied_migrations : Array(Migrated)
      schema.query
      .from(:schema_migrations)
      .all(Migrated)
    end

    private def ensure_schema_migrations_table
      schema.table :schema_migrations do
        column :version, Int64, index: true, unique: true
        timestamps
      end

      schema.schema_migrations.create!
    end

    private def migration_applied?(version)
      migrated = schema
        .query
        .from(:schema_migrations)
        .where(version: version)
        .first(Migrated)

      puts migrated

      false
    rescue DB::NoResultsError
      false
    end

    private def record_migration(version)
      schema.insert.into(:schema_migrations).values(version: version).commit
    end

    private def remove_migration_record(version)
      schema.delete.from(:schema_migrations).where(version: version).commit
    end
  end
end
