# Set Up Test Databases

Configure a separate database for running tests without affecting development data.

## Prerequisites

- CQL installed
- Database server running
- Test framework configured

## Create Test Database

### PostgreSQL

```bash
createdb myapp_test
```

### MySQL

```bash
mysql -e "CREATE DATABASE myapp_test"
```

### SQLite

SQLite creates the file automatically; use a separate path.

## Configure Test Environment

Create a test configuration:

```crystal
# src/config/database.cr
module Config
  def self.database_url
    case ENV["APP_ENV"]?
    when "test"
      ENV["TEST_DATABASE_URL"]? || "postgres://localhost/myapp_test"
    when "production"
      ENV["DATABASE_URL"]
    else
      ENV["DATABASE_URL"]? || "postgres://localhost/myapp_development"
    end
  end
end

# src/db.cr
MyDB = CQL::Schema.define(
  :my_db,
  adapter: CQL::Adapter::Postgres,
  uri: Config.database_url
) do
end
```

## Environment Variables

Set test database URL:

```bash
# .env.test
TEST_DATABASE_URL=postgres://localhost/myapp_test

# Run tests
APP_ENV=test crystal spec
```

Or in your test helper:

```crystal
# spec/spec_helper.cr
ENV["APP_ENV"] = "test"
ENV["TEST_DATABASE_URL"] = "postgres://localhost/myapp_test"

require "../src/db"
require "../src/models/*"
```

## Run Migrations for Tests

Before running tests, migrate the test database. Turn `auto_sync` off so the migrator does not rewrite your schema file:

```crystal
# spec/spec_helper.cr
ENV["APP_ENV"] = "test"
require "../src/db"

# Run migrations
MyDB.migrator(CQL::MigratorConfig.new(auto_sync: false)).up
```

If the schema is declared in code (as in CQL's own specs), you can skip migrations and create every declared table with `MyDB.build`, or one at a time with `MyDB.users.create!` and `MyDB.users.drop!`.

Or with a script:

```bash
#!/bin/bash
# bin/test (src/migrate.cr calls MyDB.migrator(...).up)
APP_ENV=test crystal run src/migrate.cr
APP_ENV=test crystal spec "$@"
```

## Database Cleaning Strategies

### Truncation (Recommended)

Fast cleanup by truncating tables:

```crystal
# spec/spec_helper.cr
Spec.before_each do
  # PostgreSQL
  MyDB.exec(<<-SQL
    TRUNCATE users, posts, comments
    RESTART IDENTITY CASCADE
  SQL
  )

  # MySQL
  # MyDB.exec("SET FOREIGN_KEY_CHECKS = 0")
  # MyDB.exec("TRUNCATE users")
  # MyDB.exec("SET FOREIGN_KEY_CHECKS = 1")

  # SQLite
  # MyDB.exec("DELETE FROM users")
  # MyDB.exec("DELETE FROM sqlite_sequence WHERE name='users'")
end
```

### Transaction Rollback

Wrap each test in a transaction that rolls back:

```crystal
Spec.around_each do |example|
  MyDB.transaction do
    example.run
    raise DB::Rollback.new
  end
end
```

`Schema#transaction` pins the fiber to one connection and swallows `DB::Rollback`, so queries issued by the example run inside the transaction.

**Note:** This won't work if your tests use multiple connections or spawn fibers, because other fibers do not see the transaction's connection.

### Delete Strategy

Slower but compatible with all scenarios:

```crystal
Spec.after_each do
  Comment.delete_all
  Post.delete_all
  User.delete_all
end
```

## In-Memory SQLite

For fastest tests, use in-memory SQLite:

```crystal
# spec/spec_helper.cr
TestDB = CQL::Schema.define(
  :test_db,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3::memory:"
) do
  table :users do
    primary :id, Int64
    column :name, String
    column :email, String
    timestamps
  end
end

Spec.before_suite do
  # Create the declared tables
  TestDB.build
end
```

SQLite gives every connection its own private `:memory:` database, so a test that ends up on a second pooled connection can see an empty database. CQL's own specs use SQLite files in the temp directory instead (`CQL::Schema.define(:name, adapter: CQL::Adapter::SQLite, uri: "sqlite3://#{File.join(Dir.tempdir, "cql_test.db")}")`) and create and drop tables around each example with `TestDB.users.create!` / `TestDB.users.drop!`.

## Separate Test Schema

Use a dedicated schema module for tests:

```crystal
# spec/support/test_schema.cr
TestDB = CQL::Schema.define(:test, adapter: CQL::Adapter::SQLite, uri: "sqlite3::memory:") do
  table :users do
    primary :id, Int64
    column :name, String
    column :email, String
    timestamps
  end
end

# Redefine models to use test database
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context TestDB, :users
  # ... properties
end
```

## Parallel Tests

For parallel test execution, use separate databases:

```crystal
worker_id = ENV["TEST_WORKER_ID"]? || "0"
test_db = "myapp_test_#{worker_id}"

TestDB = CQL::Schema.define(:test, adapter: CQL::Adapter::Postgres, uri: "postgres://localhost/#{test_db}") do
end
```

## Verify Setup

```crystal
# spec/database_spec.cr
describe "Database" do
  it "connects to test database" do
    MyDB.exec_query { |conn| conn.scalar("SELECT 1") }.should eq(1)
  end

  it "has migrated schema" do
    User.count.should eq(0)  # Table exists
  end
end
```

## See Also

- [Test Models](test-models.md)
- [Configure Multiple Environments](../configuration/environments.md)
- [Run Migrations](../migrations/run-migrations.md)
