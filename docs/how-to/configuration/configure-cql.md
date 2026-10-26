# Configure CQL

This guide shows the lifecycle CQL expects: configure once, build the schema from that configuration, point models at the schema, then build the migrator. `CQL.configure` is the entrypoint; `Schema.define` is the explicit low-level alternative (last section).

```
CQL.configure { }  ->  CQL.build_schema(:name) { }  ->  db_context models  ->  CQL.build_migrator(schema)
```

Every setting, default and error message is in the [configuration reference](../../reference/configuration.md).

## 1. Configure

`CQL.configure` yields the shared `CQL.config`, then validates it when the block ends. The config starts from the defaults of the current `CRYSTAL_ENV` (`development` when unset), and your assignments win over them.

```crystal
CQL.configure do |c|
  c.db = ENV["DATABASE_URL"]
  c.pool_size = 20
end
```

`DATABASE_URL` is not read automatically, so assign it as shown. A bad value raises `ArgumentError` at the end of the block (for example `pool_size must be positive`), so a typo fails at boot rather than at the first query.

## 2. Build the schema and keep it in a constant

`CQL.build_schema` opens the connection from `config.full_db_url` (pool, SSL, database-specific settings and `adapter_options` become URL parameters; parameters already in your URL win), runs the table DSL against the new schema, and sets up caching and SQL logging when the config asks for them. Assign the result to a constant so models can reference it at compile time:

```crystal
AppDB = CQL.build_schema(:app) do
  table :users do
    primary :id, Int64
    text :name
    timestamps
  end
end
```

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

The two do not agree on where migrations are tracked or where the schema file goes, so pick one and use it everywhere.

| | `CQL.build_migrator(schema)` | `schema.migrator` |
|---|---|---|
| Settings from | `CQL.config` | `CQL::MigratorConfig` defaults |
| Tracking table | `config.migrations_table` (`:schema_migrations`; `:test_migrations` in test) | `:cql_schema_migrations` |
| Schema file | `config.schema_dir` + `config.schema_file` (default `src/schemas/app_schema.cr`; `test_schema.cr` in test) | `src/schemas/app_schema.cr` |
| `auto_sync` | `config.auto_sync` | `true` |
| `bootstrap` / `verify_schema` | honoured | not available |

Consequences:

- Migrations applied through `schema.migrator` are recorded in `cql_schema_migrations`; `build_migrator` looks in `schema_migrations`. Mixing them leaves each migrator blind to what the other applied.
- `schema.migrator` writes `src/schemas/app_schema.cr` after each `up` and `down`, because its `auto_sync` is `true`; creating it writes no schema file. `build_migrator` writes to the path you configured (and not at all in production, where `auto_sync` is `false`).
- With `bootstrap = true`, `build_migrator` dumps the schema file from the live database. With `verify_schema = true` (the default in development and production) it compares the file to the database, logs `Schema file is out of sync with database` on a mismatch, and rewrites the file when `auto_sync` is on.

To change only the migrator, pass your own config: `CQL.build_migrator(AppDB, CQL.migrator_config(migrations_table: :my_migrations))`. That skips bootstrap and verification.

## Complete example

Save as one file and run it with `CRYSTAL_ENV=development`, `test` or `production` (run `shards install` first for `sqlite3`). It creates `db/` next to where you start it.

```crystal
require "cql"
require "sqlite3"

# ---- config/cql.cr: runs once, before anything uses CQL.config ----
Dir.mkdir_p("db")

CQL.configure do |c|
  c.schema_dir = "db"

  c.db = case c.env
         when "production" then ENV.fetch("DATABASE_URL", "sqlite3://./db/production.db")
         when "test"       then "sqlite3://./db/test.db"
         else                   "sqlite3://./db/development.db"
         end
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
```

Output per environment (the counts grow with each run because the database is a file):

| `CRYSTAL_ENV` | Database | Migration table | Schema file |
|---------------|----------|-----------------|-------------|
| `development` | `db/development.db` | `schema_migrations` | `db/app_schema.cr` |
| `test` | `db/test.db` | `test_migrations` | `db/test_schema.cr` |
| `production` | `db/production.db` or `DATABASE_URL` | `schema_migrations` | `db/app_schema.cr` (not written; `auto_sync` is off, so commit it) |

What differs between them comes from the environment defaults, not from your code: development logs SQL and keeps the schema file in sync, production uses a pool of 25, `ssl.mode = "require"` and verifies the schema file, and test uses a pool of 1 (see the notes below).

Notes on the test branch:

- The test environment's default `db` is `sqlite3://:memory:`, which cannot be parsed by `CQL.build_schema`. Assign a file URL as above.
- The test pool defaults to 1. Migrations and the `auto_sync` schema file dump that follows each need only one connection, so they run on it.

## Read config in an initializer

Everything after `CQL.configure` reads the same object:

```crystal
CQL.config.env           # => "development"
CQL.config.adapter       # => CQL::Adapter::SQLite
CQL.config.full_db_url   # => "sqlite3://./db/development.db?initial_pool_size=2&..."
CQL.config.sql_logging?  # => true when CRYSTAL_ENV=development unless CQL_NO_SQL_LOG is set; false when CRYSTAL_ENV is unset
```

Call `CQL.configure` again at any time to adjust the same config; each call re-validates. Do it before `CQL.build_schema`, because the schema captures `full_db_url` when it is built.

## Per-environment overrides

The environment defaults are applied once, when the config is first created from `CRYSTAL_ENV`. Branch on `c.env` for what you want to differ, as in the example. Do not set `c.env = "production"` to switch environments: it changes the name only and does not re-apply the production defaults. Set `CRYSTAL_ENV` instead.

Unknown names (such as `staging`) get the development defaults, so state what you need explicitly:

```crystal
CQL.configure do |c|
  if c.env == "staging"
    c.db = ENV["DATABASE_URL"]
    c.pool_size = 10
    c.ssl.mode = "require"
    c.sql_logging = false
  end
end
```

## Reset configuration in specs

`CQL.reset_config!` drops the shared config so the next `CQL.config` is built fresh from `CRYSTAL_ENV`. Reset around each example so one example's settings (and validators) do not leak into the next:

```crystal
require "spec"
require "cql"

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
```

A schema already built stays open after a reset, since it holds its own connection. To test a different `CRYSTAL_ENV`, set `ENV["CRYSTAL_ENV"]` and then call `CQL.reset_config!`.

## Add your own validation

```crystal
class MaxPoolValidator < CQL::Configure::ConfigValidator
  def validate!(config : CQL::Configure::Config) : Nil
    raise ArgumentError.new("pool_size must be at most 50") if config.pool_size > 50
  end
end

CQL.config.add_validator(MaxPoolValidator.new)
```

It runs at the end of every later `CQL.configure` block.

## When to use `Schema.define` directly

`CQL::Schema.define` takes the adapter and URL as arguments and ignores `CQL.config`. Use it when you want that explicitness:

- a second database that needs its own URL, alongside the configured one
- a one-off script or spec fixture that should not touch the shared config
- a URL that you want to pass exactly as written, with no pool, SSL or database-specific parameters added

```crystal
ReportsDB = CQL::Schema.define(
  :reports,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://./db/reports.db"
) do
  table :events do
    primary :id, Int64
    text :name
  end
end
```

Use `ReportsDB.migrator` (or a `MigratorConfig` you build yourself) for it, since `CQL.build_migrator` applies the shared config's table and schema file. See [Configure Database Connection](database-connection.md) for connection strings and [Configure Multiple Environments](environments.md) for the per-environment defaults.

## Related

- [Configuration reference](../../reference/configuration.md)
- [Configure Database Connection](database-connection.md)
- [Configure Multiple Environments](environments.md)
- [Set Up Connection Pooling](connection-pooling.md)
- [Run Migrations](../migrations/run-migrations.md)
