require "../spec_helper"

# The `table :name do ... end` block of *table* in a dump.
private def dumped_table(content : String, table : String) : String
  content[/^  table :#{table} do\n.*?^  end\n/m]
end

describe CQL::SchemaDump do
  describe "SQLite schema dumping" do
    it "can dump a SQLite database schema" do
      UserDB.build # Make sure the database exists

      dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, spec_sqlite_uri("user_db.db"))

      # Generate schema content
      schema_content = dumper.generate_schema_content(:TestDB, :test_db)

      # Verify the content contains expected elements
      schema_content.should contain("CQL::Schema.define")
      schema_content.should contain(":test_db")
      schema_content.should contain("CQL::Adapter::SQLite")
      schema_content.should contain("table :users do")
      schema_content.should contain("primary :id, Int32")
      schema_content.should contain("text :name")
      schema_content.should contain("text :email")
      schema_content.should contain("integer :age")
      schema_content.should contain("timestamps")

      dumper.close
    end

    it "can dump schema to file" do
      UserDB.build # Make sure the database exists

      dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, spec_sqlite_uri("user_db.db"))

      test_file = "spec/support/generated_test_schema.cr"
      dumper.dump_to_file(test_file, :TestSchema, :test_schema)

      # Verify file was created and contains expected content
      File.exists?(test_file).should be_true
      content = File.read(test_file)
      content.should contain("TestSchema = CQL::Schema.define")

      # Clean up
      dumper.close
      File.delete(test_file) if File.exists?(test_file)
    end

    it "handles foreign keys correctly" do
      UserDB.build # Make sure the database exists

      dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, spec_sqlite_uri("user_db.db"))

      schema_content = dumper.generate_schema_content(:TestDB, :test_db)

      # Check that foreign keys are included
      schema_content.should contain("foreign_key")
      schema_content.should contain("references:")

      dumper.close
    end
  end

  describe "type mapping" do
    it "maps SQLite types correctly through schema generation" do
      UserDB.build # Make sure the database exists

      dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, spec_sqlite_uri("user_db.db"))

      schema_content = dumper.generate_schema_content(:TestDB, :test_db)

      # Verify that the generated schema contains the correct column methods
      schema_content.should contain("integer")            # From INTEGER columns
      schema_content.should contain("text")               # From TEXT columns
      schema_content.should contain("primary :id, Int32") # Primary key still shows type

      dumper.close
    end
  end

  it "dumps DATE columns as date and TIMESTAMP columns as timestamp" do
    uri = spec_sqlite_uri("schema_dump_dates.db")
    DB.open(uri) do |db|
      db.exec("DROP TABLE IF EXISTS dated_rows")
      db.exec("CREATE TABLE dated_rows (id INTEGER PRIMARY KEY, born_on DATE NOT NULL, seen_at TIMESTAMP NOT NULL)")
    end
    dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, uri)

    content = dumper.generate_schema_content(:DatesDB, :dates_db)

    content.should contain("date :born_on")
    content.should contain("timestamp :seen_at")
  ensure
    dumper.try(&.close)
  end

  it "dumps on a pool of one connection" do
    uri = spec_sqlite_uri("schema_dump_pool_of_one.db")
    DB.open(uri) do |db|
      db.exec("DROP TABLE IF EXISTS pooled_rows")
      db.exec("CREATE TABLE pooled_rows (id INTEGER PRIMARY KEY, parent_id INTEGER REFERENCES pooled_rows (id))")
    end
    dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, "#{uri}?initial_pool_size=0&max_pool_size=1&checkout_timeout=0.05")

    content = dumper.generate_schema_content(:PooledDB, :pooled_db)

    content.should contain("table :pooled_rows do")
    content.should contain("foreign_key [:parent_id], references: :pooled_rows")
  ensure
    dumper.try(&.close)
  end

  describe "unique constraints" do
    it "writes unique: true for a single-column UNIQUE constraint or unique index on SQLite, and only for it" do
      uri = spec_sqlite_uri("schema_dump_unique_#{Random::Secure.hex(4)}.db")
      DB.open(uri) do |db|
        db.exec("CREATE TABLE unique_rows (id TEXT PRIMARY KEY, email TEXT NOT NULL UNIQUE, code TEXT NOT NULL, " \
                "name TEXT NOT NULL, a TEXT NOT NULL, b TEXT NOT NULL, UNIQUE (a, b))")
        db.exec("CREATE UNIQUE INDEX unique_rows_code ON unique_rows (code)")
        db.exec("CREATE INDEX unique_rows_name ON unique_rows (name)")
      end
      dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, uri)

      table = dumped_table(dumper.generate_schema_content(:UniqueDB, :unique_db), "unique_rows")

      table.should contain("    text :email, unique: true\n")
      table.should contain("    text :code, unique: true\n")
      table.should contain("    primary :id, String\n")
      {"name", "a", "b"}.each { |column| table.should contain("    text :#{column}\n") }
    ensure
      dumper.try(&.close)
      uri.try { |path| File.delete?(path.lchop("sqlite3://")) }
    end

    it "keeps UNIQUE(version) of the migrations table CQL::Migrator creates" do
      schema = spec_sqlite_schema("schema_dump_migrations_#{Random::Secure.hex(4)}.db")
      CQL::Migrator.new(schema)

      content = CQL::SchemaDump.open(schema, &.generate_schema_content(:MigrationsDB, :migrations_db))

      dumped_table(content, "cql_schema_migrations").should contain("    bigint :version, unique: true\n")
    ensure
      schema.try(&.close)
      schema.try { |opened| File.delete?(opened.uri.lchop("sqlite3://")) }
    end

    it "writes unique: true for a single-column UNIQUE constraint on PostgreSQL, and only for it" do
      require_postgres!
      table_name = "schema_dump_unique_#{Random::Secure.hex(4)}"
      DB.open(postgres_database_url) do |db|
        db.exec("CREATE TABLE #{table_name} (id SERIAL PRIMARY KEY, email TEXT NOT NULL UNIQUE, name TEXT NOT NULL, " \
                "a TEXT NOT NULL, b TEXT NOT NULL, UNIQUE (a, b))")
      end
      dumper = CQL::SchemaDump.new(CQL::Adapter::Postgres, postgres_database_url)

      table = dumped_table(dumper.generate_schema_content(:UniqueDB, :unique_db), table_name)

      table.should contain("    text :email, unique: true\n")
      table.should contain("    primary :id, Int32\n")
      {"name", "a", "b"}.each { |column| table.should contain("    text :#{column}\n") }
    ensure
      dumper.try(&.close)
      DB.open(postgres_database_url, &.exec("DROP TABLE IF EXISTS #{table_name}")) if table_name
    end
  end

  describe ".open" do
    it "returns the block's value and closes the dumper's connections" do
      pending!("needs /proc/self/fd") unless FileHandles.supported?
      UserDB.build
      db_file = UserDB.uri.lchop("sqlite3://")
      before = FileHandles.count(db_file)

      content = CQL::SchemaDump.open(UserDB, &.generate_schema_content(:TestDB, :test_db))

      content.should contain("table :users do")
      FileHandles.count(db_file).should eq(before)
    end
  end

  describe "error handling" do
    it "raises error for invalid database connection" do
      expect_raises(CQL::SchemaDump::Error, "Failed to connect to database") do
        CQL::SchemaDump.new(CQL::Adapter::SQLite, "sqlite3://nonexistent/path/database.db")
      end
    end
  end
end
