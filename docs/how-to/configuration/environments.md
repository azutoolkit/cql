# Configure Multiple Environments

This guide shows you how to configure different database connections for development, test, and production environments.

`CQL.configure` is the entrypoint for per-environment settings: it reads the environment once, applies that environment's defaults, and then runs your block. For the lifecycle see [Configure CQL](configure-cql.md); every setting is in the [configuration reference](../../reference/configuration.md).

## Environments with `CQL.configure`

`CQL.config` reads `CRYSTAL_ENV` (default `development`) when it is first created and applies the strategy for `production`, `test` or `development`; any other name gets the development strategy.

```crystal
require "cql"

CQL.configure do |config|
  config.db = ENV["DATABASE_URL"]? || "sqlite3://./db/development.db"
end

MyDB = CQL.build_schema(:my_db) do
end
```

Run with `CRYSTAL_ENV=production` and the block starts from the production defaults, so a pool of 25 and `ssl.mode = "require"` are already set; assignments in the block win over them.

### Strategy defaults

| Setting | development | test | production |
|---------|-------------|------|------------|
| `pool_size` / `pool.size` | 5 | 1 | 25 |
| `pool.initial_size` | 2 | 1 | 5 |
| `pool.max_idle_size` | 3 | 1 | 10 |
| `pool.checkout_timeout` | 10 seconds (default) | 10 seconds (default) | 15 seconds |
| `pool.max_retry_attempts` | 3 (default) | 3 (default) | 5 |
| `ssl.mode` | `prefer` (default) | `prefer` (default) | `require` |
| `db` | unchanged | `sqlite3://:memory:` | unchanged |
| `sqlite.journal_mode` | `wal` | `memory` | `wal` (default) |
| `auto_load` | true (default) | false | false |
| `auto_sync` | true | true | false |
| `verify_schema` | true | false | true |
| `bootstrap` | false | false | false |
| `migrations_table` | `:schema_migrations` (default) | `:test_migrations` | `:schema_migrations` (default) |
| `schema_file` / `schema_class` / `schema_name` | `app_schema.cr` / `:AppSchema` / `:app_schema` (defaults) | `test_schema.cr` / `:TestSchema` / `:test_schema` | defaults |
| `log_level` | Debug | Error | Info |
| `sql_logging` | true unless `CQL_NO_SQL_LOG` is set | false (default) | false (default) |

`sql_logging = false` in your block turns development's SQL logging off.

### Strategies apply once

The strategy runs when the configuration object is constructed, before your block, and never again. Two consequences:

- Setting `config.env` inside the block does not re-apply defaults. It only changes what later reads see (for example `migrator_config_for`), so set `CRYSTAL_ENV` instead.
- Changing `ENV["CRYSTAL_ENV"]` after the first `CQL.config` or `CQL.configure` call has no effect until you call `CQL.reset_config!`, which discards the configuration so the next access builds a new one.

```crystal
ENV["CRYSTAL_ENV"] = "test"
CQL.reset_config!
CQL.config.db   # => "sqlite3://:memory:"
```

In the test environment `config.db` is an in-memory SQLite database, so set it in your block when specs need a PostgreSQL or file database.

### Choosing the URL per environment

```crystal
CQL.configure do |config|
  config.db = case config.env
              when "production" then ENV["DATABASE_URL"]? || raise "DATABASE_URL required in production"
              when "test"       then ENV["TEST_DATABASE_URL"]? || config.db
              else                   ENV["DATABASE_URL"]? || "postgres://localhost/myapp_development"
              end
end
```

### Set the environment

```shell
# Development (default)
crystal run src/app.cr

# Test
CRYSTAL_ENV=test crystal spec

# Production
CRYSTAL_ENV=production DATABASE_URL=postgres://... crystal run src/app.cr
```

### Environment-specific features

```crystal
CQL.configure do |config|
  config.sql_logging = false if config.env == "production"
  # Pool size: see connection-pooling.md. SSL: see ssl.md.
end
```

### Verify the environment

```crystal
puts "Running in #{CQL.config.env} environment"
puts "Database: #{CQL.config.db.gsub(/:[^:@]+@/, ":****@")}"  # Hide password
```

## Low-Level: `Schema.define` Per Environment

`CQL::Schema.define` ignores `CQL.config`, so you pick the URL and adapter yourself.

### Environment-Based Configuration

```crystal
require "cql"

CRYSTAL_ENV = ENV["CRYSTAL_ENV"]? || "development"

DATABASE_URL = case CRYSTAL_ENV
when "production"
  ENV["DATABASE_URL"]? || raise "DATABASE_URL required in production"
when "test"
  ENV["TEST_DATABASE_URL"]? || "postgres://localhost/myapp_test"
else
  ENV["DATABASE_URL"]? || "postgres://localhost/myapp_development"
end

ADAPTER = case CRYSTAL_ENV
when "test"
  # Use SQLite for faster tests
  CQL::Adapter::SQLite
else
  CQL::Adapter::Postgres
end

MyDB = CQL::Schema.define(:my_db, adapter: ADAPTER, uri: DATABASE_URL) do
end
```

### Separate Database Per Environment

```crystal
# config/database.cr

module DatabaseConfig
  CRYSTAL_ENV = ENV["CRYSTAL_ENV"]? || "development"

  def self.connection_url : String
    case CRYSTAL_ENV
    when "production"
      ENV["DATABASE_URL"]
    when "test"
      "sqlite3://./db/test.db"
    when "development"
      "postgres://localhost/myapp_development"
    else
      raise "Unknown environment: #{CRYSTAL_ENV}"
    end
  end

  def self.adapter
    case CRYSTAL_ENV
    when "test"
      CQL::Adapter::SQLite
    else
      CQL::Adapter::Postgres
    end
  end
end

MyDB = CQL::Schema.define(
  :my_db,
  adapter: DatabaseConfig.adapter,
  uri: DatabaseConfig.connection_url
) do
end
```

### Using Configuration Files

```crystal
# config/database/development.cr
module Database::Development
  URL = "postgres://localhost/myapp_development"
  ADAPTER = CQL::Adapter::Postgres
end

# config/database/test.cr
module Database::Test
  URL = "sqlite3://./db/test.db"
  ADAPTER = CQL::Adapter::SQLite
end

# config/database/production.cr
module Database::Production
  URL = ENV["DATABASE_URL"]
  ADAPTER = CQL::Adapter::Postgres
end

# config/database.cr
{% if env("CRYSTAL_ENV") == "production" %}
  require "./database/production"
  DB_CONFIG = Database::Production
{% elsif env("CRYSTAL_ENV") == "test" %}
  require "./database/test"
  DB_CONFIG = Database::Test
{% else %}
  require "./database/development"
  DB_CONFIG = Database::Development
{% end %}

MyDB = CQL::Schema.define(:my_db, adapter: DB_CONFIG::ADAPTER, uri: DB_CONFIG::URL) do
end
```

## Related

- [Configure CQL](configure-cql.md)
- [Configuration reference](../../reference/configuration.md)
- [Configure Database Connection](database-connection.md)
- [Set Up Connection Pooling](connection-pooling.md)
- [Enable SSL Connections](ssl.md)
