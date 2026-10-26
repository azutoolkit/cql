# CQL Examples

Runnable programs that exercise CQL. Most need no database server: they use SQLite or no database at all.

```bash
shards install --ignore-crystal-version                  # once
crystal run examples/basic/simple_cache_demo.cr           # one example
```

> [!IMPORTANT]
> Run everything from the repository root. The examples require `../../src/cql` and write their SQLite files to
> paths such as `examples/cache_example.db` or `./db/cache_example.db`, relative to the current directory.

| Directory | What it shows | Needs |
| --- | --- | --- |
| [basic/](basic/README.md) | memory cache, fragment cache and invalidation strategies; a Redis cache | Redis for one example |
| [caching/](caching/README.md) | fragment caching on models, per-request query cache, cache configuration, Redis store | SQLite; Redis for one example |
| [configuration/](configuration/README.md) | `CQL.configure` settings and migrator configuration | nothing (one example reads `DATABASE_URL`) |
| [migrations/](migrations/README.md) | migrations with a schema file kept in sync: up, rollback, redo | PostgreSQL |
| [framework-integration/](framework-integration/README.md) | the Azu per-request cache middleware, with mock requests | SQLite |
| [utilities/](utilities/README.md) | `Beautify`, the console helpers several examples print with | nothing |

## Status

Checked with Crystal 1.22.0: every program here compiles with `crystal build --no-codegen`, and the SQLite and Redis
examples were also run.

| Example | Result |
| --- | --- |
| everything not listed below | compiles and runs |
| `migrations/generated_schema.cr`, `utilities/beautify.cr` | not programs: a sample generated schema file and a helper module |
| `configuration/configuration_showcase.cr` | runs only with `DATABASE_URL` set (any value; nothing connects), otherwise raises `KeyError` |
| `migrations/schema_migration_workflow_pg.cr` | compiles; needs a PostgreSQL server (not run) |

`caching/advanced_caching_example.cr` prints nothing unless you pass it `run`.

For a complete application, follow the [Building a Blog tutorial](../docs/tutorials/building-a-blog/01-project-setup.md);
its code runs end to end.

## See Also

- [Documentation](../docs/README.md), with the [tutorials](../docs/tutorials/README.md) and
  [how-to guides](../docs/how-to/README.md)
- [Playground](../playground/README.md): a tour of the query DSL in one file
