---
description: "Configure CQL once, build the schema from that configuration, point models at the schema, then build the migrator."
---

# Configure CQL

```text
CQL.configure { }  ->  CQL.build_schema(:name) { }  ->  db_context models  ->  CQL.build_migrator(schema)
```

Every setting, default and validation message is in the [configuration reference](../../reference/configuration.md).

## 1. Configure

{% code title="config/cql.cr" %}
```crystal
CQL.configure do |c|
  c.db = ENV["DATABASE_URL"] # CQL never reads DATABASE_URL itself
  c.pool_size = 20
end

# The block starts from the CRYSTAL_ENV defaults (development when unset); assignments win.
# The config is validated when the block ends, so a typo fails at boot:
#   c.pool_size = 0   -> ArgumentError: pool_size must be positive
#   c.db = "redis://" -> ArgumentError: Unsupported database URL: redis://
```
{% endcode %}

To add a check of your own, subclass `CQL::Configure::ConfigValidator` and register it with `CQL.config.add_validator`, as the [configuration reference](../../reference/configuration.md#access) shows.

## 2. Build the schema and keep it in a constant

```crystal
# Opens config.full_db_url: db plus pool, SSL, database-specific and adapter_options
# parameters (parameters already in db win). Then sets up the cache and SQL logging
# when the config enables them.
AppDB = CQL.build_schema(:app) do
  table :users do
    primary :id, Int64
    text :name
    timestamps
  end
end
```

The first model's `db_context` builds the constant, and `CQL.build_schema` reads `CQL.config` at that moment, so `CQL.configure` must load before any model.

## 3. Point models at the schema

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: AppDB, table: :users

  getter id : Int64?
  property name : String
  getter created_at : Time?
  getter updated_at : Time?

  def initialize(@name : String)
  end
end
```

## 4. Build the migrator

```crystal
class CreateUsers < CQL::Migration(20260101000000)
  def up
    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end

migrator = CQL.build_migrator(AppDB)
migrator.up
```

### `build_migrator` versus `schema.migrator`

They track migrations in different tables and write the schema file to different places, so pick one and use it everywhere.

| | `CQL.build_migrator(schema)` | `schema.migrator` |
|---|---|---|
| Settings from | `CQL.config` | `CQL::MigratorConfig` defaults |
| Tracking table | `config.migrations_table` (`:schema_migrations`; `:test_migrations` in test) | `:cql_schema_migrations` |
| Schema file | `config.schema_dir` + `config.schema_file` (`src/schemas/app_schema.cr`; `test_schema.cr` in test) | `src/schemas/app_schema.cr` |
| `auto_sync` | `config.auto_sync` (off in production) | `true` |
| `bootstrap` / `verify_schema` | honoured | not available |

```crystal
CQL.build_migrator(AppDB)  # reads CQL.config
AppDB.migrator             # ignores CQL.config; a migration applied here is invisible to build_migrator

# Only the migrator differs; skips the bootstrap / verify_schema step
CQL.build_migrator(AppDB, CQL.migrator_config(migrations_table: :my_migrations))

# With auto_sync on, a migrator writes the schema file when constructed if it is missing, and after
# each up/down. bootstrap = true dumps the file from the live database. verify_schema = true
# (development and production) compares it and logs "Schema file is out of sync with database";
# with auto_sync on, it then rewrites the file.
```

<details>
<summary>Complete example: one file for all three environments</summary>

Save as one file and run it with `CRYSTAL_ENV=development`, `test` or `production`. It creates `db/` in the working directory.

{% code title="env_demo.cr" %}
```crystal
require "cql"
require "sqlite3"

# ---- config/cql.cr: loads before anything else uses CQL.config ----
Dir.mkdir_p("db")

CQL.configure do |c|
  c.schema_dir = "db"

  c.db = case c.env
         when "production" then ENV.fetch("DATABASE_URL", "sqlite3://./db/production.db")
         when "test"       then "sqlite3://./db/test.db"
         else                   "sqlite3://./db/development.db"
         end

  c.pool_size = 2 if c.env == "test"
end

# ---- app.cr ----
AppDB = CQL.build_schema(:app) do
  table :users do
    primary :id, Int64
    text :name
    timestamps
  end
end

class CreateUsers < CQL::Migration(20260101000000)
  def up
    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end

class User
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: AppDB, table: :users

  getter id : Int64?
  property name : String
  getter created_at : Time?
  getter updated_at : Time?

  def initialize(@name : String)
  end
end

migrator = CQL.build_migrator(AppDB)
migrator.up
User.new("Ada").save!

puts "env=#{CQL.config.env} users=#{User.count}"
puts "table=#{migrator.config.migration_table_name} file=#{migrator.config.schema_file_path}"
# CRYSTAL_ENV=development -> env=development users=1 / table=schema_migrations file=db/app_schema.cr
# CRYSTAL_ENV=test        -> env=test users=1        / table=test_migrations file=db/test_schema.cr
# CRYSTAL_ENV=production  -> env=production users=1  / table=schema_migrations file=db/app_schema.cr
#                            (file not written: auto_sync is off in production, so commit it)
```
{% endcode %}

</details>

{% hint style="warning" %}
The test environment's default `db` is `sqlite3://:memory:`, which `CQL.build_schema` rejects with `URI::Error: Invalid URI: bad port at character 11`. Assign a file URL, as the complete example does.
{% endhint %}

{% hint style="warning" %}
Test pools default to one connection, and the schema dump after `migrator.up` needs two: `CQL::Migrator::Error: Schema update failed: Could not check out a connection in 10.0 seconds`. Set `c.pool_size = 2`, or pass `CQL::MigratorConfig.new(auto_sync: false)`.
{% endhint %}

## Read the config anywhere

```crystal
CQL.config.env           # => "development"
CQL.config.adapter       # => CQL::Adapter::SQLite
CQL.config.full_db_url   # => "sqlite3://./db/development.db?initial_pool_size=2&max_pool_size=5&..."
CQL.config.sql_logging?  # => true with CRYSTAL_ENV=development (unless CQL_NO_SQL_LOG is set);
                         #    false when CRYSTAL_ENV is unset
```

Call `CQL.configure` again to change the same config; each call re-validates. Do it before `CQL.build_schema`, which captures `full_db_url`.

## Override one environment

```crystal
# Unknown names such as staging get the development defaults, so state what differs
CQL.configure do |c|
  if c.env == "staging"
    c.db = ENV["DATABASE_URL"]
    c.pool_size = 10
    c.ssl.mode = "require"
    c.sql_logging = false
  end
end
```

Assigning `c.env` does not apply another environment's defaults; see [Switch environments with `CRYSTAL_ENV`](environments.md#switch-environments-with-crystal_env-not-configenv).

## Reset configuration in specs

{% code title="spec/cql_config_spec.cr" %}
```crystal
require "spec"
require "cql"

# A failed CQL.configure keeps the bad value, so reset around every example
Spec.before_each { CQL.reset_config! }
Spec.after_each { CQL.reset_config! }

describe "configuration" do
  it "validates at the end of the block" do
    expect_raises(ArgumentError, /pool_size must be positive/) do
      CQL.configure { |c| c.pool_size = 0 }
    end
  end

  it "keeps pool.size in step with pool_size" do
    CQL.configure { |c| c.pool_size = 7 }
    CQL.config.pool.size.should eq(7)
  end
end

# To test another environment: ENV["CRYSTAL_ENV"] = "test", then CQL.reset_config!
# A schema built before the reset keeps its own connection.
```
{% endcode %}

## Use `Schema.define` directly

`CQL::Schema.define` takes the adapter and URL itself and ignores `CQL.config`; see [Use `Schema.define` for several databases](database-connection.md#use-schemadefine-for-several-databases).

## See Also

- [Configuration reference](../../reference/configuration.md)
- [Configure Database Connection](database-connection.md)
- [Configure Multiple Environments](environments.md)
- [Set Up Connection Pooling](connection-pooling.md)
- [Run Migrations](../migrations/run-migrations.md)
