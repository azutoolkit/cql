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

Creating a migrator creates the migrations table (`config.migration_table_name`, default `cql_schema_migrations`). With `auto_sync: true` (the default) it also writes the schema file at `schema_file_path`, from the current database state, when the migrator is created and after every `up`/`down`. Pass `auto_sync: false` to leave the file alone, which is usually what you want in production. Otherwise make sure the directory of `schema_file_path` exists.

Only migration classes that have been required are registered, so require your migrations before calling `migrator.up`.

## Run All Pending Migrations

```crystal
migrator.up
puts "Migrations complete"
```

Pending migrations run in version order, and each is recorded once it succeeds. The migrator opens a transaction, but each migration's statements (and its recorded version) run on another pooled connection and commit on their own: a failing migration does not undo the ones before it, and a pool of size 1 deadlocks. `migrator.up(2)` runs at most the first 2 migrations in version order (already-applied ones count towards the 2). `up` prints a table of applied migrations when it finishes.

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

`up_to` does nothing if no registered migration has that version.

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
