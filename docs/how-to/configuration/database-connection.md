# Configure Database Connection

This guide shows you how to configure your database connection in CQL.

## Basic PostgreSQL Connection

```crystal
require "cql"
require "pg"

MyDB = CQL::Schema.define(
  :my_db,
  adapter: CQL::Adapter::Postgres,
  uri: "postgres://username:password@localhost:5432/myapp_development"
) do
end

MyDB.init
```

## Basic SQLite Connection

```crystal
require "cql"
require "sqlite3"

MyDB = CQL::Schema.define(
  :my_db,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://./db/development.db"
) do
end

MyDB.init
```

## Basic MySQL Connection

```crystal
require "cql"
require "mysql"

MyDB = CQL::Schema.define(
  :my_db,
  adapter: CQL::Adapter::MySql,
  uri: "mysql://username:password@localhost:3306/myapp_development"
) do
end

MyDB.init
```

## Use Environment Variables

```crystal
DATABASE_URL = ENV["DATABASE_URL"]? || "postgres://localhost/myapp_development"

MyDB = CQL::Schema.define(
  :my_db,
  adapter: CQL::Adapter::Postgres,
  uri: DATABASE_URL
) do
end
```

## Connection String Format

### PostgreSQL

```
postgres://username:password@host:port/database
postgres://user:pass@localhost:5432/myapp
postgres://localhost/myapp  # Uses default user and port
```

### MySQL

```
mysql://username:password@host:port/database
mysql://user:pass@localhost:3306/myapp
```

### SQLite

```
sqlite3://path/to/database.db
sqlite3://./db/development.db
sqlite3://:memory:  # In-memory database
```

## Test Connection

```crystal
begin
  MyDB.init
  puts "Connected successfully"
rescue ex
  puts "Connection failed: #{ex.message}"
  exit 1
end
```

## Connection with Options (PostgreSQL)

```crystal
MyDB = CQL::Schema.define(
  :my_db,
  adapter: CQL::Adapter::Postgres,
  uri: "postgres://user:pass@localhost:5432/myapp?sslmode=require"
) do
end
```

## Create Database Directory (SQLite)

```crystal
db_path = "./db/development.db"
Dir.mkdir_p(File.dirname(db_path)) unless Dir.exists?(File.dirname(db_path))

MyDB = CQL::Schema.define(
  :my_db,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://#{db_path}"
) do
end
```

## Multiple Databases

```crystal
PrimaryDB = CQL::Schema.define(
  :primary,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["PRIMARY_DATABASE_URL"]
) do
end

AnalyticsDB = CQL::Schema.define(
  :analytics,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["ANALYTICS_DATABASE_URL"]
) do
end

# Use different schemas for different models
struct User
  db_context PrimaryDB, :users
end

struct PageView
  db_context AnalyticsDB, :page_views
end
```

## Verify Connection

```crystal
MyDB.init

# Run a simple query
MyDB.exec("SELECT 1")
puts "Database connection verified"
```

## Related

- [Configure Multiple Environments](environments.md)
- [Set Up Connection Pooling](connection-pooling.md)
- [Enable SSL Connections](ssl.md)
