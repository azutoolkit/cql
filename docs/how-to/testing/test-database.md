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

Before running tests, migrate the test database:

```crystal
# spec/spec_helper.cr
ENV["APP_ENV"] = "test"
require "../src/db"

# Run migrations
MyDB.migrator.up
```

Or with a script:

```bash
#!/bin/bash
# bin/test
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

**Note:** This won't work if your tests use multiple connections or spawn fibers.

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
  uri: "sqlite3://:memory:"
) do
end

Spec.before_suite do
  # Run migrations on in-memory database
  TestDB.migrator.up
end
```

## Separate Test Schema

Use a dedicated schema module for tests:

```crystal
# spec/support/test_schema.cr
TestDB = CQL::Schema.define(:test, adapter: CQL::Adapter::SQLite, uri: "sqlite3://:memory:") do
  table :users do
    primary_key :id, Int64
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
    MyDB.exec("SELECT 1").should_not be_nil
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
