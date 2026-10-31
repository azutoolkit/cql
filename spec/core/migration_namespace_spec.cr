require "../spec_helper"

module NamespaceMigrationSpec
  {% for name in ["A", "B"] %}
    module {{name.id}}
      class One < CQL::BaseMigration
        def self.version : Int64
          1_i64
        end
        def up
          schema.exec("CREATE TABLE namespace_{{name.downcase.id}} (id INTEGER)")
        end
        def down
          schema.exec("DROP TABLE namespace_{{name.downcase.id}}")
        end
      end
    end
  {% end %}

  def self.with_schema(&)
    previous = CQL::Migrator.migrations
    CQL::Migrator.migrations = [A::One, B::One] of CQL::BaseMigration.class
    path = File.tempname("cql_namespace", ".db")
    schema = CQL::Schema.new(:namespace_test, "sqlite3://#{path}", CQL::Adapter::SQLite)
    yield schema
  ensure
    CQL::Migrator.migrations = previous if previous
    schema.try(&.close)
    File.delete?(path) if path
  end
end

describe "migration namespaces" do
  it "scopes duplicate checks, targets, history and reviewed execution to each ledger" do
    NamespaceMigrationSpec.with_schema do |schema|
      ca = CQL::MigratorConfig.new(auto_sync: false, migration_namespace: "NamespaceMigrationSpec::A", migration_table_name: :ledger_a)
      cb = CQL::MigratorConfig.new(auto_sync: false, migration_namespace: "NamespaceMigrationSpec::B::", migration_table_name: :ledger_b)
      CQL::Migrator.ready?(schema, ca).should be_false
      a, b = CQL::Migrator.new(schema, ca), CQL::Migrator.new(schema, cb)
      a.up_to(1)
      a.last.should eq(NamespaceMigrationSpec::A::One)
      b.pending_migrations.should eq([NamespaceMigrationSpec::B::One])
      b.apply_reviewed([] of Int64, [1_i64])
      CQL::Migrator.ready?(schema, ca).should be_true
      CQL::Migrator.ready?(schema, cb).should be_true
      a.down
      b.applied_migrations.size.should eq(1)
      a.redo
      a.applied_migrations.size.should eq(1)
      b.apply_reviewed([1_i64], [] of Int64, 1_i64)
      b.applied_migrations.should be_empty
    end
  end

  it "rejects a foreign version before running any migration body" do
    NamespaceMigrationSpec.with_schema do |schema|
      a = CQL::Migrator.new(schema, CQL::MigratorConfig.new(auto_sync: false, migration_namespace: "NamespaceMigrationSpec::A"))
      b = CQL::Migrator.new(schema, CQL::MigratorConfig.new(auto_sync: false, migration_namespace: "NamespaceMigrationSpec::B"))
      a.up
      expect_raises(CQL::Migrator::Error, "separate migration_table_name") { b.up }
      schema.exec_query(&.query_one("SELECT count(*) FROM sqlite_master WHERE name='namespace_b'", as: Int64)).should eq(0)
      b.applied_migrations.should be_empty
    end
  end

  it "matches module boundaries and validates even an empty registry" do
    config = CQL::MigratorConfig.new(migration_namespace: "App_Name::Migrations::")
    config.includes_migration?("App_Name::Migrations::One").should be_true
    config.includes_migration?("App_Name::MigrationsExtra::One").should be_false
    expect_raises(ArgumentError) { CQL::MigratorConfig.new(migration_namespace: " ").namespace_prefix }
  end
end

describe "namespace history validation" do
  it "retains missing-source history and checks reviewed preconditions" do
    NamespaceMigrationSpec.with_schema do |schema|
      config = CQL::MigratorConfig.new(auto_sync: false, migration_namespace: "NamespaceMigrationSpec::A")
      migrator = CQL::Migrator.new(schema, config)
      migrator.up
      schema.exec("INSERT INTO cql_schema_migrations (name,version) VALUES ('NamespaceMigrationSpec::A::Missing', 2)")
      migrator.applied_migrations.map(&.version).sort!.should eq([1_i64, 2_i64])
      migrator.last.should be_nil
      expect_raises(CQL::Migrator::Error, "state changed") do
        migrator.apply_reviewed([1_i64], [] of Int64)
      end
      expect_raises(CQL::Migrator::Error, "source is missing") do
        migrator.apply_reviewed([1_i64, 2_i64], [] of Int64, 2_i64)
      end
      migrator.applied_migrations.size.should eq(2)
    end
  end

  it "revalidates dynamically registered duplicates within the selected namespace" do
    NamespaceMigrationSpec.with_schema do |schema|
      config = CQL::MigratorConfig.new(auto_sync: false, migration_namespace: "NamespaceMigrationSpec::A")
      migrator = CQL::Migrator.new(schema, config)
      CQL::Migrator.migrations << NamespaceMigrationSpec::A::One
      expect_raises(CQL::Migrator::Error, "share version") { migrator.up }
      expect_raises(CQL::Migrator::Error, "Duplicate migration") { CQL::Migrator.ready?(schema, config) }
      migrator.applied_migrations.should be_empty
    end
  end
end
