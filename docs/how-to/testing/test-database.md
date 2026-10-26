# Set Up Test Databases

Point CQL at a separate database for specs, create its tables, and clean it between examples.

## Create the Database

```bash
createdb myapp_test                     # PostgreSQL
mysql -e "CREATE DATABASE myapp_test"   # MySQL
# SQLite creates the file on the first connection
```

## Choose the URL by Environment

```crystal
# src/config/database.cr
module Config
  def self.database_url : String
    case ENV["APP_ENV"]?
    when "test"       then ENV["TEST_DATABASE_URL"]? || "postgres://localhost/myapp_test"
    when "production" then ENV["DATABASE_URL"]
    else                   ENV["DATABASE_URL"]? || "postgres://localhost/myapp_development"
    end
  end
end

# src/db.cr
AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::Postgres, uri: Config.database_url) do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String
    column :email, String
    timestamps
  end
end
```

```crystal
# spec/spec_helper.cr
ENV["APP_ENV"] = "test"   # before the schema is defined
require "spec"
require "../src/db"
require "../src/models/*"
```

Models compile against one schema constant, so switch databases through the URL rather than redefining models.

## Create the Tables

```crystal
# spec/spec_helper.cr: run the migrations, leaving the schema file alone
AppDB.migrator(CQL::MigratorConfig.new(auto_sync: false)).up

# Or, when the schema declares the tables in code
AppDB.build             # CREATE TABLE IF NOT EXISTS ... and its indexes, for every declared table
AppDB.users.create!     # one table
AppDB.users.drop!       # DROP TABLE IF EXISTS users
```

```bash
APP_ENV=test crystal src/migrate.cr up && APP_ENV=test crystal spec
```

## Roll Back Each Example

```crystal
Spec.around_each do |example|
  AppDB.transaction do
    example.run
    raise DB::Rollback.new   # nothing the example wrote survives
  end
end
```

Every query the example runs on its own fiber joins that transaction. A fiber the example spawns gets another
connection: it does not see the example's rows, and its writes are not rolled back. On MySQL and CockroachDB, DDL
inside the example raises `CQL::DialectError`.

## Empty the Tables

```crystal
Spec.before_each do
  AppDB.comments.truncate!   # SQLite: DELETE FROM comments; PostgreSQL and MySQL: TRUNCATE TABLE comments
  AppDB.posts.truncate!
  AppDB.users.truncate!
  AppDB.exec("DELETE FROM sqlite_sequence")  # SQLite: restart AUTOINCREMENT ids
end

# PostgreSQL: one statement, past foreign keys, with ids restarted
AppDB.exec("TRUNCATE users, posts, comments RESTART IDENTITY CASCADE")

# Through the models: one DELETE per table, no callbacks
Comment.delete_all
Post.delete_all
User.delete_all
```

## Use SQLite Files, Not :memory:

```crystal
# ❌ Every connection gets its own empty :memory: database
TestDB = CQL::Schema.define(:test_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3::memory:") do
  # ...
end
# a second pooled connection (a spawned fiber, for one) -> no such table: users

# ✅ A file in the temp directory, as CQL's own specs do
TestDB = CQL::Schema.define(:test_db, adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://#{File.join(Dir.tempdir, "myapp_test.db")}") do
  # ...
end
```

For parallel CI jobs, give each job its own database before the schema is defined:

```crystal
ENV["TEST_DATABASE_URL"] = "postgres://localhost/myapp_test_#{ENV["TEST_WORKER_ID"]? || "0"}"
```

## Check the Setup

```crystal
describe "database" do
  it "connects to the test database" do
    AppDB.exec_query { |conn| conn.scalar("SELECT 1") }.should eq(1)
  end

  it "has the migrated tables" do
    User.count.should eq(0)
  end
end
```

## See Also

- [Test Models](test-models.md)
- [Configure Multiple Environments](../configuration/environments.md)
- [Run Migrations](../migrations/run-migrations.md)
- [Use Transactions](../data-operations/transactions.md)
