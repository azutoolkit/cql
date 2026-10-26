# Configure Database Connection

Point CQL at a database with a URL in `CQL.configure`; the URL scheme picks the adapter.

For when settings are read and validated see [Configure CQL](configure-cql.md). Every setting is in the [configuration reference](../../reference/configuration.md).

## Connect with `CQL.configure`

```crystal
require "cql"
require "sqlite3"

CQL.configure do |config|
  config.db = ENV["DATABASE_URL"]? || "sqlite3://./db/development.db" # the default db
end

AppDB = CQL.build_schema(:app) do
  table :users do
    primary :id, Int64
    text :name
  end
end
```

`CQL.build_schema` opens `config.full_db_url`, so pool, SSL, database-specific and `adapter_options` settings reach the connection. `CQL.config` is process-wide: it describes one database.

## Pick the URL for your database

```text
postgres://user:pass@localhost:5432/myapp    CQL::Adapter::Postgres     native driver, loaded by require "cql"
postgresql://localhost/myapp                 CQL::Adapter::Postgres     default user and port
cockroachdb://root@localhost:26257/app       CQL::Adapter::CockroachDB  see cockroachdb.md
mysql://user:pass@localhost:3306/myapp       CQL::Adapter::MySql        add require "mysql"
sqlite3://./db/development.db                CQL::Adapter::SQLite       add require "sqlite3"
redis://localhost:6379                       ArgumentError: Unsupported database URL: redis://localhost:6379
```

`config.adapter` reports the adapter. If the app also requires the `pg` shard, `pg` serves `postgres://` URLs instead of the native driver; see the [native PostgreSQL driver guide](../postgres-native/README.md).

## See what `full_db_url` adds

```crystal
CQL.configure do |config|
  config.db = "postgres://app:secret@db.internal:5432/app"
  config.pool_size = 25                                  # connection-pooling.md
  config.ssl.mode = "verify-full"                        # ssl.md
  config.ssl.ca_path = "/etc/ssl/certs/db-ca.crt"
  config.adapter_options["application_name"] = "billing"
end

puts CQL.config.full_db_url
# postgres://app:secret@db.internal:5432/app?initial_pool_size=2&max_pool_size=25&max_idle_pool_size=3
#   &checkout_timeout=10.0&retry_attempts=3&retry_delay=1.0&prepared_statements=true
#   &sslmode=verify-full&sslrootcert=%2Fetc%2Fssl%2Fcerts%2Fdb-ca.crt
#   &auth_methods=scram-sha-256%2Cmd5&application_name=billing
```

The order is pool, SSL (not for SQLite), database-specific settings, then `adapter_options`. The database-specific settings follow the adapter:

| Settings object | Adapters | URL parameters (default) |
|---|---|---|
| `config.postgres` | Postgres, CockroachDB | `auth_methods` (`scram-sha-256,md5`); the native driver accepts and ignores it |
| `config.mysql` | MySql | `encoding` (`utf8mb4_unicode_ci`) |
| `config.sqlite` | SQLite | `journal_mode` (`wal`), `synchronous` (`normal`), `cache_size` (`-4000`), `foreign_keys` (`1`), `busy_timeout` (`5000`) |

`adapter_options` keys are passed as given. The native PostgreSQL driver sends keys it does not recognise to the server as startup parameters, so add only keys the server understands.

## Put driver options in the URL

```crystal
CQL.configure do |config|
  # sslmode, connect_timeout, application_name, statement_cache_size and pool keys
  # configure the driver; other keys such as search_path go to the server
  config.db = "postgres://app:secret@db.internal/app?sslmode=disable&max_pool_size=5&search_path=app"
end

CQL.config.full_db_url # => "...&max_pool_size=5&...&sslmode=disable&...": parameters in db win
```

## Prepare a SQLite file

```crystal
# ❌ CQL.build_schema raises DB::ConnectionRefused (with no message): the directory is missing
CQL.configure { |config| config.db = "sqlite3://./db/missing/app.db" }

# ✅ Create the directory first
db_path = "./db/development.db"
Dir.mkdir_p(File.dirname(db_path))
CQL.configure { |config| config.db = "sqlite3://#{db_path}" }
```

{% hint style="warning" %}
`sqlite3://:memory:` does not parse: `CQL.build_schema` raises `URI::Error` and `Schema.define` raises `CQL::Schema::InvalidURIError`. Use a file URL.
{% endhint %}

## Test the connection

```crystal
begin
  AppDB.exec_query(&.scalar("SELECT 1"))
  puts "Connected"
rescue ex
  puts "Connection failed: #{ex.class}: #{ex.message}"
  # Connection failed: DB::ConnectionRefused: cannot connect to localhost:5432: Error connecting to 'localhost:5432': Connection refused
  exit 1
end
```

The schema opens its first connection when it is built, so a refused connection usually raises from `CQL.build_schema` itself. See [Fix Connection Errors](../troubleshooting/connection-errors.md).

## Use `Schema.define` for several databases

`CQL::Schema.define` takes the adapter and URL directly and ignores `CQL.config`: no pool, SSL or database-specific parameters are added.

```crystal
PrimaryDB = CQL::Schema.define(
  :primary,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["PRIMARY_DATABASE_URL"] # add ?sslmode=require&max_pool_size=25 yourself
) do
end

AnalyticsDB = CQL::Schema.define(
  :analytics,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["ANALYTICS_DATABASE_URL"]
) do
end

# Or reuse the configured URL and adapter
ConfiguredDB = CQL::Schema.define(:configured, CQL.config.full_db_url, CQL.config.adapter) do
end

class User
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: PrimaryDB, table: :users
end

class PageView
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: AnalyticsDB, table: :page_views
end

# A malformed URI raises CQL::Schema::InvalidURIError before connecting:
#   "redis://localhost"   -> Unsupported database type: redis
#   "cockroachdb:///app"  -> Missing host in CockroachDB URI (same for MySQL)
#   "localhost/app"       -> Invalid database URI format
```

## See Also

- [Configure CQL](configure-cql.md)
- [Configuration reference](../../reference/configuration.md)
- [Set Up Connection Pooling](connection-pooling.md)
- [Enable SSL Connections](ssl.md)
- [Use CockroachDB](cockroachdb.md)
- [Fix Connection Errors](../troubleshooting/connection-errors.md)
