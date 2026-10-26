# Configure Multiple Environments

Run the same app against different databases and defaults in development, test and production.

## Set the environment

```bash
crystal run src/app.cr                                            # CRYSTAL_ENV unset: development defaults
CRYSTAL_ENV=test crystal spec
CRYSTAL_ENV=production DATABASE_URL=postgres://... ./bin/app
```

`CQL.config` reads `CRYSTAL_ENV` when it is first created and applies that environment's defaults before your `CQL.configure` block runs. Assignments in the block win over them. For the lifecycle see [Configure CQL](configure-cql.md).

## Know the defaults

| Setting | development | test | production |
|---|---|---|---|
| `db` | `sqlite3://./db/development.db` | `sqlite3://:memory:` (does not open; assign a file URL) | `sqlite3://./db/development.db` |
| `pool_size` / `pool.size` | 5 | 1 | 25 |
| `pool.initial_size` / `pool.max_idle_size` | 2 / 3 | 1 / 1 | 5 / 10 |
| `pool.checkout_timeout` / `pool.max_retry_attempts` | 10 s / 3 | 10 s / 3 | 15 s / 5 |
| `ssl.mode` | `prefer` | `prefer` | `require` |
| `sqlite.journal_mode` | `wal` | `memory` | `wal` |
| `auto_sync` / `verify_schema` / `bootstrap` | true / true / false | true / false / false | false / true / false |
| `migrations_table` | `:schema_migrations` | `:test_migrations` | `:schema_migrations` |
| `schema_file` / `schema_class` / `schema_name` | `app_schema.cr` / `:AppSchema` / `:app_schema` | `test_schema.cr` / `:TestSchema` / `:test_schema` | as development |
| `log_level` | Debug | Error | Info |
| `sql_logging?` | true only when `CRYSTAL_ENV=development` is set and `CQL_NO_SQL_LOG` is not; `config.sql_logging = false` turns it off | false | false |
| `cache.on` | true | false | false |

Any other name, such as `staging`, gets the development column, except that `sql_logging?` and `cache.on` are false.

## Choose the URL per environment

```crystal
CQL.configure do |config|
  config.db = case config.env
              when "production" then ENV["DATABASE_URL"]? || raise "DATABASE_URL required in production"
              when "test"       then ENV["TEST_DATABASE_URL"]? || "sqlite3://./db/test.db"
              else                   ENV["DATABASE_URL"]? || "postgres://localhost/myapp_development"
              end
  config.pool_size = 2 if config.env == "test" # migrator.up needs two connections
end
```

## Switch environments with `CRYSTAL_ENV`, not `config.env`

```crystal
# ❌ Renames the environment only: the development pool and SSL defaults stay
CQL.configure { |config| config.env = "production" }
CQL.config.pool_size # => 5

# ✅ Defaults are applied once, when the config is created, so reset after changing CRYSTAL_ENV
ENV["CRYSTAL_ENV"] = "test"
CQL.reset_config!
CQL.config.env # => "test"
CQL.config.db  # => "sqlite3://:memory:"
```

## Check the effective settings

```crystal
config = CQL.config
puts "env=#{config.env} pool=#{config.pool_size} ssl=#{config.ssl.mode} sql_logging=#{config.sql_logging?}"
puts "migrations=#{config.migrations_table} schema_file=#{config.schema_path} auto_sync=#{config.auto_sync?}"
puts "db=#{config.db.gsub(/:[^:@\/]+@/, ":****@")}" # hides the password: postgres://app:****@db.internal/app

# CRYSTAL_ENV unset:
#   env=development pool=5 ssl=prefer sql_logging=false
#   migrations=schema_migrations schema_file=src/schemas/app_schema.cr auto_sync=true
# CRYSTAL_ENV=test:
#   env=test pool=1 ssl=prefer sql_logging=false
#   migrations=test_migrations schema_file=src/schemas/test_schema.cr auto_sync=true
# CRYSTAL_ENV=production:
#   env=production pool=25 ssl=require sql_logging=false
#   migrations=schema_migrations schema_file=src/schemas/app_schema.cr auto_sync=false
```

## Pick the URL yourself with `Schema.define`

`CQL::Schema.define` ignores `CQL.config` and its environment defaults:

```crystal
APP_ENV = ENV["CRYSTAL_ENV"]? || "development"

DATABASE_URL = case APP_ENV
               when "production" then ENV["DATABASE_URL"]? || raise "DATABASE_URL required in production"
               when "test"       then "sqlite3://./db/test.db"
               else                   ENV["DATABASE_URL"]? || "postgres://localhost/myapp_development"
               end

ADAPTER = APP_ENV == "test" ? CQL::Adapter::SQLite : CQL::Adapter::Postgres

AppDB = CQL::Schema.define(:app, adapter: ADAPTER, uri: DATABASE_URL) do
end
```

## See Also

- [Configure CQL](configure-cql.md)
- [Configuration reference](../../reference/configuration.md)
- [Configure Database Connection](database-connection.md)
- [Set Up Connection Pooling](connection-pooling.md)
- [Enable SSL Connections](ssl.md)
- [Set Up Test Databases](../testing/test-database.md)
