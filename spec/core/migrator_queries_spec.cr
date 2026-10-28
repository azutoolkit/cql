require "../spec_helper"

# Not `CQL::Migration(V)` subclasses: those register themselves in the global `CQL::Migrator.migrations`.
{% for n in 1..20 %}
  class QueryCountMigration{{n}} < CQL::BaseMigration
    def self.version : Int64
      {{8_000_000 + n}}_i64
    end

    def up; end
    def down; end
  end
{% end %}

private QUERY_COUNT_MIGRATIONS = {% begin %}[{% for n in 1..20 %}QueryCountMigration{{n}}, {% end %}] of CQL::BaseMigration.class{% end %}

# Statements (SELECTs and DDL, where a CREATE TABLE IF NOT EXISTS shows up) of one `pending_migrations` call.
private def pending_statements(registered : Int32, applied : Int32) : Array(String)
  original = CQL::Migrator.migrations
  db_file = File.join(Dir.tempdir, "cql_migrator_queries_#{Process.pid}_#{Random::Secure.hex(4)}.db")
  schema = CQL::Schema.new(:migrator_queries, "sqlite3://#{db_file}", CQL::Adapter::SQLite)
  begin
    CQL::Migrator.migrations = QUERY_COUNT_MIGRATIONS.first(registered)
    migrator = CQL::Migrator.new(schema, CQL::MigratorConfig.new(auto_sync: false))
    migrator.up(applied)
    selects = [] of String
    ddl = count_queries(:ddl) { selects = count_queries { migrator.pending_migrations.size.should eq(registered - applied) } }
    selects + ddl
  ensure
    CQL::Migrator.migrations = original
    schema.close
    File.delete(db_file) if File.exists?(db_file)
  end
end

describe "CQL::Migrator#pending_migrations" do
  it "runs a constant number of statements, none of them DDL, however many migrations are registered" do
    [0, 1].each do |applied|
      one = pending_statements(1, applied)
      many = pending_statements(20, applied)
      one.size.should eq(1)
      many.size.should eq(one.size)
      (one + many).count(&.upcase.starts_with?("CREATE")).should eq(0)
    end
  end
end
