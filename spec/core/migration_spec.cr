require "../spec_helper"

# Not `CQL::Migration(V)` subclasses: those register themselves in the global `CQL::Migrator.migrations`.
abstract class StepMigration < CQL::BaseMigration
  def up
    schema.exec("CREATE TABLE step_migration_#{self.class.version} (id INTEGER)")
  end

  def down
    schema.exec("DROP TABLE step_migration_#{self.class.version}")
  end
end

class StepMigrationOne < StepMigration
  def self.version : Int64
    1_i64
  end
end

class StepMigrationTwo < StepMigration
  def self.version : Int64
    2_i64
  end
end

class StepMigrationThree < StepMigration
  def self.version : Int64
    3_i64
  end
end

# Runs the block with only *migrations* registered, on a fresh SQLite file.
private def with_step_migrator(*migrations : CQL::BaseMigration.class, &)
  original = CQL::Migrator.migrations
  db_file = File.join(Dir.tempdir, "cql_migration_steps_#{Process.pid}_#{Random::Secure.hex(4)}.db")
  schema = CQL::Schema.new(:migration_steps, "sqlite3://#{db_file}", CQL::Adapter::SQLite)
  begin
    CQL::Migrator.migrations = [*migrations] of CQL::BaseMigration.class
    yield CQL::Migrator.new(schema, CQL::MigratorConfig.new(auto_sync: false))
  ensure
    CQL::Migrator.migrations = original
    schema.close
    File.delete(db_file) if File.exists?(db_file)
  end
end

private def applied_versions(migrator : CQL::Migrator) : Array(Int64)
  migrator.applied_migrations.map(&.version).sort!
end

# Yields a schema on a fresh SQLite file and the path of a schema file that does not exist yet.
private def with_sync_schema(&)
  name = "cql_schema_sync_#{Process.pid}_#{Random::Secure.hex(4)}"
  db_file = File.join(Dir.tempdir, "#{name}.db")
  schema_file = File.join(Dir.tempdir, "#{name}.cr")
  schema = CQL::Schema.new(:schema_sync, "sqlite3://#{db_file}", CQL::Adapter::SQLite)
  begin
    yield schema, schema_file
  ensure
    schema.close
    [db_file, schema_file].each { |path| File.delete(path) if File.exists?(path) }
  end
end

# Points `CQL.config` at *schema_file* with `verify_schema` and `auto_sync` on, then restores it.
private def with_verify_schema_config(schema_file : String, &)
  config = CQL.config
  saved = {config.schema_dir, config.schema_file, config.auto_sync, config.verify_schema}
  config.schema_dir = File.dirname(schema_file)
  config.schema_file = File.basename(schema_file)
  config.auto_sync = true
  config.verify_schema = true
  begin
    yield
  ensure
    config.schema_dir, config.schema_file, config.auto_sync, config.verify_schema = saved
  end
end

describe "CQL::Migrator stepping" do
  it "applies the next pending migrations with up(n)" do
    with_step_migrator(StepMigrationOne, StepMigrationTwo, StepMigrationThree) do |migrator|
      migrator.up(1)
      migrator.up(1)

      applied_versions(migrator).should eq [1_i64, 2_i64]
    end
  end

  it "applies a pending migration registered below applied ones first with up(n)" do
    with_step_migrator(StepMigrationOne, StepMigrationThree) do |migrator|
      migrator.up
      CQL::Migrator.migrations << StepMigrationTwo

      migrator.up(1)

      applied_versions(migrator).should eq [1_i64, 2_i64, 3_i64]
    end
  end

  it "rolls back the newest applied migrations with down(n)" do
    with_step_migrator(StepMigrationOne, StepMigrationTwo, StepMigrationThree) do |migrator|
      migrator.up(2)

      migrator.down(1)

      applied_versions(migrator).should eq [1_i64]
    end
  end

  it "rolls back the newest applied migration with rollback" do
    with_step_migrator(StepMigrationOne, StepMigrationTwo, StepMigrationThree) do |migrator|
      migrator.up(2)

      migrator.rollback

      applied_versions(migrator).should eq [1_i64]
    end
  end

  it "rolls back every migration above a version and keeps that version applied with down_to" do
    with_step_migrator(StepMigrationOne, StepMigrationTwo, StepMigrationThree) do |migrator|
      migrator.up

      migrator.down_to(1_i64)

      applied_versions(migrator).should eq [1_i64]
      migrator.pending_migrations.should eq [StepMigrationTwo, StepMigrationThree] of CQL::BaseMigration.class
    end
  end

  it "applies every pending migration up to and including a version with up_to" do
    with_step_migrator(StepMigrationOne, StepMigrationThree) do |migrator|
      migrator.up
      CQL::Migrator.migrations << StepMigrationTwo

      migrator.up_to(2_i64)

      applied_versions(migrator).should eq [1_i64, 2_i64, 3_i64]
    end
  end

  it "rolls back every migration with down_to(0)" do
    with_step_migrator(StepMigrationOne, StepMigrationTwo) do |migrator|
      migrator.up

      migrator.down_to(0_i64)

      applied_versions(migrator).should be_empty
    end
  end

  it "does nothing when up has nothing pending or down has nothing applied" do
    with_step_migrator(StepMigrationOne) do |migrator|
      migrator.down
      applied_versions(migrator).should be_empty

      migrator.up
      migrator.up
      applied_versions(migrator).should eq [1_i64]
    end
  end
end

describe "CQL::Migrator without migrations" do
  it "compiles when no migration class is defined" do
    success, _output, error = Snippets.compile <<-CRYSTAL
      require "./src/cql"

      schema = CQL::Schema.new(:no_migrations, "sqlite3://./no_migrations.db", CQL::Adapter::SQLite)
      migrator = CQL::Migrator.new(schema, CQL::MigratorConfig.new(auto_sync: false))
      migrator.up
      migrator.down
      migrator.redo
      CRYSTAL

    error.should_not contain("Error")
    success.should be_true
  end
end

describe CQL::Migration do
  migrator = Northwind.migrator(CQL::MigratorConfig.new(auto_sync: false))

  before_each do
    migrator.down rescue nil
    Northwind.users.drop! rescue nil
  end

  it "has a migration" do
    CQL::Migrator.migrations.size.should eq(2)
  end

  it "migrates up" do
    migrator.up

    migrator.last.try(&.version).should eq(AlterUsersMigration.version)
    migrator.applied_migrations.map(&.version).should eq([CreateUsersMigration.version, AlterUsersMigration.version])
  end

  it "migrates down" do
    migrator.up

    migrator.down

    migrator.last.should be_nil
    migrator.applied_migrations.size.should eq(0)
    migrator.applied_migrations.map(&.version).should eq([] of Int32)
  end

  it "rolls back" do
    migrator.up

    migrator.rollback(2)

    migrator.last.try(&.version).should be_nil
    migrator.applied_migrations.map(&.version).should eq([] of Int32)
  end

  it "redo" do
    migrator.up

    migrator.last.try(&.version).should eq(AlterUsersMigration.version)
    migrator.applied_migrations.map(&.version).should eq([CreateUsersMigration.version, AlterUsersMigration.version])

    migrator.redo

    migrator.last.try(&.version).should eq(AlterUsersMigration.version)
    migrator.applied_migrations.map(&.version).should eq([CreateUsersMigration.version, AlterUsersMigration.version])
  end

  it "migrates down to a specific version" do
    migrator.up

    migrator.down_to(CreateUsersMigration.version)

    migrator.last.try(&.version).should eq(CreateUsersMigration.version)
    migrator.applied_migrations.map(&.version).should eq([CreateUsersMigration.version])
  end

  it "migrates up to a specific version" do
    migrator.up_to(AlterUsersMigration.version)

    migrator.last.try(&.version).should eq(AlterUsersMigration.version)
    migrator.applied_migrations.map(&.version).should eq([CreateUsersMigration.version, AlterUsersMigration.version])
  end

  it "prints pending migrations" do
    migrator.down
    migrator.print_pending_migrations
    migrator.pending_migrations.should be_a(Array(CQL::BaseMigration.class))
  end

  # New comprehensive tests for missing functionality

  describe "MigratorConfig" do
    it "creates with default values" do
      config = CQL::MigratorConfig.new
      config.schema_file_path.should eq("src/schemas/app_schema.cr")
      config.schema_name.should eq(:AppSchema)
      config.schema_symbol.should eq(:app_schema)
      config.auto_sync?.should be_true
    end

    it "creates with custom values" do
      config = CQL::MigratorConfig.new(
        schema_file_path: "spec/test_schema.cr",
        schema_name: :TestSchema,
        schema_symbol: :test_schema,
        auto_sync: false
      )
      config.schema_file_path.should eq("spec/test_schema.cr")
      config.schema_name.should eq(:TestSchema)
      config.schema_symbol.should eq(:test_schema)
      config.auto_sync?.should be_false
    end
  end

  describe "Schema synchronization" do
    stale_schema = "# stale schema file\n"

    it "keeps an existing schema file when a migrator with auto_sync is built" do
      with_sync_schema do |schema, schema_file|
        File.write(schema_file, stale_schema)

        stale_migrator = schema.migrator(CQL::MigratorConfig.new(schema_file_path: schema_file, auto_sync: true))

        File.read(schema_file).should eq stale_schema
        stale_migrator.verify_schema_consistency.should be_false
      end
    end

    it "writes a missing schema file after creating the migrations table" do
      with_sync_schema do |schema, schema_file|
        synced_migrator = schema.migrator(CQL::MigratorConfig.new(schema_file_path: schema_file, auto_sync: true))

        File.read(schema_file).should contain "cql_schema_migrations"
        synced_migrator.verify_schema_consistency.should be_true
      end
    end

    it "reports a stale schema file from CQL.verify_schema without rewriting it first" do
      with_sync_schema do |schema, schema_file|
        with_verify_schema_config(schema_file) do
          File.write(schema_file, stale_schema)

          CQL.verify_schema(schema).should be_false
          File.read(schema_file).should eq stale_schema
        end
      end
    end

    it "reports a missing schema file from CQL.verify_schema without writing it" do
      with_sync_schema do |schema, schema_file|
        with_verify_schema_config(schema_file) do
          CQL.verify_schema(schema).should be_false
          File.exists?(schema_file).should be_false
        end
      end
    end

    it "rewrites a stale schema file from CQL.verify_schema with auto_fix" do
      with_sync_schema do |schema, schema_file|
        with_verify_schema_config(schema_file) do
          File.write(schema_file, stale_schema)

          CQL.verify_schema(schema, auto_fix: true).should be_true
          schema.migrator(CQL.migrator_config(auto_sync: false)).verify_schema_consistency.should be_true
        end
      end
    end

    it "creates migrator with custom config" do
      config = CQL::MigratorConfig.new(
        schema_file_path: "spec/support/test_auto_schema.cr",
        schema_name: :TestAutoSchema,
        schema_symbol: :test_auto_schema,
        auto_sync: false
      )
      custom_migrator = Northwind.migrator(config)
      custom_migrator.config.should eq(config)
    end

    it "verifies schema consistency" do
      config = CQL::MigratorConfig.new(
        schema_file_path: "spec/support/nonexistent_schema.cr",
        auto_sync: false
      )
      test_migrator = Northwind.migrator(config)

      # Should handle missing schema file gracefully
      result = test_migrator.verify_schema_consistency
      result.should be_false
    end

    it "handles schema file operations" do
      temp_file = "spec/support/temp_schema.cr"
      config = CQL::MigratorConfig.new(
        schema_file_path: temp_file,
        schema_name: :TempSchema,
        schema_symbol: :temp_schema,
        auto_sync: false
      )
      test_migrator = Northwind.migrator(config)

      # Clean up any existing temp file
      File.delete(temp_file) if File.exists?(temp_file)

      # Update schema file should create the file
      test_migrator.update_schema_file
      File.exists?(temp_file).should be_true

      # Clean up
      File.delete(temp_file) if File.exists?(temp_file)
    end

    it "bootstraps schema from existing database" do
      temp_file = "spec/support/bootstrap_schema.cr"
      config = CQL::MigratorConfig.new(
        schema_file_path: temp_file,
        schema_name: :BootstrapSchema,
        schema_symbol: :bootstrap_schema,
        auto_sync: false
      )
      test_migrator = Northwind.migrator(config)

      # Clean up any existing temp file
      File.delete(temp_file) if File.exists?(temp_file)

      # Bootstrap should create the schema file
      test_migrator.bootstrap_schema
      File.exists?(temp_file).should be_true

      # Clean up
      File.delete(temp_file) if File.exists?(temp_file)
    end
  end

  describe "Migration collection methods" do
    it "returns applied migrations" do
      migrator.up
      applied = migrator.applied_migrations
      applied.should be_a(Array(CQL::MigrationRecord))
      applied.size.should eq(2)
      applied.map(&.version).should eq([CreateUsersMigration.version, AlterUsersMigration.version])
    end

    it "returns pending migrations when all applied" do
      migrator.up
      pending = migrator.pending_migrations
      pending.should be_a(Array(CQL::BaseMigration.class))
      pending.size.should eq(0)
    end

    it "returns pending migrations when none applied" do
      migrator.down
      pending = migrator.pending_migrations
      pending.should be_a(Array(CQL::BaseMigration.class))
      pending.size.should eq(2)
      pending.map(&.version).should eq([CreateUsersMigration.version, AlterUsersMigration.version])
    end

    it "handles last migration when none applied" do
      migrator.down
      migrator.last.should be_nil
    end

    it "handles last migration when applied" do
      migrator.up
      last = migrator.last
      last.should_not be_nil
      last.try(&.version).should eq(AlterUsersMigration.version)
    end
  end

  describe "Migration steps parameter" do
    it "migrates up with limited steps" do
      migrator.down  # Reset
      migrator.up(1) # Only migrate one step

      migrator.applied_migrations.size.should eq(1)
      migrator.last.try(&.version).should eq(CreateUsersMigration.version)
    end

    it "migrates down with limited steps" do
      migrator.up      # Apply all
      migrator.down(1) # Only rollback one step

      migrator.applied_migrations.size.should eq(1)
      migrator.last.try(&.version).should eq(CreateUsersMigration.version)
    end

    it "rollback with custom steps" do
      migrator.up          # Apply all
      migrator.rollback(1) # Rollback one step

      migrator.applied_migrations.size.should eq(1)
      migrator.last.try(&.version).should eq(CreateUsersMigration.version)
    end
  end

  describe "Print methods" do
    it "prints applied migrations" do
      migrator.up
      # This should not raise an error
      migrator.print_applied_migrations
    end

    it "prints rolled back migrations with custom list" do
      migrations = [CreateUsersMigration, AlterUsersMigration]
      # This should not raise an error
      migrator.print_rolled_back_migrations(migrations)
    end
  end

  describe "Migration versioning and naming" do
    it "has correct migration versions" do
      CreateUsersMigration.version.should eq(20250705001401)
      AlterUsersMigration.version.should eq(20250705001402)
    end

    it "generates migration names correctly" do
      CreateUsersMigration.name.should eq("CreateUsersMigration")
      AlterUsersMigration.name.should eq("AlterUsersMigration")
    end
  end

  describe "Edge cases and error handling" do
    it "handles down_to with invalid version" do
      migrator.up
      original_count = migrator.applied_migrations.size

      # Non-existent version should not change anything
      migrator.down_to(999999)
      migrator.applied_migrations.size.should eq(original_count)
    end

    it "handles up_to with invalid version" do
      migrator.down
      original_count = migrator.applied_migrations.size

      # Non-existent version should not change anything
      migrator.up_to(999999)
      migrator.applied_migrations.size.should eq(original_count)
    end

    it "handles up_to with already applied version" do
      migrator.up
      original_count = migrator.applied_migrations.size

      # Should not change if already at or past the version
      migrator.up_to(CreateUsersMigration.version)
      migrator.applied_migrations.size.should eq(original_count)
    end

    it "handles database connection errors gracefully" do
      # Test with a bad URI to simulate connection issues
      expect_raises(CQL::Schema::InvalidURIError) do
        CQL::Schema.define(
          :bad_db,
          adapter: CQL::Adapter::SQLite,
          uri: "invalid://bad_uri"
        ) do
          table :test do
            primary :id, Int32
          end
        end
      end
    end
  end
end

describe CQL::MigrationRecord do
  it "creates migration record with all parameters" do
    record = CQL::MigrationRecord.new(
      id: 1,
      name: "test_migration",
      version: 123,
      created_at: Time.local,
      updated_at: Time.local
    )

    record.id.should eq(1)
    record.name.should eq("test_migration")
    record.version.should eq(123)
    record.created_at?.should be_a(Time?)
    record.updated_at?.should be_a(Time?)
  end

  it "creates migration record with default timestamps" do
    record = CQL::MigrationRecord.new(
      id: 1,
      name: "test_migration",
      version: 123
    )

    record.created_at?.should be_a(Time?)
    record.updated_at?.should be_a(Time?)
  end
end

describe CQL::BaseMigration do
  it "requires version to be defined" do
    # Test that version is properly accessible
    CreateUsersMigration.version.should be_a(Int64)
    AlterUsersMigration.version.should be_a(Int64)
  end

  it "implements required abstract methods" do
    # Verify that concrete migration instances can be created and execute
    migration1 = CreateUsersMigration.new(Northwind)
    migration2 = AlterUsersMigration.new(Northwind)

    # These should be callable without errors (actual functionality tested elsewhere)
    migration1.should be_a(CQL::BaseMigration)
    migration2.should be_a(CQL::BaseMigration)
  end

  it "generates correct migration names" do
    # Test the name generation method from BaseMigration
    CreateUsersMigration.name.should be_a(String)
    AlterUsersMigration.name.should be_a(String)
    CreateUsersMigration.name.should_not be_empty
    AlterUsersMigration.name.should_not be_empty
  end
end
