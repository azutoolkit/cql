require "tallboy"
require "colorize"

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

    def initialize(@schema : Schema); end

    abstract def up
    abstract def down
  end

  class Migrator
    Log = ::Log.for(self)

    class MigrationRecord
      include DB::Serializable

      getter id : Int64
      getter name : String
      getter version : Int64
      getter created_at : Time
      getter updated_at : Time

      def initialize(
        @id : Int64,
        @name : String,
        @version : Int64,
        @created_at = Time.local,
        @updated_at = Time.local
      )
      end
    end

    getter schema : Schema
    class_property migrations : Array(Migration.class) = [] of Migration.class
    getter repo : Repository(MigrationRecord)

    def initialize(@schema : Schema)
      ensure_schema_migrations_table
      @repo = Repository(MigrationRecord).new(schema, :schema_migrations)
    end

    def up(steps : Int32 = Migrator.migrations.size)
      sorted_migrations[0, steps].each do |migration_class|
        unless migration_applied?(migration_class.version)
          schema.db.transaction do
            migration_class.new(schema).up
            record_migration(migration_class)
          end
        end
      end
      print_applied_migrations
    end

    def down(steps : Int32 = Migrator.migrations.size)
      sorted_migrations.reverse[0, steps].each do |migration_class|
        if migration_applied?(migration_class.version)
          schema.db.transaction do
            migration_class.new(schema).down
            remove_migration_record(migration_class)
          end
        end
      end
      print_rolled_back_migrations(sorted_migrations.reverse[0, steps])
    end

    def rollback(steps : Int32 = 1)
      down(steps)
    end

    def redo
      rollback
      up
    end

    def last : Migration.class | Nil
      Migrator.migrations.find { |m| m.version == repo.last.version }
    rescue DB::NoResultsError
      nil
    end

    def down_to(version : Int64)
      index = sorted_migrations.index { |m| m.version == version }
      down(index ? index + 1 : 0) if index
    end

    def up_to(version : Int64)
      index = sorted_migrations.index { |m| m.version == version }
      up(index ? index + 1 : 0) if index
    end

    def print_rolled_back_migrations(m : Array(Migration.class))
      print_table(m.map { |migration| build_migration_record(migration) }, "✗".colorize.red.to_s)
    end

    def print_applied_migrations
      print_table(applied_migrations)
    end

    def print_pending_migrations
      print_table(pending_migrations, "⏱".colorize.yellow.to_s)
    end

    def pending_migrations : Array(MigrationRecord)
      sorted_migrations.reject { |m| migration_applied?(m.version) }.map { |m| build_migration_record(m) }
    end

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

    private def build_migration_record(migration : Migration.class) : MigrationRecord
      MigrationRecord.new(0, migration.name, migration.version)
    end

    private def sorted_migrations
      Migrator.migrations.sort_by(&.version)
    end

    private def ensure_schema_migrations_table
      schema.table :schema_migrations do
        primary :id, Int32
        column :name, String
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

    private def record_migration(migration : Migration.class)
      repo.create(name: migration.name, version: migration.version)
    end

    private def remove_migration_record(migration : Migration.class)
      repo.delete_by(name: migration.name, version: migration.version)
    end
  end
end
