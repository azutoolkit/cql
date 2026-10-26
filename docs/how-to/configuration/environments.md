---
description: "Run the same app against different databases and defaults in development, test and production."
---

# Configure Multiple Environments

## Set the environment

```bash
crystal run src/app.cr                                            # CRYSTAL_ENV unset: development defaults
CRYSTAL_ENV=test crystal spec
CRYSTAL_ENV=production DATABASE_URL=postgres://... ./bin/app
```

`CQL.config` reads `CRYSTAL_ENV` when it is first created and applies that environment's defaults before your `CQL.configure` block runs. Assignments in the block win over them. The defaults per environment are in [Environment strategies](../../reference/configuration.md#environment-strategies); for the lifecycle see [Configure CQL](configure-cql.md).

## Choose the URL per environment

{% code title="config/cql.cr" %}
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
{% endcode %}

`CQL::Schema.define` ignores `CQL.config` and these defaults, so with it you pick the URL and adapter per environment yourself; see [Use `Schema.define` for several databases](database-connection.md#use-schemadefine-for-several-databases).

## Switch environments with `CRYSTAL_ENV`, not `config.env`

```crystal
# ❌ Renames the environment only: the development pool and SSL defaults stay
CQL.configure { |config| config.env = "production" }
CQL.config.pool_size # => 5

# ✅ Defaults are applied once, when the config is created, so reset after changing CRYSTAL_ENV
ENV["CRYSTAL_ENV"] = "test"
CQL.reset_config!
CQL.config.env # => "test"
CQL.config.db  # => "sqlite3::memory:"
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

## See Also

- [Configure CQL](configure-cql.md)
- [Configuration reference](../../reference/configuration.md)
- [Configure Database Connection](database-connection.md)
- [Set Up Connection Pooling](connection-pooling.md)
- [Enable SSL Connections](ssl.md)
- [Set Up Test Databases](../testing/test-database.md)
