# Migration and Schema Examples

Four migrations run through `CQL::Migrator` with `auto_sync`, so that a Crystal schema file is rewritten after every
change. Run from the repository root.

```bash
crystal run examples/migrations/schema_migration_workflow.cr                    # SQLite
DATABASE_URL=postgres://user:pass@localhost/scratch \
  crystal run examples/migrations/schema_migration_workflow_pg.cr               # PostgreSQL
```

| File | What it is |
| --- | --- |
| `schema_migration_workflow.cr` | the workflow on SQLite (`examples/app_example.db`) |
| `schema_migration_workflow_pg.cr` | the same workflow on PostgreSQL; `DATABASE_URL` defaults to `postgresql://localhost/cql_example_db` |
| `generated_schema.cr` | a sample of a generated schema file (a `schema_migrations` table only). It is not a program: it has no `require` |

> [!WARNING]
> On SQLite the workflow stops at the first migration with `attempt to write a readonly database`, then exits 0. It
> deletes `examples/app_example.db` (line 122) after `AppDB` has already opened that file, so every later write
> fails. Until the example is fixed, read it for the calls it makes.

Both files define the same migrations:

| Migration | Change |
| --- | --- |
| `CreateUsersTable < CQL::Migration(1)` | `users`: `id`, `name`, `email`, timestamps |
| `AddEmailIndex < CQL::Migration(2)` | `create_index :email_idx, [:email], unique: true` in `schema.alter :users` |
| `CreatePostsTable < CQL::Migration(3)` | `posts`: `id`, `title`, `content`, `user_id` with a foreign key, timestamps |
| `AddPublishedToPosts < CQL::Migration(4)` | `add_column :published, Bool, default: false` in `schema.alter :posts` |

and drive them in this order:

```crystal
config = CQL::MigratorConfig.new(
  schema_file_path: "examples/generated_app_schema.cr",
  schema_name: :GeneratedAppSchema,
  schema_symbol: :generated_app_schema,
  auto_sync: true # rewrite the schema file after each migration
)
migrator = AppDB.migrator(config)

migrator.pending_migrations        # the four migrations
migrator.up                        # apply them
migrator.verify_schema_consistency # compare the schema file with the database
migrator.rollback                  # undo the last one (AddPublishedToPosts)
migrator.redo                      # rollback, then up
migrator.update_schema_file        # regenerate the file on demand
```

Each workflow then prints team-workflow notes and `MigratorConfig` values for development, production and test, and
deletes `examples/generated_app_schema.cr` when it ends: the SQLite one also deletes its database file, the
PostgreSQL one drops its tables.

> [!CAUTION]
> `schema_migration_workflow_pg.cr` runs `DROP TABLE IF EXISTS ... CASCADE` on `posts`, `users` and
> `schema_migrations` when it starts and again when it ends. Point `DATABASE_URL` at a scratch database.

The PostgreSQL file requires the `pg` shard before CQL, so the `pg` shard's driver serves its connection rather than
CQL's own. Its lines about JSONB, array and UUID columns are printed text. It was checked with
`crystal build --no-codegen` only.

## See Also

- [Create a Migration](../../docs/how-to/migrations/create-migration.md)
- [Run Migrations](../../docs/how-to/migrations/run-migrations.md)
- [Rollback Migrations](../../docs/how-to/migrations/rollback.md)
- [Dump and Validate Your Schema](../../docs/how-to/migrations/schema-dump-and-validation.md)
- [Migration Workflows](../../docs/tutorials/real-world-examples/migration-workflows.md)
