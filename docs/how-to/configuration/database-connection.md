# Configure Database Connection

`CQL.configure` is the entrypoint for connection settings: one configuration object holds the URL, environment, pool, SSL and database-specific options, and `CQL.build_schema` opens the connection from it. `CQL::Schema.define` is the low-level alternative, covered [below](#low-level-schemadefine).

For the lifecycle (when settings are read, reset, validation) see [Configure CQL](configure-cql.md). Every setting is listed in the [configuration reference](../../reference/configuration.md).

## Connect with `CQL.configure`

```crystal
require "cql"
require "sqlite3"

CQL.configure do |config|
  config.db = "sqlite3://./db/development.db"
end

MyDB = CQL.build_schema(:my_db) do
  table :users do
    primary :id, Int64
    text :name
  end
end
```

`CQL.build_schema` opens the schema through `config.full_db_url`, runs the block with the schema DSL, then sets up the cache and SQL logging when the configuration enables them. Pool, SSL, database-specific and `adapter_options` settings therefore reach the connection. Parameters already in `config.db` win over configured ones.

`config.db` defaults to `sqlite3://./db/development.db`.

### The adapter comes from the URL

`config.adapter` is detected from the URL scheme:

| Scheme | Adapter |
|--------|---------|
| `postgres://`, `postgresql://` | `CQL::Adapter::Postgres` |
| `cockroachdb://` | `CQL::Adapter::CockroachDB` |
| `mysql://` | `CQL::Adapter::MySql` |
| `sqlite3://` | `CQL::Adapter::SQLite` |

Any other scheme raises `ArgumentError` ("Unsupported database URL").

### Read `DATABASE_URL` yourself

CQL does not read `DATABASE_URL`. Pass it in:

```crystal
CQL.configure do |config|
  config.db = ENV["DATABASE_URL"]? || "postgres://localhost/myapp_development"
end
```

### What `full_db_url` adds

```crystal
CQL.configure do |config|
  config.db = ENV["DATABASE_URL"]
  config.pool_size = 25                        # see connection-pooling.md
  config.ssl.mode = "require"                  # see ssl.md
  config.postgres.auth_methods = "scram-sha-256"
  config.adapter_options["application_name"] = "billing"
end

puts CQL.config.full_db_url
```

`full_db_url` appends, in this order: pool parameters, SSL parameters (PostgreSQL, CockroachDB and MySQL only), the database-specific settings, then `adapter_options`. The database-specific settings follow the adapter:

| Adapter | Settings object | Settings (default) |
|---------|-----------------|--------------------|
| Postgres, CockroachDB | `config.postgres` | `auth_methods` (`scram-sha-256,md5`) |
| MySql | `config.mysql` | `encoding` (`utf8mb4_unicode_ci`) |
| SQLite | `config.sqlite` | `journal_mode` (`wal`), `synchronous` (`normal`), `cache_size` (`-4000`), `foreign_keys` (`true`), `busy_timeout` (`5000`) |

`adapter_options` is a `Hash(String, String)` of extra URL parameters, added as given. Each driver decides what to do with a parameter it does not know. The native PostgreSQL driver sends unrecognised keys to the server as startup parameters, so only add keys the server understands. It accepts and ignores `auth_methods` (the option `config.postgres.auth_methods` adds for the `pg` shard) because it negotiates SCRAM and MD5 itself.

`CQL.configure` validates the settings and raises `ArgumentError` on a bad value, for example an unknown `sqlite.journal_mode`.

### URL parameters

Recognised query parameters configure the driver (`sslmode`, `connect_timeout`, `application_name`, `statement_cache_size`, pool settings); with the native PostgreSQL driver any other key is sent to the server as a startup parameter such as `search_path`. You can put them in `config.db`, and they win over the matching configured settings:

```crystal
CQL.configure do |config|
  config.db = "postgres://user:pass@localhost:5432/myapp?sslmode=require&search_path=app"
end
```

See [Enable SSL Connections](ssl.md) and [Set Up Connection Pooling](connection-pooling.md).

### Test the connection

```crystal
begin
  MyDB.exec_query(&.scalar("SELECT 1"))
  puts "Connected successfully"
rescue ex
  puts "Connection failed: #{ex.message}"
  exit 1
end
```

### One configuration, one database

`CQL.config` is process-wide, so `CQL.build_schema` builds from a single URL. For several databases use `Schema.define` for each (see [Multiple databases](#multiple-databases)).

## Connection String Format

### PostgreSQL

```
postgres://username:password@host:port/database
postgres://user:pass@localhost:5432/myapp
postgres://localhost/myapp  # Uses default user and port
```

`postgres://` and `postgresql://` URLs are opened by CQL's native PostgreSQL driver, so no `pg` shard is needed. If you `require "pg"` before CQL, the `pg` shard keeps those scheme names instead. See the [native PostgreSQL driver guide](../postgres-native/README.md).

### CockroachDB

```
cockroachdb://user@host:26257/database
```

`cockroachdb://` is rewritten to `postgres://` for crystal-db. Using the native driver for it is opt-in: compile with `-Dcql_postgres_driver_cockroachdb` or call `CQL::Postgres::Driver.register_cockroachdb`. See [CockroachDB](cockroachdb.md).

### MySQL

```
mysql://username:password@host:port/database
mysql://user:pass@localhost:3306/myapp
```

Add `require "mysql"`.

### SQLite

```
sqlite3://path/to/database.db
sqlite3://./db/development.db
sqlite3://:memory:  # In-memory database
```

Add `require "sqlite3"`. Create the directory of a file database first:

```crystal
db_path = "./db/development.db"
Dir.mkdir_p(File.dirname(db_path))

CQL.configure do |config|
  config.db = "sqlite3://#{db_path}"
end
```

## Low-Level: `Schema.define`

`CQL::Schema.define` takes the adapter and URI directly and ignores `CQL.config`: no pool, SSL or database-specific settings are added. It validates the URI (`CQL::Schema::InvalidURIError`) and opens the pool. Use it for several databases, or when you do not want the global configuration.

```crystal
MyDB = CQL::Schema.define(
  :my_db,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do
end
```

The same shape works for `CQL::Adapter::CockroachDB` (`cockroachdb://root@localhost:26257/defaultdb?sslmode=disable`), `CQL::Adapter::SQLite` (`sqlite3://./db/development.db`) and `CQL::Adapter::MySql` (`mysql://username:password@localhost:3306/myapp_development`). Put pool and SSL settings in the URI yourself, for example `?sslmode=require&max_pool_size=25`.

To get the configured settings with `Schema.define`, pass the built URL:

```crystal
MyDB = CQL::Schema.define(:my_db, CQL.config.full_db_url, CQL.config.adapter) do
end
```

### Multiple Databases

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

## Related

- [Configure CQL](configure-cql.md)
- [Configuration reference](../../reference/configuration.md)
- [Configure Multiple Environments](environments.md)
- [Set Up Connection Pooling](connection-pooling.md)
- [Enable SSL Connections](ssl.md)
