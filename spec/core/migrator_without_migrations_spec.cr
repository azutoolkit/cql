require "../spec_helper"

describe "CQL::Migrator in an application that defines no migrations" do
  it "compiles and runs migrator.up and migrator.down" do
    success, output, error = Snippets.run <<-'CRYSTAL'
      require "./src/cql"
      require "sqlite3"

      db_file = File.tempname("cql_no_migrations", ".db")
      schema = CQL::Schema.new(:no_migrations, "sqlite3://#{db_file}", CQL::Adapter::SQLite)
      begin
        migrator = CQL::Migrator.new(schema, CQL::MigratorConfig.new(auto_sync: false))
        migrator.up
        migrator.down
        puts "applied: #{migrator.applied_migrations.size}"
      ensure
        schema.close
        File.delete(db_file) if File.exists?(db_file)
      end
      CRYSTAL

    fail error unless success
    output.should contain("applied: 0")
  end
end
