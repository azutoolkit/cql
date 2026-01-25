# Run Migrations

This guide shows you how to run database migrations.

## Setup Migrator

```crystal
require "cql"
require "../migrations/*"

MyDB.init

config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  auto_sync: true
)

migrator = MyDB.migrator(config)
```

## Run All Pending Migrations

```crystal
migrator.up
puts "Migrations complete"
```

## Check Migration Status

```crystal
puts "Applied: #{migrator.applied_migrations.size}"
puts "Pending: #{migrator.pending_migrations.size}"
```

## Run to Specific Version

```crystal
# Run up to migration 5
migrator.up_to(5)
```

## Create Migration Script

```crystal
# src/migrate.cr
require "./database"
require "../migrations/*"

MyDB.init

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
  migrator.down
  puts "Rolled back one migration"
when "status"
  puts "Applied: #{migrator.applied_migrations.size}"
  puts "Pending: #{migrator.pending_migrations.size}"
when "version"
  puts "Current version: #{migrator.current_version}"
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
  MyDB.init

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
migrator.applied_migrations.each do |version|
  puts "  - #{version}"
end
```

## Related

- [Create a Migration](create-migration.md)
- [Rollback Migrations](rollback.md)
- [Migration DSL Reference](../../reference/api/migration-dsl.md)
