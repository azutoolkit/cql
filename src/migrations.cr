module Cql
  abstract class Migration(T)
    # Stores all registered migrations
    @@migrations = [] of Migration.class

    # Automatically register the migration class upon inheritance
    macro inherited
      @@migrations << {{ @type }}
    end

    # Accessor to get all migrations
    def self.migrations : Array(Migration.class)
      @@migrations
    end

    abstract def up
    abstract def down

    # The version of this migration
    def version : T.class
      T
    end
  end


  class Migrator
    def initialize(@schema : Cql::Schema)
      ensure_schema_migrations_table
    end

    # Apply all pending migrations
    def migrate_up
      Migration.migrations.sort_by(&.version).each do |migration_class|
        unless migration_applied?(migration_class.version)
          migration = migration_class.new(schema)
          migration.up
          record_migration(migration.version)
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
        if applied?(migration_class.version)
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
    def last : Migration.class?
      version = schema.query.from(:schema_migrations).order(:version).last
      Migration.migrations.find { |m| m.version == version }
    end

    # Get list of pending migrations
    def pending : Array(Migration.class)
      applied_migrations = schema.query.from(:schema_migrations).select(:version).all(Tuple(Int64))
      Migration.migrations.map(&.version) - applied_migrations
    end

    private def ensure_schema_migrations_table
      schema.table :schema_migrations do
        primary
        column :version, Int64
        timestamps
      end

      schema.schema_migrations.create!
    end

    private def applied?(version) : Bool
      schema.query.from(:schema_migrations).where(version: version).exists?
    end

    private def record_migration(version)
      schema.insert.into(:schema_migrations).values(version: version).commit
    end

    private def remove_migration_record(version)
      schema.delete.from(:schema_migrations).where(version: version).commit
    end
  end
end
