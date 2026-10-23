# Configuration Reference

Every setting on the configuration object (`CQL::Configure::Config`), what it defaults to in each environment, how it is validated, and which URL parameter it becomes. For the step-by-step lifecycle see [Configure CQL](../how-to/configuration/configure-cql.md).

## Access

| Call | Purpose |
|------|---------|
| `CQL.configure { \|c\| ... }` | Yields the shared config, then runs `validate!`. Returns the config. Raises `ArgumentError` for an invalid value; the values stay assigned. |
| `CQL.config` | The shared `CQL::Configure::Config` (created on first use). |
| `CQL.reset_config!` | Drops the shared config; the next `CQL.config` builds a fresh one from `CRYSTAL_ENV`. Used in specs. |
| `CQL::Configure.configured?` | `true` once the shared config exists. |
| `config.validate!` | Runs every validator on demand. |
| `config.add_validator(validator)` | Registers a `CQL::Configure::ConfigValidator` subclass. Validators live on the instance, so `CQL.reset_config!` removes them. |

```crystal
class MaxPoolValidator < CQL::Configure::ConfigValidator
  def validate!(config : CQL::Configure::Config) : Nil
    raise ArgumentError.new("pool_size must be at most 50") if config.pool_size > 50
  end
end

CQL.config.add_validator(MaxPoolValidator.new)
```

Validation order: built-in validator, `pool`, `ssl`, the database-specific block for the adapter in `db`, then `cache`. The first failure raises.

## Top-level settings

Settings marked **inert** are accepted and validated but nothing in `src/` reads them.

| Setting | Type | Default | Notes |
|---------|------|---------|-------|
| `db` | `String` | `"sqlite3://./db/development.db"` | Database URL. The scheme selects the adapter: `postgres://`, `postgresql://`, `cockroachdb://`, `mysql://`, `sqlite3://`. Not read from `DATABASE_URL`; assign it yourself: `c.db = ENV["DATABASE_URL"]`. Cannot be empty. |
| `env` | `String` | `ENV["CRYSTAL_ENV"]?` or `"development"` | Read once when the config is built. Assigning it later does **not** re-apply the environment defaults (see [Environment strategies](#environment-strategies)). |
| `adapter_options` | `Hash(String, String)` | `{}` | Extra URL parameters appended to the connection URL. |
| `logger` | `Log` | `Log.for("CQL::<Env>")` | The logger the migrator, schema and table classes capture at load time. |
| `log_level` | `Log::Severity` | per environment | Applied to `logger` whenever the config calls `effective_logger` (migrator and SQL-logging setup). |
| `migrations_table` | `Symbol` | `:schema_migrations` | Table used by `CQL.build_migrator`. `:test_migrations` in the test environment. |
| `schema_dir` | `String` | `"src/schemas"` | Cannot be empty. Only used to build the generated schema file path. |
| `schema_file` | `String` | `"app_schema.cr"` | Cannot be empty; must end in `.cr`. Only names the generated schema file. |
| `schema_class` | `Symbol` | `:AppSchema` | Constant name written into the generated schema file (`MigratorConfig#schema_name`). |
| `schema_name` | `Symbol` | `:app_schema` | Schema symbol written into the generated schema file (`MigratorConfig#schema_symbol`). |
| `auto_sync` | `Bool` | `true` | Passed to the migrator: rewrite the schema file on construction, `up` and `down`. Also gates the auto-fix in `build_migrator` and `CQL.verify_schema(auto_fix: true)`. |
| `bootstrap` | `Bool` | `false` | `CQL.build_migrator` dumps the schema file from the live database right after building the migrator. |
| `verify_schema` | `Bool` | `false` | `CQL.build_migrator` checks the schema file against the database (ignored when `bootstrap` is on) and logs a warning on mismatch; with `auto_sync` it rewrites the file. |
| `sql_logging` | `Bool` | unset: on in `development` unless `CQL_NO_SQL_LOG` is set, off otherwise | `CQL.build_schema` calls `CQL::Performance.enable_sql_logging` when true. Assigning `true` or `false` overrides the environment default. |
| `sql_logging_colorize` | `Bool` | `true` | Passed to `enable_sql_logging(colorize:)`. |
| `pool_size` | `Int32` | `10`, then per environment | Writing it also writes `pool.size`. Must be positive. |
| `timezone` | `Symbol` | `:utc` | **Inert.** Validated (`:utc` or `:local`), never read. |
| `auto_load` | `Bool` | `true` (`false` in test and production) | **Inert.** No model loading is driven by it. |
| `monitor_performance` | `Bool` | `false` | **Inert.** |
| `sql_logging_async` | `Bool` | `false` | **Inert.** SQL logging is always synchronous. |

Predicate forms exist for the booleans: `auto_load?`, `auto_sync?`, `bootstrap?`, `verify_schema?`, `sql_logging?`, `monitor_performance?`.

Read-only objects: `pool`, `ssl`, `postgres`, `mysql`, `sqlite`, `cache`. Configure them through their own properties (`c.pool.checkout_timeout = 5.seconds`).

### Validation messages

| Check | Message |
|-------|---------|
| `db` empty | `db (database_url) cannot be empty` |
| `schema_dir` empty | `schema_dir cannot be empty` |
| `schema_file` empty | `schema_file cannot be empty` |
| `timezone` not `:utc`/`:local` | `timezone must be :utc or :local` |
| `schema_file` without `.cr` | `schema_file must end with .cr extension` |
| `pool_size <= 0` | `pool_size must be positive` |
| Unknown URL scheme | `Unsupported database URL: <url>` |

## `pool`

`config.pool` is a `ConnectionPoolConfig`. All values reach the connection through `full_db_url`.

| Setting | Type | Default | URL parameter | Validation |
|---------|------|---------|---------------|------------|
| `size` | `Int32` | `10` | `max_pool_size` | `pool_size must be positive` |
| `initial_size` | `Int32` | `1` | `initial_pool_size` | `initial_pool_size must be positive` |
| `max_idle_size` | `Int32` | `1` | `max_idle_pool_size` | `max_idle_pool_size must be positive` |
| `checkout_timeout` | `Time::Span` | `10.seconds` | `checkout_timeout` (seconds) | none |
| `max_retry_attempts` | `Int32` | `3` | `retry_attempts` | `max_retry_attempts must be positive` |
| `retry_delay` | `Time::Span` | `1.second` | `retry_delay` (seconds) | none |
| `use_prepared_statements?` | `Bool` | `true` | `prepared_statements` | none |
| `query_timeout` | `Time::Span` | `30.seconds` | **never emitted** | none |

`query_timeout` is stored and never applied to a connection. Setting `c.pool.size` directly does not update `pool_size`; use `c.pool_size =` to keep both in step. See [Set Up Connection Pooling](../how-to/configuration/connection-pooling.md).

## `ssl`

`config.ssl` is an `SSLConfig`. Parameters are added for PostgreSQL, CockroachDB and MySQL only; SQLite URLs get none.

| Setting | Type | Default | URL parameter |
|---------|------|---------|---------------|
| `mode` | `String` | `"prefer"` (`"require"` in production) | `sslmode` |
| `cert_path` | `String?` | `nil` | `sslcert` (only when set) |
| `key_path` | `String?` | `nil` | `sslkey` (only when set) |
| `ca_path` | `String?` | `nil` | `sslrootcert` for PostgreSQL and CockroachDB, `sslca` for MySQL (only when set) |

Validation: `mode` must be one of `disable`, `allow`, `prefer`, `require`, `verify-ca`, `verify-full`. Otherwise `ssl_mode must be one of: disable, allow, prefer, require, verify-ca, verify-full`. See [Enable SSL Connections](../how-to/configuration/ssl.md).

## Database-specific settings

`config.db_config` returns the block for the adapter detected from `db`: `postgres` for PostgreSQL and CockroachDB, `mysql`, or `sqlite`. Only that block is validated and added to the URL.

### `postgres` (`PostgreSQLConfig`)

| Setting | Type | Default | URL parameter |
|---------|------|---------|---------------|
| `auth_methods` | `String` | `"scram-sha-256,md5"` | `auth_methods` |

### `mysql` (`MySQLConfig`)

| Setting | Type | Default | URL parameter |
|---------|------|---------|---------------|
| `encoding` | `String` | `"utf8mb4_unicode_ci"` | `encoding` |

### `sqlite` (`SQLiteConfig`)

| Setting | Type | Default | URL parameter | Validation |
|---------|------|---------|---------------|------------|
| `journal_mode` | `String` | `"wal"` (`"memory"` in test) | `journal_mode` | one of `delete truncate persist memory wal off`; message `sqlite_journal_mode must be one of: delete, truncate, persist, memory, wal, off` |
| `synchronous` | `String` | `"normal"` | `synchronous` | one of `off normal full extra`; message `sqlite_synchronous must be one of: off, normal, full, extra` |
| `cache_size` | `Int32` | `-4000` | `cache_size` | none |
| `foreign_keys?` | `Bool` | `true` | `foreign_keys` (`1` or `0`) | none |
| `busy_timeout` | `Int32` (ms) | `5000` | `busy_timeout` | `sqlite_busy_timeout must be non-negative` |

## `cache`

`config.cache` is a `CacheConfig`. Its environment defaults come from `ENV["CRYSTAL_ENV"]` at construction, not from `config.env`. Validation runs only when `on` is true.

| Setting | Type | Default | development | test | production | Used by |
|---------|------|---------|-------------|------|------------|---------|
| `on` | `Bool` | `false` | `true` | `false` | `false` | `CQL.build_schema` and `setup_cache_system` |
| `ttl` | `Time::Span` | `1.hour` | | | | `Cache.default_ttl`, fragment cache. Must be positive: `ttl must be positive` |
| `key_prefix` | `String` | `"cql"` | | | | fragment cache keys |
| `name` | `String` | `"cql"` | | | | `Cache.cache_name` |
| `memory_size` | `Int32?` | `1000` | `1000` | `100` | `5000` | memory and fragment cache size. `memory_size must be positive` |
| `request_cache` | `Bool` | `true` | | | | `CQL.start_request_cache`, `CQL.end_request_cache`, `CQL.with_request_cache`, `RequestQueryCacheHelper.enabled` |
| `request_size` | `Int32` | `1000` | `1000` | `100` | `2000` | validation only: `request_size must be positive` |
| `fragment_versions` | `Bool` | `true` | | | | fragment cache `enable_versioning` |
| `fragment_tags` | `Bool` | `true` | | | | fragment cache `enable_tagging` |
| `stats` | `Bool` | `true` | | | | fragment cache `enable_statistics` |
| `invalidation` | `String` | `"timestamp"` | | | | one of `timestamp`, `version`, `transaction_aware`; message `Invalid invalidation strategy: <value>` |
| `max_age` | `Time::Span` | `1.hour` | | | | `timestamp` and `transaction_aware` invalidation |
| `logging` | `Bool` | `false` | `true` | `false` | `false` | **inert** |
| `log_level` | `Log::Severity` | `Debug` | `Debug` | `Debug` | `Info` | **inert** |

These cache settings are inert (nothing in `src/` reads them): `memory`, `memory_stats`, `auto_clear`, `fragments` (only echoed by `cache_stats`), `auto_cleanup`, `cleanup_interval`, `batch_ops`, `middleware`, `request_id_header`.

An environment other than `development`, `test` or `production` keeps the plain defaults (cache off).

Cache helpers on `CQL`: `cache_on(enabled = true)`, `cache_on?`, `cache_stats`, `cache_summary`, `reset_cache!`, `memory_cache`, `fragment_cache`. See [Query caching](../how-to/caching/query-cache.md).

## Environment strategies

`Config.new` reads `CRYSTAL_ENV`, picks a strategy, applies it once, and re-syncs `pool.size` from `pool_size`. `CQL.configure` then runs your block on top, so your assignments win.

- An unset `CRYSTAL_ENV` means `development`. Any other unknown name (for example `staging`) also falls back to the development strategy. Only the exact strings `production`, `test` and `development` are recognised.
- The strategy is applied at construction. `c.env = "production"` inside the block changes `env` (an unset `sql_logging` follows the new `env`) but does not re-apply the production defaults. Set `CRYSTAL_ENV` before the first use of `CQL.config`, or call `CQL.reset_config!` after changing it.

| Setting | development | test | production |
|---------|-------------|------|------------|
| `db` | unchanged | `"sqlite3://:memory:"` (see warning) | unchanged |
| `migrations_table` | `:schema_migrations` | `:test_migrations` | `:schema_migrations` |
| `pool_size` / `pool.size` | 5 | 1 | 25 |
| `pool.initial_size` | 2 | 1 | 5 |
| `pool.max_idle_size` | 3 | 1 | 10 |
| `pool.checkout_timeout` | 10s | 10s | 15s |
| `pool.max_retry_attempts` | 3 | 3 | 5 |
| `ssl.mode` | `prefer` | `prefer` | `require` |
| `sqlite.journal_mode` | `wal` | `memory` | `wal` |
| `schema_file` / `schema_class` / `schema_name` | defaults | `test_schema.cr` / `:TestSchema` / `:test_schema` | defaults |
| `auto_sync` | `true` | `true` | `false` |
| `verify_schema` | `true` | `false` | `true` |
| `bootstrap` | `false` | `false` | `false` |
| `auto_load` | `true` | `false` | `false` |
| `log_level` | `Debug` | `Error` | `Info` |
| `sql_logging` | `true` unless `CQL_NO_SQL_LOG` | `false` | `false` |

Warning: `URI.parse("sqlite3://:memory:")` raises, so `CQL.build_schema` fails with the test strategy's default `db`. Assign a file URL in test (`c.db = "sqlite3://./db/test.db"`).

Warning: the test pool of 1 deadlocks `Migrator#up`, which holds one connection in a transaction while checking out another (`DB::PoolTimeout`). Use `c.pool_size = 2` when running migrations in test.

## Environment variables read

| Variable | Read by | Effect |
|----------|---------|--------|
| `CRYSTAL_ENV` | `Config#env`, `CacheConfig`, performance config | Selects the environment. Default `development`. |
| `CQL_NO_SQL_LOG` | `sql_logging?` | If the variable exists (any value, even empty) and `sql_logging` was never assigned, development does not log SQL. Setting `c.sql_logging = false` in the block does the same. |
| `CQL_CACHE_TYPE` | `CQL::Cache::CacheStoreConfig.from_env` | `redis` or `memory`. |
| `CQL_CACHE_TTL` | same | TTL in whole seconds. |
| `CQL_CACHE_PREFIX` | same | Key prefix. |
| `CQL_REDIS_URL`, `REDIS_URL` | same | Redis URL; setting it selects the Redis store. |
| `CQL_REDIS_POOL_SIZE` | same | Redis pool size. |
| `CQL_REDIS_TIMEOUT` | same | Redis timeout in whole seconds. |
| `CQL_MEMORY_CACHE_MAX_SIZE` | same | Memory store max size. |

The `CQL_CACHE_*`, `CQL_REDIS_*` and `CQL_MEMORY_CACHE_MAX_SIZE` variables are not read by `CQL.config`. They only take effect when you call `CQL::Cache::Cache.configure_from_env` (or `CacheStoreConfig.from_env`). See [Redis cache](../how-to/caching/redis.md).

`DATABASE_URL` is not read automatically. Assign it:

```crystal
CQL.configure do |c|
  c.db = ENV["DATABASE_URL"]
end
```

Other variables belong to the performance monitor, not the config object: `CQL_ENV`, `CQL_MONITORING_ENABLED`, `CQL_SQL_LOGGING`, `CQL_SLOW_QUERY_MS`, `NO_COLOR`; and `CQL_VALIDATE_SCHEMA_MAPPINGS=1` for model mapping checks.

## Helpers

| Helper | Returns | Description |
|--------|---------|-------------|
| `config.adapter` | `CQL::Adapter` | Detected from the `db` scheme. Raises `ArgumentError` (`Unsupported database URL: ...`) otherwise. |
| `config.db_config` | `DatabaseConfig` | The `postgres`, `mysql` or `sqlite` block for the adapter. |
| `config.full_db_url` | `String` | `db` plus `pool`, `ssl`, database-specific settings and `adapter_options` as query parameters. Parameters already in `db` win over configured ones. Applied in that order, later duplicates replace earlier ones. |
| `config.schema_path` | `String` | `File.join(schema_dir, schema_file)`. |
| `config.effective_logger` | `Log` | `logger` with `log_level` applied. |
| `config.migrator_config(...)` | `CQL::MigratorConfig` | Built from `schema_path`, `schema_class`, `schema_name`, `migrations_table`, `auto_sync`. Each can be overridden by keyword (`schema_path:`, `schema_class:`, `schema_name:`, `migrations_table:`, `auto_sync:`). |
| `config.migrator_config_for(env)` | `CQL::MigratorConfig` | Fixed per-environment variants: `"production"` uses `production_schema.cr`, `:ProductionSchema`, `:production_schema`, table `:schema_migrations`, `auto_sync: false`; `"test"` uses `test_schema.cr`, `:TestSchema`, `:test_schema`, table `:test_migrations`, `auto_sync: true`; `"development"` uses the configured paths with `auto_sync: true`; anything else equals `migrator_config`. These variants do not read `verify_schema` or `bootstrap`. |
| `CQL.migrator_config(**args)`, `CQL.migrator_config_for(env)` | `CQL::MigratorConfig` | Same, on the shared config. |
| `CQL.build_schema(name, &)` | `CQL::Schema` | Opens `full_db_url`, runs the block in the schema, then sets up the cache (`cache.on`) and SQL logging (`sql_logging`). |
| `CQL.build_migrator(schema, custom_config = nil)` | `CQL::Migrator` | Uses `migrator_config` and honours `bootstrap` and `verify_schema`; with `custom_config` it is `schema.migrator(custom_config)`. |
| `CQL.bootstrap_schema(schema)` | `CQL::Migrator` | `build_migrator` followed by `bootstrap_schema`. |
| `CQL.verify_schema(schema, auto_fix = false)` | `Bool` | Consistency check; rewrites the schema file when `auto_fix` and `auto_sync` are both true. |

`CQL::MigratorConfig.new` on its own defaults to schema file `src/schemas/app_schema.cr`, `schema_name` `:AppSchema`, `schema_symbol` `:app_schema`, table `:cql_schema_migrations`, `auto_sync` `true`. This is what plain `schema.migrator` uses; see [the lifecycle guide](../how-to/configuration/configure-cql.md#build_migrator-versus-schemamigrator).

## Related

- [Configure CQL](../how-to/configuration/configure-cql.md)
- [Configure Database Connection](../how-to/configuration/database-connection.md)
- [Configure Multiple Environments](../how-to/configuration/environments.md)
