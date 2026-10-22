require "../../support/postgres_spec_support"

# Registered globally, so it is outside the version range of every other spec; the tasks are
# limited to it with `Tasks.migrations`.
class TasksSpecCreateItems < ::CQL::Postgres::Migration(20250101000001_i64)
  def up
    create_table :tasks_spec_items do |t|
      t.string :name
      t.index :name, unique: true
    end
  end

  def down
    drop_table :tasks_spec_items
  end
end

module TasksSpec
  SPEC_DATABASE = "cql_tasks_spec_#{Process.pid}"
  VERSION       = 20250101000001_i64

  # The configured test URL pointed at this spec's own database.
  def self.url(database : String = SPEC_DATABASE) : String
    uri = URI.parse(PostgresSpec.url)
    uri.path = "/#{database}"
    uri.to_s
  end

  def self.use(url : String) : Nil
    ::CQL::Postgres.config.url = url
    ::CQL::Postgres::Database.schema = nil
  end

  def self.table?(name : String) : Bool
    ::CQL::Postgres::Database.schema.raw_readonly("SELECT to_regclass('#{name}') IS NOT NULL", 1)[1].first.first == "true"
  end

  def self.run(*args : String) : {Int32, String, String}
    stdout = IO::Memory.new
    stderr = IO::Memory.new
    code = ::CQL::Postgres::Database::Tasks.run(args.to_a, stdout, stderr, quiet: false)
    {code, stdout.to_s, stderr.to_s}
  end
end

describe ::CQL::Postgres::Database::Tasks do
  original_url = ::CQL::Postgres.config.url

  before_all { ::CQL::Postgres::Database::Tasks.migrations = [TasksSpecCreateItems] of ::CQL::Postgres::BaseMigration.class }

  after_all do
    ::CQL::Postgres::Database::Tasks.migrations = nil
    if PostgresSpec.available?
      ::CQL::Postgres::Database::Tasks.drop(TasksSpec.url, force: true)
      TasksSpec.use(PostgresSpec.url)
    end
    ::CQL::Postgres.config.url = original_url
  end

  describe ".target" do
    it "splits a URL into pg_dump / psql arguments" do
      target = ::CQL::Postgres::Database::Tasks.target("postgres://app:p%40ss@db.example:5433/shop?sslmode=require&max_pool_size=5")
      target.database.should eq "shop"
      target.cli_args.should eq ["-h", "db.example", "-p", "5433", "-U", "app"]
      target.env.should eq({"PGPASSWORD" => "p@ss", "PGSSLMODE" => "require"})
    end

    it "needs a database name" do
      expect_raises(::CQL::Postgres::Database::Tasks::Error, /no database name/) { ::CQL::Postgres::Database::Tasks.target("postgres://localhost") }
    end
  end

  describe ".run" do
    it "prints usage and reports unknown commands" do
      code, stdout, _ = TasksSpec.run("help")
      code.should eq 0
      stdout.should contain "migrate"
      stdout.should contain "structure:dump"

      code, _, stderr = TasksSpec.run("frobnicate")
      code.should eq 2
      stderr.should contain %(unknown command "frobnicate")
    end

    it "rejects a non-numeric version without touching the database" do
      code, _, stderr = TasksSpec.run("migrate", "soon")
      code.should eq 1
      stderr.should contain "VERSION must be a number"
    end
  end

  describe "database lifecycle and migrations" do
    it "creates, migrates, reports status, rolls back and drops" do
      PostgresSpec.require!
      ::CQL::Postgres::Database::Tasks.drop(TasksSpec.url, force: true)
      ::CQL::Postgres::Database::Tasks.exists?(TasksSpec.url).should be_false

      ::CQL::Postgres::Database::Tasks.create(TasksSpec.url).should be_true
      ::CQL::Postgres::Database::Tasks.create(TasksSpec.url).should be_false
      ::CQL::Postgres::Database::Tasks.exists?(TasksSpec.url).should be_true

      TasksSpec.use(TasksSpec.url)
      code, stdout, _ = TasksSpec.run("status")
      stdout.should contain "down"

      code, stdout, _ = TasksSpec.run("migrate")
      code.should eq 0
      stdout.should contain "migrated 20250101000001 TasksSpecCreateItems"
      TasksSpec.table?("tasks_spec_items").should be_true
      TasksSpec.run("migrate")[1].should contain "Nothing to migrate"
      TasksSpec.run("version")[1].strip.should eq TasksSpec::VERSION.to_s
      TasksSpec.run("status")[1].should match(/up\s+20250101000001/)

      code, stdout, _ = TasksSpec.run("rollback")
      stdout.should contain "reverted 20250101000001"
      TasksSpec.table?("tasks_spec_items").should be_false
      TasksSpec.run("rollback")[1].should contain "Nothing to roll back"

      code, stdout, _ = TasksSpec.run("migrate", "--dry-run")
      stdout.should contain "dry run"
      stdout.should contain %(CREATE TABLE "tasks_spec_items")
      TasksSpec.table?("tasks_spec_items").should be_false

      TasksSpec.run("migrate")
      TasksSpec.run("redo")[1].should contain "Reverted 1 and re-applied 1"
      TasksSpec.table?("tasks_spec_items").should be_true

      ::CQL::Postgres::Database.schema = nil # drop terminates this process's own sessions
      ::CQL::Postgres::Database::Tasks.drop(TasksSpec.url, force: true).should be_true
      ::CQL::Postgres::Database::Tasks.exists?(TasksSpec.url).should be_false
    end

    it "runs seeds registered with ::CQL::Postgres::Database.seed" do
      PostgresSpec.require!
      ::CQL::Postgres::Database.clear_seeds
      seeded = [] of Int32
      ::CQL::Postgres::Database.seed { seeded << 1 }
      ::CQL::Postgres::Database.seed { seeded << 2 }
      begin
        TasksSpec.run("seed")[1].should contain "Ran 2 seed block(s)"
        seeded.should eq [1, 2]
      ensure
        ::CQL::Postgres::Database.clear_seeds
      end
      TasksSpec.run("seed")[1].should contain "No seeds registered"
    end

    it "sets up and resets a database in one step" do
      PostgresSpec.require!
      ::CQL::Postgres::Database.clear_seeds
      count = 0
      ::CQL::Postgres::Database.seed { count += 1 }
      TasksSpec.use(TasksSpec.url("cql_tasks_spec_setup_#{Process.pid}"))
      begin
        stdout = IO::Memory.new
        ::CQL::Postgres::Database::Tasks.setup(stdout)
        stdout.to_s.should contain "Created database"
        stdout.to_s.should contain "migrated 20250101000001"
        count.should eq 1

        ::CQL::Postgres::Database.schema = nil
        stdout = IO::Memory.new
        ::CQL::Postgres::Database::Tasks.reset(stdout, force: true)
        stdout.to_s.should contain "Dropped database"
        stdout.to_s.should contain "migrated 20250101000001"
        count.should eq 2
      ensure
        ::CQL::Postgres::Database.clear_seeds
        ::CQL::Postgres::Database.schema = nil
        ::CQL::Postgres::Database::Tasks.drop(::CQL::Postgres::Database.url, force: true)
      end
    end

    it "refuses to drop in production without --force" do
      PostgresSpec.require!
      ::CQL::Postgres::Database::Tasks.create(TasksSpec.url)
      with_postgres_env(::CQL::Postgres::Environment::Production) do
        expect_raises(::CQL::Postgres::Database::Tasks::Error, /refusing to drop/) { ::CQL::Postgres::Database::Tasks.drop(TasksSpec.url) }
        TasksSpec.run("drop")[0].should eq 1
      end
      ::CQL::Postgres::Database::Tasks.exists?(TasksSpec.url).should be_true
      ::CQL::Postgres::Database::Tasks.drop(TasksSpec.url, force: true)
    end

    it "explains an unreachable server" do
      expect_raises(::CQL::Postgres::Database::Tasks::Error, /cannot reach the PostgreSQL server/) do
        ::CQL::Postgres::Database::Tasks.exists?("postgres://postgres@127.0.0.1:1/nope")
      end
    end
  end

  describe "structure dump and load" do
    it "round-trips the schema and the applied migration versions" do
      PostgresSpec.require!
      pending!("pg_dump / psql not installed") unless Process.find_executable("pg_dump") && Process.find_executable("psql")

      ::CQL::Postgres::Database::Tasks.drop(TasksSpec.url, force: true)
      ::CQL::Postgres::Database::Tasks.create(TasksSpec.url)
      TasksSpec.use(TasksSpec.url)
      ::CQL::Postgres::Database::Tasks.migrate(io: IO::Memory.new)

      path = File.join(Dir.tempdir, "cql_structure_#{Process.pid}.sql")
      begin
        ::CQL::Postgres::Database::Tasks.structure_dump(path, io: IO::Memory.new)
        sql = File.read(path)
        sql.should contain "CREATE TABLE public.tasks_spec_items"
        sql.should contain "CREATE UNIQUE INDEX index_tasks_spec_items_on_name"
        sql.should contain %(INSERT INTO public."schema_migrations" (version, name) VALUES (20250101000001, 'TasksSpecCreateItems'))

        ::CQL::Postgres::Database.schema = nil
        ::CQL::Postgres::Database::Tasks.drop(TasksSpec.url, force: true)
        ::CQL::Postgres::Database::Tasks.create(TasksSpec.url)
        ::CQL::Postgres::Database::Tasks.structure_load(path, io: IO::Memory.new)

        TasksSpec.use(TasksSpec.url)
        TasksSpec.table?("tasks_spec_items").should be_true
        ::CQL::Postgres::Migrator.new(migrations: [TasksSpecCreateItems] of ::CQL::Postgres::BaseMigration.class).pending.should be_empty
      ensure
        File.delete?(path)
      end
    end

    it "fails clearly when the structure file is missing" do
      PostgresSpec.require!
      pending!("psql not installed") unless Process.find_executable("psql")
      expect_raises(::CQL::Postgres::Database::Tasks::Error, /does not exist/) do
        ::CQL::Postgres::Database::Tasks.structure_load("/nonexistent/structure.sql", TasksSpec.url)
      end
    end
  end

  describe "analyze" do
    it "prints the health report" do
      PostgresSpec.require!
      ::CQL::Postgres::Database::Tasks.create(TasksSpec.url)
      TasksSpec.use(TasksSpec.url)
      stdout = IO::Memory.new
      ::CQL::Postgres::Database::Tasks.analyze(refresh: true, io: stdout)
      stdout.to_s.should contain "Largest tables"
      stdout.to_s.should contain "Buffer cache hit ratio"
      stdout.to_s.should contain "ANALYZE completed"
      ::CQL::Postgres::Database.schema = nil
      ::CQL::Postgres::Database::Tasks.drop(TasksSpec.url, force: true)
    end
  end
end
