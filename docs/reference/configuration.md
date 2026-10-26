---
description: "Every setting on CQL::Configure::Config, its default in each environment, its validation message and the URL parameter it becomes, plus the environment variables CQL reads."
---

# Configuration Reference

## Access

| Call | Returns | Behavior |
| :--- | :--- | :--- |
| **`CQL.configure { \|c\| ... }`** | `Config` | Yields the shared config, runs `validate!`, then calls `CQL::Performance.enable_monitoring` when `monitor_performance` is true. An invalid value raises `ArgumentError` and stays assigned. |
| **`CQL.config`** | `Config` | The shared config, built on first use from `CRYSTAL_ENV`. Same as `CQL::Configure.current`. |
| **`CQL.reset_config!`** | `Nil` | Drops the shared config (`CQL::Configure.reset!`); the next `CQL.config` builds a fresh one. |
| **`CQL::Configure.configured?`** | `Bool` | `true` once the shared config exists. Loading CQL already builds it (`Schema`, `Table` and `Migrator` read `CQL.config.logger`), so this is `true` unless `reset_config!` ran since. |
| **`config.validate!`** | `Nil` | Runs the validators in order: built-in, `pool`, `ssl`, the block for the adapter in `db`, `cache`. The first failure raises. |
| **`config.add_validator(v)`** | `Nil` | Adds a `CQL::Configure::ConfigValidator` subclass. It lives on this config instance, so `reset_config!` drops it. |

```crystal
CQL.configure do |c|
  c.db = ENV["DATABASE_URL"]
  c.pool_size = 20
end

class MaxPoolValidator < CQL::Configure::ConfigValidator
  def validate!(config : CQL::Configure::Config) : Nil
    raise ArgumentError.new("pool_size must be at most 50") if config.pool_size > 50
  end
end

CQL.config.add_validator(MaxPoolValidator.new)
CQL.configure { |c| c.pool_size = 60 } # raises ArgumentError: pool_size must be at most 50
```

## Top-level settings

```crystal
CQL.configure do |c|
  c.db = "postgres://app@localhost/app"   # default "sqlite3://./db/development.db"
  c.env = "production"                    # default ENV["CRYSTAL_ENV"]? || "development"
  c.adapter_options = {"application_name" => "web"}
  c.logger = Log.for("myapp.db")
  c.log_level = Log::Severity::Warn
  c.migrations_table = :schema_migrations
  c.schema_dir = "src/schemas"
  c.schema_file = "app_schema.cr"
  c.schema_class = :AppSchema
  c.schema_name = :app_schema
  c.auto_sync = false
  c.bootstrap = false
  c.verify_schema = true
  c.sql_logging = true
  c.sql_logging_colorize = false
  c.pool_size = 25
  c.monitor_performance = true
end
```

| Setting | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `db` | `String` | `"sqlite3://./db/development.db"` (`"sqlite3://:memory:"` in test) | Database URL. The scheme picks the adapter: `postgres://`, `postgresql://`, `cockroachdb://`, `mysql://`, `sqlite3://`. `DATABASE_URL` is not read for you. |
| `env` | `String` | `ENV["CRYSTAL_ENV"]? \|\| "development"` | Read when the config is built. Assigning it later changes `env` and the `sql_logging` default only; it does not re-apply the [environment strategy](#environment-strategies). |
| `adapter_options` | `Hash(String, String)` | `{}` | Extra URL parameters, appended after the configured ones. A key the config already emits appears twice and crystal-db reads the first; to override a configured parameter put it in `db`. |
| `logger` | `Log` | `Log.for("CQL::<Env>")`, e.g. `CQL::Development` | `Schema`, `Table`, `AlterTable` and `Migrator` capture it when CQL loads (`Log = CQL.config.logger`); a logger assigned later reaches only `effective_logger` (the `CQL.build_*` helpers). |
| `log_level` | `Log::Severity` | `Debug` (development and unknown), `Error` (test), `Info` (production) | Applied to `logger` by `effective_logger`. |
| `migrations_table` | `Symbol` | `:schema_migrations` (`:test_migrations` in test) | Table `CQL.build_migrator` records migrations in. |
| `schema_dir` | `String` | `"src/schemas"` | Directory of the generated schema file. |
| `schema_file` | `String` | `"app_schema.cr"` (`"test_schema.cr"` in test) | Generated schema file name; must end in `.cr`. |
| `schema_class` | `Symbol` | `:AppSchema` (`:TestSchema` in test) | Constant written into the schema file (`MigratorConfig#schema_name`). |
| `schema_name` | `Symbol` | `:app_schema` (`:test_schema` in test) | Schema symbol written into the schema file (`MigratorConfig#schema_symbol`). |
| `auto_sync` | `Bool` | `true` (`false` in production) | Passed to the migrator: write the schema file when the migrator is built and the file is missing, and rewrite it after `up` / `down`. Also gates the rewrite in `build_migrator` and `CQL.verify_schema(auto_fix: true)`. |
| `bootstrap` | `Bool` | `false` | `CQL.build_migrator` dumps the schema file from the database right away. |
| `verify_schema` | `Bool` | `true` (`false` in test) | `CQL.build_migrator` compares the schema file with the database (skipped when `bootstrap` is on) and logs a warning on mismatch; with `auto_sync` on it then rewrites the file. |
| `sql_logging` | `Bool` | `true` only when the environment is *named* `development` (`CRYSTAL_ENV=development` or `c.env = "development"`) and `CQL_NO_SQL_LOG` is unset; otherwise `false`, including when `CRYSTAL_ENV` is unset | `CQL.build_schema` calls `CQL::Performance.enable_sql_logging` (which also enables the performance monitor). An assigned value overrides the default. |
| `sql_logging_colorize` | `Bool` | `true` | Passed as `enable_sql_logging(colorize:)`. |
| `pool_size` | `Int32` | `10`, then 5 / 1 / 25 by environment | Writes `pool.size` too, and lowers `pool.initial_size` and `pool.max_idle_size` to at most the new size. Must be positive. |
| `monitor_performance` | `Bool` | `false` | `CQL.configure` turns the global performance monitor on. One-way: `false` never turns it off. |

Predicates: `auto_load?`, `auto_sync?`, `bootstrap?`, `verify_schema?`, `sql_logging?`, `monitor_performance?`. Read-only blocks: `pool`, `ssl`, `postgres`, `mysql`, `sqlite`, `cache`; set their properties (`c.pool.checkout_timeout = 5.seconds`).

### Validation messages

| Check | `ArgumentError` message |
| :--- | :--- |
| `db` empty | `db (database_url) cannot be empty` |
| `db` scheme unknown | `Unsupported database URL: <url>` |
| `schema_dir` empty | `schema_dir cannot be empty` |
| `schema_file` empty | `schema_file cannot be empty` |
| `schema_file` without `.cr` | `schema_file must end with .cr extension` |
| `timezone` not `:utc` / `:local` | `timezone must be :utc or :local` |
| `pool_size <= 0` | `pool_size must be positive` |

## `pool`

`config.pool` is a `ConnectionPoolConfig`. Each value reaches the driver as a URL parameter through `full_db_url`.

```crystal
CQL.configure do |c|
  c.pool.size = 20                       # max_pool_size=20
  c.pool.initial_size = 2                # initial_pool_size=2
  c.pool.max_idle_size = 5               # max_idle_pool_size=5
  c.pool.checkout_timeout = 5.seconds    # checkout_timeout=5.0
  c.pool.max_retry_attempts = 3          # retry_attempts=3
  c.pool.retry_delay = 500.milliseconds  # retry_delay=0.5
  c.pool.use_prepared_statements = false # prepared_statements=false
end
```

| Setting | Type | Default | URL parameter | Validation message |
| :--- | :--- | :--- | :--- | :--- |
| `size` | `Int32` | `10` | `max_pool_size` | `pool_size must be positive` |
| `initial_size` | `Int32` | `1` | `initial_pool_size` | `initial_pool_size must be positive` |
| `max_idle_size` | `Int32` | `1` | `max_idle_pool_size` | `max_idle_pool_size must be positive` |
| `checkout_timeout` | `Time::Span` | `10.seconds` | `checkout_timeout` (seconds) | none |
| `max_retry_attempts` | `Int32` | `3` | `retry_attempts` | `max_retry_attempts must be positive` |
| `retry_delay` | `Time::Span` | `1.second` | `retry_delay` (seconds) | none |
| `use_prepared_statements?` | `Bool` | `true` | `prepared_statements` | none |

`c.pool.size =` does not update `pool_size`; use `c.pool_size =` to set both. See [Set Up Connection Pooling](../how-to/configuration/connection-pooling.md).

## `ssl`

`config.ssl` is an `SSLConfig`. Its parameters are added for PostgreSQL, CockroachDB and MySQL; SQLite URLs get none.

```crystal
CQL.configure do |c|
  c.ssl.mode = "verify-full"           # sslmode=verify-full
  c.ssl.ca_path = "/etc/ssl/ca.pem"    # sslrootcert= (PostgreSQL, CockroachDB) / sslca= (MySQL)
  c.ssl.cert_path = "/etc/ssl/c.pem"   # sslcert=
  c.ssl.key_path = "/etc/ssl/c.key"    # sslkey=
end
```

| Setting | Type | Default | URL parameter |
| :--- | :--- | :--- | :--- |
| `mode` | `String` | `"prefer"` (`"require"` in production) | `sslmode` |
| `ca_path` | `String?` | `nil` | `sslrootcert` (PostgreSQL, CockroachDB) or `sslca` (MySQL), only when set |
| `cert_path` | `String?` | `nil` | `sslcert`, only when set |
| `key_path` | `String?` | `nil` | `sslkey`, only when set |

`mode` must be one of `disable allow prefer require verify-ca verify-full`, else `ssl_mode must be one of: disable, allow, prefer, require, verify-ca, verify-full`.

{% hint style="warning" %}
The native PostgreSQL driver rejects `sslcert` and `sslkey` (`ArgumentError: the sslcert option is not supported by this driver`) and accepts `sslrootcert` only with `sslmode=verify-full`. See [Enable SSL Connections](../how-to/configuration/ssl.md).
{% endhint %}

## Database-specific settings

`config.db_config` returns the block for the adapter in `db`: `postgres` (PostgreSQL and CockroachDB), `mysql` or `sqlite`. Only that block is validated and added to the URL.

{% tabs %}
{% tab title="SQLite" %}
```crystal
CQL.configure do |c|
  c.sqlite.journal_mode = "delete" # journal_mode=delete
  c.sqlite.synchronous = "full"    # synchronous=full
  c.sqlite.cache_size = -8000      # cache_size=-8000
  c.sqlite.foreign_keys = false    # foreign_keys=0
  c.sqlite.busy_timeout = 10_000   # busy_timeout=10000
end
```
{% endtab %}
{% tab title="PostgreSQL and CockroachDB" %}
```crystal
CQL.configure do |c|
  c.postgres.auth_methods = "scram-sha-256" # auth_methods=scram-sha-256 (ignored by the native driver)
end
```
{% endtab %}
{% tab title="MySQL" %}
```crystal
CQL.configure do |c|
  c.mysql.encoding = "utf8mb4_general_ci" # encoding=utf8mb4_general_ci
end
```
{% endtab %}
{% endtabs %}

| Block | Setting | Type | Default | URL parameter | Validation message |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `postgres` | `auth_methods` | `String` | `"scram-sha-256,md5"` | `auth_methods` | none |
| `mysql` | `encoding` | `String` | `"utf8mb4_unicode_ci"` | `encoding` | none |
| `sqlite` | `journal_mode` | `String` | `"wal"` (`"memory"` in test) | `journal_mode` | `sqlite_journal_mode must be one of: delete, truncate, persist, memory, wal, off` |
| `sqlite` | `synchronous` | `String` | `"normal"` | `synchronous` | `sqlite_synchronous must be one of: off, normal, full, extra` |
| `sqlite` | `cache_size` | `Int32` | `-4000` | `cache_size` | none |
| `sqlite` | `foreign_keys?` | `Bool` | `true` | `foreign_keys` (`1` / `0`) | none |
| `sqlite` | `busy_timeout` | `Int32` (ms) | `5000` | `busy_timeout` | `sqlite_busy_timeout must be non-negative` |

## `cache`

`config.cache` is a `CacheConfig`. Its environment defaults come from `ENV["CRYSTAL_ENV"]` when it is built, not from `config.env`; an unset `CRYSTAL_ENV` counts as development, any other unknown name keeps the plain defaults. It is validated only while `on` is true.

```crystal
CQL.configure do |c|
  c.cache.on = true
  c.cache.ttl = 10.minutes
  c.cache.key_prefix = "myapp"
  c.cache.name = "myapp"
  c.cache.memory_size = 2000
  c.cache.request_cache = true
  c.cache.request_size = 500
  c.cache.fragment_versions = true
  c.cache.fragment_tags = true
  c.cache.stats = true
  c.cache.invalidation = "transaction_aware"
  c.cache.max_age = 30.minutes
end
```

| Setting | Type | Default (dev / test / prod) | Used by | Validation message |
| :--- | :--- | :--- | :--- | :--- |
| `on` | `Bool` | `false` (`true` / `false` / `false`) | `CQL.build_schema`, `setup_cache_system`, `CQL.cache_on?` | none |
| `ttl` | `Time::Span` | `1.hour` | `Cache.default_ttl`, fragment cache TTL | `ttl must be positive` |
| `key_prefix` | `String` | `"cql"` | fragment cache keys | none |
| `name` | `String` | `"cql"` | `Cache.cache_name` | none |
| `memory_size` | `Int32?` | `1000` (`1000` / `100` / `5000`) | memory and fragment cache size | `memory_size must be positive` |
| `request_cache` | `Bool` | `true` | `CQL.start_request_cache`, `end_request_cache`, `with_request_cache` | none |
| `request_size` | `Int32` | `1000` (`1000` / `100` / `2000`) | validation only | `request_size must be positive` |
| `fragment_versions` | `Bool` | `true` | fragment cache `enable_versioning` | none |
| `fragment_tags` | `Bool` | `true` | fragment cache `enable_tagging` | none |
| `stats` | `Bool` | `true` | fragment cache `enable_statistics` | none |
| `invalidation` | `String` | `"timestamp"` | `timestamp`, `version` or `transaction_aware` strategy | `Invalid invalidation strategy: <value>` |
| `max_age` | `Time::Span` | `1.hour` | `timestamp` and `transaction_aware` strategies | none |

| Cache helper | Returns | Behavior |
| :--- | :--- | :--- |
| `CQL.cache_on(enabled = true)` | `Nil` | Sets `cache.on`; `true` also runs `setup_cache_system`. |
| `CQL.cache_on?` | `Bool` | `cache.on`. |
| `CQL.cache_stats` | `Hash(String, String \| Int32 \| Int64 \| Float64 \| Bool)` | `{"enabled" => false}` when off, else the settings above. |
| `CQL.cache_summary` | `String` | Text summary of the query and request caches. |
| `CQL.reset_cache!` | `Nil` | When `cache.on`: resets cache statistics and clears the request cache. |
| `CQL.memory_cache` | `CQL::Cache::MemoryCache` | New memory cache sized by `memory_size`. |
| `CQL.fragment_cache` | `CQL::Cache::FragmentCache` | New fragment cache from the settings above. |
| `CQL.start_request_cache(request_id = nil)`, `CQL.end_request_cache`, `CQL.with_request_cache(request_id = nil) { }` | `Nil` / block value | No-ops unless `cache.on` and `cache.request_cache`. |

See [Query caching](../how-to/caching/query-cache.md).

## Accepted but not read

These settings are accepted, and `timezone` is validated, but nothing in `src/` reads them.

| Block | Settings (default) |
| :--- | :--- |
| top level | `timezone` (`:utc`), `auto_load` (`true`; `false` in test and production), `sql_logging_async` (`false`; SQL logging is always synchronous) |
| `pool` | `query_timeout` (`30.seconds`; never emitted as a URL parameter) |
| `cache` | `memory` (`true`), `memory_stats` (`true`), `auto_clear` (`true`), `fragments` (`false`), `logging` (`false`; `true` in development), `log_level` (`Debug`; `Info` in production), `auto_cleanup` (`true`), `cleanup_interval` (`5.minutes`), `batch_ops` (`true`), `middleware` (`false`), `request_id_header` (`"X-Request-ID"`) |

`cache_stats` echoes `memory`, `request_cache` and `fragments`.

## Environment strategies

`Config.new` reads `CRYSTAL_ENV`, applies one strategy, and syncs `pool.size` from `pool_size`; `CQL.configure` then runs your block on top. Only `production`, `test` and `development` are recognised; unset or any other name (e.g. `staging`) gets the development strategy, except that `sql_logging` stays off until development is named.

| Setting | development | test | production |
| :--- | :--- | :--- | :--- |
| `db` | unchanged | `"sqlite3://:memory:"` | unchanged |
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
| `log_level` | `Debug` | `Error` | `Info` |
| `sql_logging` | `true` when named, unless `CQL_NO_SQL_LOG` | `false` | `false` |

{% hint style="warning" %}
The test strategy's `db` cannot be opened: `CQL.build_schema` raises `URI::Error` (`bad port`) on `sqlite3://:memory:`. Assign a file URL in test, e.g. `c.db = "sqlite3://./db/test.db"`.
{% endhint %}

{% hint style="warning" %}
With the test pool of 1, `migrator.up` and `down` with `auto_sync` on raise `CQL::Migrator::Error` ("Schema update failed: Could not check out a connection") after a 10-second wait. Use `c.pool_size = 2` or `CQL::MigratorConfig.new(auto_sync: false)` in test.
{% endhint %}

## Environment variables

| Variable | Read by | Effect |
| :--- | :--- | :--- |
| `CRYSTAL_ENV` | `Config#env`, `CacheConfig`, `CQL::Performance::Config` | Picks the environment. Unset means `development` (without SQL logging). |
| `CQL_NO_SQL_LOG` | `Config#sql_logging?` | Present (any value) and `sql_logging` never assigned: development does not log SQL. |
| `CQL_VALIDATE_SCHEMA_MAPPINGS` | model definitions | `1` checks model getter types and primary keys against the schema; a mismatch raises `CQL::ActiveRecord::SchemaMappingError`. The check is emitted from `macro finished`, so it runs after all other top-level code: a server that blocks in `listen` never reaches it. Run it from a spec or a script that only requires the models. |
| `NO_COLOR` | `CQL::Performance::SQLFormatter` | Present: SQL logging is not colorized. |
| `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD` | native PostgreSQL driver | Used when the URL has no host, port, user or password (defaults `localhost`, `5432`, `postgres`, none). |

`CQL.config` reads none of the cache store variables below; they apply only through `CQL::Cache::Cache.configure_from_env` or `CacheStoreConfig.from_env` (see [Redis cache](../how-to/caching/redis.md)). The performance monitor has its own options, set with `CQL::Performance.configure` or the variables below (see [Profile Queries](../how-to/observability/query-profiler.md)).

<details>
<summary>Cache store and performance monitor variables</summary>

| Variable | Read by | Effect |
| :--- | :--- | :--- |
| `CQL_CACHE_TYPE` | `CQL::Cache::CacheStoreConfig.from_env` | `redis` or `memory`. |
| `CQL_CACHE_TTL` | same | TTL in whole seconds. |
| `CQL_CACHE_PREFIX` | same | Key prefix. |
| `CQL_REDIS_URL`, then `REDIS_URL` | same | Redis URL; setting it selects the Redis store. |
| `CQL_REDIS_POOL_SIZE` | same | Redis pool size. |
| `CQL_REDIS_TIMEOUT` | same | Redis timeout in whole seconds. |
| `CQL_MEMORY_CACHE_MAX_SIZE` | same | Memory store max size. |
| `CQL_ENV` | `CQL::Performance::Config` | Alternative to `CRYSTAL_ENV` for the performance monitor's mode. |
| `CQL_MONITORING_ENABLED`, `CQL_SQL_LOGGING`, `CQL_SLOW_QUERY_MS` | `CQL::Performance::Config.from_env` | `true` / `true` / milliseconds. |

</details>

## Helpers

| Helper | Returns | Behavior |
| :--- | :--- | :--- |
| `config.adapter` | `CQL::Adapter` | From the `db` scheme; else `ArgumentError: Unsupported database URL: <url>`. |
| `config.db_config` | `DatabaseConfig` | The `postgres`, `mysql` or `sqlite` block for the adapter. |
| `config.full_db_url` | `String` | `db` plus the `pool`, `ssl`, database-specific and `adapter_options` parameters, in that order. A parameter already in `db` replaces the configured one. |
| `config.schema_path` | `String` | `File.join(schema_dir, schema_file)`. |
| `config.effective_logger` | `Log` | `logger` with `log_level` applied. |
| `config.migrator_config(schema_path:, schema_class:, schema_name:, migrations_table:, auto_sync:)` | `CQL::MigratorConfig` | Built from the settings; every keyword is optional and overrides one. |
| `config.migrator_config_for(env)` | `CQL::MigratorConfig` | `"production"`: `production_schema.cr`, `:ProductionSchema`, `:production_schema`, `:schema_migrations`, `auto_sync: false`. `"test"`: `test_schema.cr`, `:TestSchema`, `:test_schema`, `:test_migrations`, `auto_sync: true`. `"development"`: the configured values with `auto_sync: true`. Anything else: `migrator_config`. |
| `config.build_migrator(schema)` | `CQL::Migrator` | `schema.migrator(migrator_config)`, then `bootstrap` or `verify_schema` as configured. |
| `config.setup_sql_logging` | `Nil` | `CQL::Performance.enable_sql_logging(colorize: sql_logging_colorize)` when `sql_logging?`. |
| `config.setup_cache_system` | `Nil` | Applies `on`, `ttl` and `name` to `CQL::Cache::Cache` when `cache.on`. |
| `config.build_memory_cache`, `config.build_fragment_cache` | cache | Same as `CQL.memory_cache` / `CQL.fragment_cache`. |
| `config.cache_stats`, `config.cache_summary`, `config.reset_cache!` | | Same as the `CQL.` helpers. |
| `CQL.migrator_config(**args)`, `CQL.migrator_config_for(env)` | `CQL::MigratorConfig` | The same on the shared config. |
| `CQL.build_schema(name) { ... }` | `CQL::Schema` | `Schema.new(name, full_db_url, adapter)`, runs the block in the schema, then sets up the cache (`cache.on`) and SQL logging (`sql_logging?`). |
| `CQL.build_migrator(schema, custom_config = nil)` | `CQL::Migrator` | `config.build_migrator(schema)`; with `custom_config`, `schema.migrator(custom_config)`. |
| `CQL.bootstrap_schema(schema)` | `CQL::Migrator` | `build_migrator`, then `bootstrap_schema`. |
| `CQL.verify_schema(schema, auto_fix = false)` | `Bool` | `schema.migrator(migrator_config)` without the `bootstrap` / `verify_schema` step, then compares the schema file with the database: `false` for a stale file. With `auto_fix` and `auto_sync` on, rewrites a stale file and returns `true`. |

```crystal
# CRYSTAL_ENV=development, c.db = "postgres://app@localhost/app"
CQL.config.full_db_url
# => "postgres://app@localhost/app?initial_pool_size=2&max_pool_size=5&max_idle_pool_size=3&checkout_timeout=10.0
#     &retry_attempts=3&retry_delay=1.0&prepared_statements=true&sslmode=prefer&auth_methods=scram-sha-256%2Cmd5"
```

```crystal
AppDB = CQL.build_schema(:app_db) do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String
  end
end
migrator = CQL.build_migrator(AppDB)
```

`CQL::MigratorConfig.new` alone defaults to `src/schemas/app_schema.cr`, `:AppSchema`, `:app_schema`, table `:cql_schema_migrations` and `auto_sync: true`, which is what plain `schema.migrator` uses; see [build_migrator versus schema.migrator](../how-to/configuration/configure-cql.md#build_migrator-versus-schemamigrator).

## See Also

- [Configure CQL](../how-to/configuration/configure-cql.md)
- [Configure Database Connection](../how-to/configuration/database-connection.md)
- [Configure Multiple Environments](../how-to/configuration/environments.md)
- [Set Up Connection Pooling](../how-to/configuration/connection-pooling.md)
- [Enable SSL Connections](../how-to/configuration/ssl.md)
- [Migration DSL](api/migration-dsl.md)
