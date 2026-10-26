require "../spec_helper"

private def guard_schema(uri : String, schema_class : CQL::Schema.class = CQL::Schema)
  schema_class.define(:ddl_guard, uri, CQL::Adapter::SQLite) do
    table :ddl_guard_a do
      primary :id, Int32
      text :name
      index [:name]
    end

    table :ddl_guard_b do
      primary :id, Int32
    end
  end
end

describe "CQL schema changes inside a transaction" do
  db_file = File.join(Dir.tempdir, "cql_ddl_guard_#{Process.pid}_#{Random::Secure.hex(4)}.db")
  uri = "sqlite3://#{db_file}"

  # Reads through a separate connection, so it sees only committed state.
  committed_tables = -> do
    DB.open(uri, &.query_all("SELECT name FROM sqlite_master WHERE type = 'table' AND name GLOB 'ddl_guard_*' ORDER BY name", as: String))
  end

  # The SQL the block runs, as Telemetry reports it.
  statements_of = ->(block : ->) do
    statements = [] of String
    CQL::Telemetry.subscribe("ddl_guard_spec") { |event| statements << event.sql }
    begin
      block.call
    ensure
      CQL::Telemetry.unsubscribe("ddl_guard_spec")
    end
    statements
  end

  before_each do
    DB.open(uri) do |db|
      db.query_all("SELECT name FROM sqlite_master WHERE type = 'table' AND (name GLOB 'ddl_guard_*' OR name GLOB 'idx_ddl_guard_*')", as: String)
        .each { |table| db.exec("DROP TABLE IF EXISTS #{table}") }
    end
  end

  after_all do
    ["", "-wal", "-shm", "-journal"].each do |suffix|
      path = db_file + suffix
      File.delete(path) if File.exists?(path)
    end
  end

  describe "without transactional DDL" do
    it "refuses Table#create! before running any DDL" do
      schema = guard_schema(uri, NonTransactionalDdlSchema)

      statements = statements_of.call(-> do
        expect_raises(CQL::DialectError, "MySQL does not support schema changes inside a transaction") do
          schema.transaction { schema.ddl_guard_a.create! }
        end
        nil
      end)

      statements.select(&.includes?("CREATE")).should be_empty
      committed_tables.call.should be_empty
    ensure
      schema.try &.close
    end

    it "refuses Table#drop! before running any DDL" do
      schema = guard_schema(uri, NonTransactionalDdlSchema)
      schema.ddl_guard_a.create!

      statements = statements_of.call(-> do
        expect_raises(CQL::DialectError, "MySQL") { schema.transaction { schema.ddl_guard_a.drop! } }
        nil
      end)

      statements.select(&.includes?("DROP")).should be_empty
      committed_tables.call.should eq(["ddl_guard_a"])
    ensure
      schema.try &.close
    end

    it "refuses Table#truncate! before running any DDL" do
      schema = guard_schema(uri, NonTransactionalDdlSchema)
      schema.ddl_guard_a.create!

      statements = statements_of.call(-> do
        expect_raises(CQL::DialectError, "MySQL") { schema.transaction { schema.ddl_guard_a.truncate! } }
        nil
      end)

      statements.select(&.includes?("ddl_guard_a")).should be_empty
    ensure
      schema.try &.close
    end

    it "refuses Schema#build before running any DDL" do
      schema = guard_schema(uri, NonTransactionalDdlSchema)

      statements = statements_of.call(-> do
        expect_raises(CQL::DialectError, "MySQL") { schema.transaction { schema.build } }
        nil
      end)

      statements.select(&.includes?("CREATE")).should be_empty
      committed_tables.call.should be_empty
    ensure
      schema.try &.close
    end

    it "runs create!, truncate!, drop! and build outside a transaction" do
      schema = guard_schema(uri, NonTransactionalDdlSchema)

      schema.build
      committed_tables.call.should eq(["ddl_guard_a", "ddl_guard_b"])

      schema.ddl_guard_a.truncate!
      schema.ddl_guard_a.drop!
      schema.ddl_guard_b.drop!
      committed_tables.call.should be_empty

      schema.ddl_guard_a.create!
      committed_tables.call.should eq(["ddl_guard_a"])
    ensure
      schema.try &.close
    end
  end

  describe "with transactional DDL" do
    it "rolls back the tables Schema#build created when a later one fails" do
      DB.open(uri) do |db|
        db.exec("CREATE TABLE ddl_guard_seed (id INTEGER)")
        db.exec("CREATE INDEX ddl_guard_b ON ddl_guard_seed (id)") # takes the name the second table needs
      end
      schema = guard_schema(uri)

      expect_raises(Exception, "ddl_guard_b") { schema.build }

      committed_tables.call.should eq(["ddl_guard_seed"])
    ensure
      schema.try &.close
    end

    it "rolls back the table Table#create! created when one of its indexes fails" do
      DB.open(uri, &.exec("CREATE TABLE idx_ddl_guard_a_name (id INTEGER)")) # takes the index's name
      schema = guard_schema(uri)

      expect_raises(Exception, "idx_ddl_guard_a_name") { schema.ddl_guard_a.create! }

      committed_tables.call.should be_empty
    ensure
      schema.try &.close
    end

    it "nests a failing Table#create! in a caller's transaction as a SAVEPOINT that rolls back alone" do
      DB.open(uri, &.exec("CREATE TABLE idx_ddl_guard_a_name (id INTEGER)")) # takes the index's name
      schema = guard_schema(uri)

      schema.transaction do
        expect_raises(Exception, "idx_ddl_guard_a_name") { schema.ddl_guard_a.create! }
        schema.ddl_guard_b.create!
      end

      committed_tables.call.should eq(["ddl_guard_b"])
    ensure
      schema.try &.close
    end

    it "runs create!, truncate! and drop! in a caller's transaction on its single pooled connection" do
      schema = guard_schema("#{uri}?initial_pool_size=0&max_pool_size=1&checkout_timeout=0.05")

      schema.transaction do
        schema.ddl_guard_a.create!
        schema.ddl_guard_b.create!
        schema.ddl_guard_a.truncate!
        schema.ddl_guard_b.drop!
      end

      committed_tables.call.should eq(["ddl_guard_a"])
    ensure
      schema.try &.close
    end
  end
end
