# Configure Multiple Environments

This guide shows you how to configure different database connections for development, test, and production environments.

## Environment Detection

```crystal
CRYSTAL_ENV = ENV["CRYSTAL_ENV"]? || "development"
```

## Environment-Based Configuration

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

## Separate Database Per Environment

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

## Using Configuration Files

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

## Set Environment

```shell
# Development (default)
crystal run src/app.cr

# Test
CRYSTAL_ENV=test crystal spec

# Production
CRYSTAL_ENV=production DATABASE_URL=postgres://... crystal run src/app.cr
```

## Environment-Specific Features

```crystal
CRYSTAL_ENV = ENV["CRYSTAL_ENV"]? || "development"

if CRYSTAL_ENV == "development"
  # Enable query logging
  Log.setup do |c|
    c.bind("cql.*", :debug, Log::IOBackend.new)
  end
end

if CRYSTAL_ENV == "production"
  # Use connection pooling
  # Enable SSL
end
```

## Verify Environment

```crystal
puts "Running in #{CRYSTAL_ENV} environment"
puts "Database: #{DATABASE_URL.gsub(/:[^:@]+@/, ":****@")}"  # Hide password
```

## Related

- [Configure Database Connection](database-connection.md)
- [Set Up Connection Pooling](connection-pooling.md)
- [Enable SSL Connections](ssl.md)
