require "../spec_helper"

# The `table :name do ... end` block of *table* in a dump.
private def dumped_table(content : String, table : String) : String
  content[/^  table :#{table} do\n.*?^  end\n/m]
end

# *name* as a double-quoted SQL identifier.
private def quoted_identifier(name : String) : String
  %("#{name.gsub('"', %(""))}")
end

# Yields a dumper over a fresh SQLite database built by *ddl*, and its URI; deletes the database afterwards.
private def with_sqlite_dump(*ddl : String, &)
  uri = spec_sqlite_uri("schema_dump_#{Random::Secure.hex(4)}.db")
  DB.open(uri) { |db| ddl.each { |sql| db.exec(sql) } }
  dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, uri)
  yield dumper, uri
ensure
  dumper.try(&.close)
  uri.try { |path| File.delete?(path.lchop("sqlite3://")) }
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

    it "omits the foreign key rules SQLite reports as NO ACTION, and writes the others as CQL's symbols" do
      with_sqlite_dump("CREATE TABLE parents (id INTEGER PRIMARY KEY)",
        "CREATE TABLE children (id INTEGER PRIMARY KEY, parent_id INTEGER REFERENCES parents (id), " \
        "owner_id INTEGER REFERENCES parents (id) ON DELETE CASCADE ON UPDATE SET NULL)") do |dumper|
        table = dumped_table(dumper.generate_schema_content(:RulesDB, :rules_db), "children")

        table.should contain("    foreign_key [:parent_id], references: :parents, references_columns: [:id]\n")
        table.should contain("    foreign_key [:owner_id], references: :parents, references_columns: [:id], " \
                             "on_delete: :cascade, on_update: :set_null\n")
      end
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

  describe "the uri: line" do
    it "reads DATABASE_URL and falls back to the URI without its password" do
      require_postgres!
      uri = URI.parse(postgres_database_url)
      uri.query = "sslmode=disable&password=qp_leak"
      dumper = CQL::SchemaDump.new(CQL::Adapter::Postgres, uri.to_s)
      secret = uri.password
      uri.password = nil
      uri.query = "sslmode=disable"

      content = dumper.generate_schema_content(:AppDB, :app_db)

      content.should contain("  uri: ENV.fetch(\"DATABASE_URL\", #{uri.to_s.inspect})) do\n")
      content.should_not contain("qp_leak")
      secret.try { |password| content.should_not contain(":#{password}@") }
    ensure
      dumper.try(&.close)
    end

    it "writes the fallback and the variable name as escaped Crystal string literals" do
      uri = spec_sqlite_uri(%(schema_dump_q"uote_#{Random::Secure.hex(4)}.db))
      dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, uri)

      content = dumper.generate_schema_content(:AppDB, :app_db, env_var: "A\#{x}\"")
      content.should contain("ENV.fetch(#{"A\#{x}\"".inspect}, #{uri.inspect})) do\n")
    ensure
      dumper.try(&.close)
      uri.try { |written| File.delete?(URI.parse(written).path) }
    end

    it "keeps a SQLite URI without credentials as the fallback" do
      dir = File.join(Dir.tempdir, "schema_dump_uri_#{Random::Secure.hex(4)}")
      Dir.mkdir_p(File.join(dir, "db"))
      content = Dir.cd(dir) do
        dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, "sqlite3://./db/app.db")
        dumper.generate_schema_content(:AppDB, :app_db).tap { dumper.close }
      end

      content.should contain("  uri: ENV.fetch(\"DATABASE_URL\", \"sqlite3://./db/app.db\")) do\n")
    ensure
      dir.try { |path| FileUtils.rm_rf(path) }
    end

    it "keeps only known non-secret query parameters in the fallback" do
      base = spec_sqlite_uri("schema_dump_params_#{Random::Secure.hex(4)}.db")
      dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, base + "?sslmode=require&sslpassword=sslpw_leak&Password=pw_leak" \
                                                                "&api_key=key_leak&app.token=token_leak&options=opts_leak&application_name=my%20app")

      content = dumper.generate_schema_content(:AppDB, :app_db)

      content.should contain("  uri: ENV.fetch(\"DATABASE_URL\", #{(base + "?sslmode=require&application_name=my%20app").inspect})) do\n")
      %w[sslpw_leak pw_leak key_leak token_leak opts_leak].each { |secret| content.should_not contain(secret) }
    ensure
      dumper.try(&.close)
      base.try { |written| File.delete?(URI.parse(written).path) }
    end

    it "drops the URL fragment from the fallback" do
      base = spec_sqlite_uri("schema_dump_fragment_#{Random::Secure.hex(4)}.db")
      dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, base + "?sslmode=require#frag_leak")

      content = dumper.generate_schema_content(:AppDB, :app_db)

      content.should contain("  uri: ENV.fetch(\"DATABASE_URL\", #{(base + "?sslmode=require").inspect})) do\n")
      content.should_not contain("frag_leak")
    ensure
      dumper.try(&.close)
      base.try { |written| File.delete?(URI.parse(written).path) }
    end

    it "reads the environment variable dump_to_file is given, DATABASE_URL by default" do
      uri = spec_sqlite_uri("schema_dump_env_#{Random::Secure.hex(4)}.db")
      file = File.join(Dir.tempdir, "schema_dump_env_#{Random::Secure.hex(4)}.cr")
      dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, uri)

      dumper.dump_to_file(file, :AppDB, :app_db, env_var: "ANALYTICS_DATABASE_URL")
      File.read(file).should contain("  uri: ENV.fetch(\"ANALYTICS_DATABASE_URL\", #{uri.inspect})) do\n")
      dumper.dump_to_file(file, :AppDB, :app_db)
      File.read(file).should contain("  uri: ENV.fetch(\"DATABASE_URL\", #{uri.inspect})) do\n")
    ensure
      dumper.try(&.close)
      file.try { |path| File.delete?(path) }
      uri.try { |written| File.delete?(URI.parse(written).path) }
    end
  end

  describe "names read from the database" do
    it "refuses a table name that is not a plain identifier before writing anything, and runs nothing else" do
      table = "x); DROP TABLE decoy; --"
      file = File.join(Dir.tempdir, "schema_dump_decoy_#{Random::Secure.hex(4)}.cr")
      with_sqlite_dump("CREATE TABLE decoy (id INTEGER PRIMARY KEY)",
        "CREATE TABLE #{quoted_identifier(table)} (id INTEGER PRIMARY KEY, decoy_id INTEGER REFERENCES decoy (id))") do |dumper, uri|
        expect_raises(CQL::SchemaDump::Error, table.inspect) { dumper.dump_to_file(file, :DecoyDB, :decoy_db) }

        File.exists?(file).should be_false
        DB.open(uri, &.query_all("SELECT name FROM sqlite_master WHERE name = 'decoy'", as: String)).should eq(["decoy"])
      end
    ensure
      file.try { |path| File.delete?(path) }
    end

    it "refuses a column name that is not a plain identifier, naming the column and its table" do
      column = "note TEXT, injected TEXT)--"
      with_sqlite_dump("CREATE TABLE notes (id INTEGER PRIMARY KEY, #{quoted_identifier(column)} TEXT)") do |dumper|
        error = expect_raises(CQL::SchemaDump::Error, column.inspect) { dumper.generate_schema_content(:NotesDB, :notes_db) }

        error.message.to_s.should contain("notes")
      end
    end

    it "refuses a foreign key whose column, referenced table or referenced column is not a plain identifier" do
      {"my col"            => "%s INTEGER REFERENCES parents (id)",
       "parents (id)); --" => "parent_id INTEGER REFERENCES %s (id)",
       "their col"         => "parent_id INTEGER REFERENCES parents (%s)"}.each do |name, column|
        with_sqlite_dump("CREATE TABLE children (id INTEGER PRIMARY KEY, #{column % quoted_identifier(name)})") do |dumper|
          expect_raises(CQL::SchemaDump::Error, name.inspect) { dumper.generate_schema_content(:ChildrenDB, :children_db) }
        end
      end
    end

    it "writes table and column names in letters of any script as symbols" do
      with_sqlite_dump("CREATE TABLE café (id INTEGER PRIMARY KEY, naïve TEXT NOT NULL)") do |dumper|
        dumper.generate_schema_content(:CafeDB, :cafe_db).should contain("  table :café do\n    primary :id, Int32\n    text :naïve\n")
      end
    end

    it "refuses a PostgreSQL table name that is not a plain identifier" do
      require_postgres!
      table = "t(id int);DROP TABLE decoy;--#{Random::Secure.hex(4)}"
      DB.open(postgres_database_url, &.exec("CREATE TABLE #{quoted_identifier(table)} (id SERIAL PRIMARY KEY)"))
      dumper = CQL::SchemaDump.new(CQL::Adapter::Postgres, postgres_database_url)

      expect_raises(CQL::SchemaDump::Error, table.inspect) { dumper.generate_schema_content(:NamesDB, :names_db) }
    ensure
      dumper.try(&.close)
      table.try { |name| DB.open(postgres_database_url, &.exec("DROP TABLE IF EXISTS #{quoted_identifier(name)}")) }
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
