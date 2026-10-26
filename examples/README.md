# CQL Examples

Runnable programs that exercise CQL. Most need no database server: they use SQLite or no database at all.

```bash
shards install --ignore-crystal-version                  # once
crystal run examples/basic/simple_cache_demo.cr           # one example
crystal run examples/run_examples.cr -- --list            # every example the runner knows
crystal run examples/run_examples.cr -- -c caching        # run a category, report pass/fail
crystal run examples/run_examples.cr                      # interactive menu
```

> [!IMPORTANT]
> Run everything from the repository root. The examples require `../../src/cql` and write their SQLite files to
> paths such as `examples/blog/blog.db`, relative to the current directory.

| Directory | What it shows | Needs |
| --- | --- | --- |
| [basic/](basic/README.md) | memory cache, fragment cache and invalidation strategies; a Redis cache | Redis for one example |
| [caching/](caching/README.md) | fragment caching on models, per-request query cache, cache configuration, Redis store | SQLite; Redis for one example |
| [configuration/](configuration/README.md) | `CQL.configure` settings and migrator configuration | nothing (one example reads `DATABASE_URL`) |
| [migrations/](migrations/README.md) | migrations with a schema file kept in sync: up, rollback, redo | SQLite; PostgreSQL for one example |
| [performance/](performance/README.md) | the performance monitor and reports | see its README: none compile today |
| [framework-integration/](framework-integration/README.md) | the Azu per-request cache middleware, with mock requests | SQLite |
| [blog/](blog/README.md) | a blog app: migrations, seeders, models, CRUD, joins, aggregates, monitoring | SQLite |
| [utilities/](utilities/README.md) | `Beautify`, the console helpers several examples print with | nothing |

## Status

Checked with Crystal 1.22.0: every program here was compiled with `crystal build --no-codegen` (the blog's models,
migrations and demos as part of `blog_demo.cr`), and the SQLite and Redis examples were also run.

| Example | Result |
| --- | --- |
| everything not listed below | compiles and runs |
| `migrations/generated_schema.cr`, `utilities/beautify.cr` | not programs: a sample generated schema file and a helper module |
| `configuration/configuration_showcase.cr` | runs only with `DATABASE_URL` set (any value; nothing connects), otherwise raises `KeyError` |
| `blog/blog_demo.cr` | runs, and rewrites the tracked file `src/schemas/app_schema.cr`; see [blog/](blog/README.md) |
| `migrations/schema_migration_workflow.cr` | compiles, but stops at the first migration (`attempt to write a readonly database`) and exits 0; see [migrations/](migrations/README.md) |
| `migrations/schema_migration_workflow_pg.cr` | compiles; needs a PostgreSQL server (not run) |
| `blog/blog.cr` | does not compile: it requires `./blog/blog_demo`, which does not exist. Run `blog/blog_demo.cr` instead |
| `caching/with_cache_demo.cr` | does not compile: `CQL::Cache::Cache.with_cache` fails with "can't use Class in unions yet" |
| `performance/*.cr` | none of the four compiles; see [performance/](performance/README.md) |

`run_examples.cr` lists four files that do not exist (`performance/sql_log_formatter_example.cr`,
`sql_integration_example.cr`, `simple_sql_log_demo.cr`, `sql_log_demo.cr`), so those menu entries fail. It also runs
`caching/advanced_caching_example.cr` without the `run` argument that example needs, so that entry prints nothing.

## See Also

- [Documentation](../docs/README.md), with the [tutorials](../docs/tutorials/README.md) and
  [how-to guides](../docs/how-to/README.md)
- [Playground](../playground/README.md): a tour of the query DSL in one file
