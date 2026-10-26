# Run Migrations

Build a migrator for your schema, apply the pending migrations, and check what has run.

## Build the Migrator

```crystal
require "./database"           # defines AppDB
require "../db/migrations/*"   # registers every migration class

config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  auto_sync: true              # the default
)
migrator = AppDB.migrator(config)

config.migration_table_name    # => :cql_schema_migrations, created by AppDB.migrator
```

With `auto_sync: true`, the migrator writes the schema file from the live database when it is built and after every
`up` and `down`, creating missing directories. Pass `auto_sync: false` in production and in tests so the file is left
alone.

## Apply Pending Migrations

```crystal
migrator.up             # every pending migration, in version order, then prints the applied table
migrator.up(2)          # only the first 2 registered migrations; applied ones count towards the 2
migrator.up_to(5_i64)   # every migration up to and including version 5; nothing if no migration has that version
```

On SQLite and PostgreSQL the whole run, migration records included, is one transaction on one connection: a failing
migration rolls back everything the run did. On MySQL and CockroachDB each statement commits on its own, so a failure
leaves the run's earlier migrations applied, and building a migrator or calling `up` inside an open transaction raises
`CQL::DialectError`.

{% hint style="warning" %}
On PostgreSQL a run holds its DDL locks until the final commit, and `CREATE INDEX CONCURRENTLY` fails inside a migration. Use `up(steps)` or `up_to` to keep runs short.
{% endhint %}

## Check Status

```crystal
migrator.applied_migrations.size                    # rows in cql_schema_migrations
migrator.pending_migrations.map(&.version)          # => [4, 5]
migrator.applied_migrations.max_of?(&.version) || 0 # current version
migrator.last.try(&.name)                           # => "CreateComments", the last recorded one

migrator.applied_migrations.each { |record| puts "#{record.version} #{record.name}" }
migrator.print_pending_migrations                   # table of pending migrations
migrator.print_applied_migrations
```

## Write a Migration Command

```crystal
# src/migrate.cr
require "./database"
require "../db/migrations/*"

migrator = AppDB.migrator(CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  auto_sync: ENV["APP_ENV"]? != "production"
))

case ARGV[0]?
when "up"      then migrator.up
when "status"  then puts "Applied: #{migrator.applied_migrations.size}, pending: #{migrator.pending_migrations.size}"
when "version" then puts migrator.applied_migrations.max_of?(&.version) || 0
else                abort "Usage: crystal src/migrate.cr up|status|version"
end
```

```bash
crystal src/migrate.cr up
crystal src/migrate.cr status    # Applied: 5, pending: 0
```

[Rollback Migrations](rollback.md) adds a `rollback` command.

## Migrate on Startup

```crystal
# src/app.cr
migrator = AppDB.migrator(CQL::MigratorConfig.new(auto_sync: false))
unless migrator.pending_migrations.empty?
  puts "Running #{migrator.pending_migrations.size} pending migration(s)..."
  migrator.up
end
```

{% hint style="info" %}
`CQL.build_migrator(schema)` reads its settings from `CQL.configure` and by default records migrations in `schema_migrations`, not `cql_schema_migrations`. See [build_migrator versus schema.migrator](../configuration/configure-cql.md#build_migrator-versus-schemamigrator).
{% endhint %}

## See Also

- [Create a Migration](create-migration.md)
- [Rollback Migrations](rollback.md)
- [Dump and Validate Your Schema](schema-dump-and-validation.md)
- [Fix Migration Errors](../troubleshooting/migration-errors.md)
- [Migration DSL Reference](../../reference/api/migration-dsl.md)
