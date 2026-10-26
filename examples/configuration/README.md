# Configuration Examples

`CQL.configure` settings for several environments, and the migrator configuration built from them. Neither example
opens a database connection.

```bash
DATABASE_URL=postgres://localhost/myapp crystal run examples/configuration/configuration_showcase.cr
crystal run examples/configuration/migrator_config_example.cr
```

| File | Shows |
| --- | --- |
| `configuration_showcase.cr` | five `CQL.configure` blocks: development (`db`, `log_level`, `auto_sync`), production (`env`, `db = ENV["DATABASE_URL"]`, `pool_size`, `monitor_performance`, `verify_schema`, `cache.*`), a cache-focused setup (`cache.request_cache`, `cache.fragments`, `cache.invalidation = "transaction_aware"`), test (`sqlite3::memory:`, `pool_size = 1`) and SQL logging (`sql_logging`, `sql_logging_colorize`). It then prints the old long property names next to the current ones |
| `migrator_config_example.cr` | `schema_dir`, `schema_file`, `schema_class`, `auto_sync`, `verify_schema`, `bootstrap` and `migrations_table`, per environment, then `CQL.migrator_config` and `CQL.migrator_config_for(env)` with their `schema_file_path`, `schema_name`, `migration_table_name` and `auto_sync?` |

`configuration_showcase.cr` reads `ENV["DATABASE_URL"]` and raises `KeyError` when it is unset; any value works,
because nothing connects. The production block it shows:

```crystal
CQL.configure do |config|
  config.env = "production"
  config.db = ENV["DATABASE_URL"]
  config.pool_size = 25
  config.monitor_performance = true
  config.auto_sync = false
  config.verify_schema = true
  config.cache.on = true
  config.cache.ttl = 1.hour
  config.cache.memory_size = 5000
end
```

For a new app, configure a schema through [Configure CQL](../../docs/how-to/configuration/configure-cql.md) rather
than copying these blocks: they set `CQL.config` but define no schema.

## See Also

- [Configuration Reference](../../docs/reference/configuration.md): every setting and its default
- [Configure Multiple Environments](../../docs/how-to/configuration/environments.md)
- [caching/cache_configuration_example.cr](../caching/README.md): the `cache.*` settings in more detail
- [migrations/](../migrations/README.md): a migrator that keeps a schema file in sync
