# Configure Database Connection

This guide shows you how to configure your database connection in CQL.

## Basic PostgreSQL Connection

```crystal
require "cql"

MyDB = CQL::Schema.define(
  :my_db,
  adapter: CQL::Adapter::Postgres,
  uri: "postgres://username:password@localhost:5432/myapp_development"
) do
end
```

`postgres://` and `postgresql://` URLs are opened by CQL's native PostgreSQL driver, so no `pg` shard is needed. If you `require "pg"` before CQL, the `pg` shard keeps those scheme names instead. See the [native PostgreSQL driver guide](../postgres-native/README.md).

## Basic CockroachDB Connection

```crystal
MyDB = CQL::Schema.define(
  :my_db,
  adapter: CQL::Adapter::CockroachDB,
  uri: "cockroachdb://root@localhost:26257/defaultdb?sslmode=disable"
) do
end
```

`cockroachdb://` is rewritten to `postgres://` for crystal-db. Using the native driver for it is opt-in: compile with `-Dcql_postgres_driver_cockroachdb` or call `CQL::Postgres::Driver.register_cockroachdb`. See [CockroachDB](cockroachdb.md).

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

### CockroachDB

```
cockroachdb://user@host:26257/database
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

`Schema.define` validates the URI (`CQL::Schema::InvalidURIError`) and opens the pool. Run a query to confirm the database answers:

```crystal
begin
  MyDB.exec_query(&.scalar("SELECT 1"))
  puts "Connected successfully"
rescue ex
  puts "Connection failed: #{ex.message}"
  exit 1
end
```

## Connection with Options (PostgreSQL)

Recognised query parameters configure the driver (`sslmode`, `connect_timeout`, `application_name`, `statement_cache_size`, pool settings); any other key is sent to the server as a startup parameter such as `search_path`. See [Enable SSL Connections](ssl.md) and [Set Up Connection Pooling](connection-pooling.md).

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
class User
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: PrimaryDB, table: :users
end

class PageView
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: AnalyticsDB, table: :page_views
end
```

## Verify Connection

```crystal
# Run a simple query
MyDB.exec_query(&.scalar("SELECT 1"))
puts "Database connection verified"
```

## Global Configuration

`CQL.configure` holds the URL, environment, pool and SSL settings in one place (`config.db`, `config.env`, `config.pool_size`, `config.ssl.mode`). The adapter is detected from the URL scheme (`postgres://`, `postgresql://`, `cockroachdb://`, `mysql://`, `sqlite3://`):

```crystal
CQL.configure do |config|
  config.db = ENV["DATABASE_URL"]
end

MyDB = CQL.build_schema(:my_db) do
end
```

## Related

- [Configure Multiple Environments](environments.md)
- [Set Up Connection Pooling](connection-pooling.md)
- [Enable SSL Connections](ssl.md)
