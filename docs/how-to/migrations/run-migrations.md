# Run Migrations

This guide shows you how to run database migrations.

## Setup Migrator

```crystal
require "cql"
require "../migrations/*"

config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  auto_sync: true
)

migrator = MyDB.migrator(config)
```

Creating a migrator creates the migrations table (`config.migration_table_name`, default `cql_schema_migrations`). With `auto_sync: true` (the default) `up` and `down` also write the schema file at `schema_file_path` from the database state when they finish; creating the migrator does not write it. Pass `auto_sync: false` to leave the file alone, which is usually what you want in production. Otherwise make sure the directory of `schema_file_path` exists.

Only migration classes that have been required are registered, so require your migrations before calling `migrator.up`.

## Run All Pending Migrations

```crystal
migrator.up
puts "Migrations complete"
```

Pending migrations run in version order and are recorded as they succeed. On SQLite and PostgreSQL the whole run, `schema_migrations` records included, is one transaction on one connection, so a failing migration rolls back everything the run did. On MySQL and CockroachDB each statement commits on its own, so a failure leaves the earlier migrations of the run applied, and building a migrator, calling `up` or listing `pending_migrations` inside an open transaction raises `CQL::DialectError`. On PostgreSQL the run holds its DDL locks until the final commit and `CREATE INDEX CONCURRENTLY` fails inside a migration; `up(steps)` keeps runs short. `migrator.up(2)` applies the 2 oldest pending migrations. `up` prints a table of applied migrations when it finishes.

## Check Migration Status

```crystal
puts "Applied: #{migrator.applied_migrations.size}"
puts "Pending: #{migrator.pending_migrations.size}"
migrator.print_pending_migrations   # table of pending migrations
migrator.print_applied_migrations   # table of applied migrations
```

## Run to Specific Version

```crystal
# Run every migration up to and including version 5 (an Int64)
migrator.up_to(5_i64)
```

`up_to` applies the pending migrations up to that version and skips the ones already applied. It raises `CQL::Migrator::Error` ("No migration with version 5") if no registered migration has that version.

## Create Migration Script

```crystal
# src/migrate.cr
require "./database"
require "../migrations/*"

config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  auto_sync: true
)

migrator = MyDB.migrator(config)

case ARGV[0]?
when "up"
  migrator.up
  puts "Migrated up"
when "down"
  migrator.rollback   # one migration; `migrator.down` with no argument rolls back all of them
  puts "Rolled back one migration"
when "status"
  puts "Applied: #{migrator.applied_migrations.size}"
  puts "Pending: #{migrator.pending_migrations.size}"
when "version"
  puts "Current version: #{migrator.last.try(&.version) || 0}"
else
  puts "Usage: crystal src/migrate.cr [up|down|status|version]"
end
```

## Run From Command Line

```shell
# Run all pending migrations
crystal src/migrate.cr up

# Check status
crystal src/migrate.cr status

# Rollback one migration
crystal src/migrate.cr down
```

## Auto-Run on Startup

Run migrations when your app starts:

```crystal
# src/app.cr
require "./database"
require "../migrations/*"

def setup_database
  config = CQL::MigratorConfig.new(
    schema_file_path: "src/schemas/app_schema.cr",
    schema_name: :AppSchema,
    auto_sync: true
  )

  migrator = MyDB.migrator(config)

  pending = migrator.pending_migrations.size
  if pending > 0
    puts "Running #{pending} pending migration(s)..."
    migrator.up
  end
end

setup_database
# ... rest of your app
```

## Verify Migrations Ran

```crystal
migrator = MyDB.migrator(config)
migrator.up

# Verify
puts "Applied migrations:"
migrator.applied_migrations.each do |record|
  puts "  - #{record.version} #{record.name}"
end
```

## Related

- [Create a Migration](create-migration.md)
- [Rollback Migrations](rollback.md)
- [Migration DSL Reference](../../reference/api/migration-dsl.md)
