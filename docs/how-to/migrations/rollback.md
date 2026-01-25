# Rollback Migrations

This guide shows you how to rollback database migrations.

## Rollback Last Migration

```crystal
migrator = MyDB.migrator(config)
migrator.down
puts "Rolled back one migration"
```

## Rollback Multiple Migrations

```crystal
# Rollback last 3 migrations
3.times { migrator.down }
```

## Rollback to Specific Version

```crystal
# Rollback to version 5
migrator.down_to(5)
```

## Rollback All Migrations

```crystal
# Rollback everything (use with caution!)
migrator.down_to(0)
```

## Check Before Rollback

```crystal
puts "Current version: #{migrator.current_version}"
puts "Applied migrations: #{migrator.applied_migrations.size}"

# Only rollback if there are migrations to rollback
if migrator.applied_migrations.any?
  migrator.down
  puts "Rolled back to version: #{migrator.current_version}"
else
  puts "No migrations to rollback"
end
```

## Safe Rollback Script

```crystal
# src/rollback.cr
require "./database"
require "../migrations/*"

MyDB.init

config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  auto_sync: true
)

migrator = MyDB.migrator(config)

current = migrator.current_version
puts "Current version: #{current}"

if current == 0
  puts "No migrations to rollback"
  exit 0
end

print "Rollback migration #{current}? (y/n): "
if gets.try(&.strip) == "y"
  migrator.down
  puts "Rolled back to version: #{migrator.current_version}"
else
  puts "Cancelled"
end
```

## Handle Irreversible Migrations

Some migrations can't be rolled back:

```crystal
class DropLegacyTable < CQL::Migration(10)
  def up
    schema.legacy_users.drop!
  end

  def down
    # Can't restore dropped table with data
    raise "Cannot rollback: table was dropped with data"
  end
end
```

When you try to rollback:

```crystal
begin
  migrator.down
rescue ex
  puts "Rollback failed: #{ex.message}"
end
```

## Refresh Database

Rollback all and re-migrate (development only):

```crystal
def refresh_database
  migrator = MyDB.migrator(config)

  puts "Rolling back all migrations..."
  migrator.down_to(0)

  puts "Re-running all migrations..."
  migrator.up

  puts "Database refreshed"
end
```

## Verify Rollback

```crystal
migrator = MyDB.migrator(config)

# Record current state
before = migrator.applied_migrations.size

# Rollback
migrator.down

# Verify
after = migrator.applied_migrations.size
puts "Rolled back: #{before} -> #{after} migrations"
```

## Related

- [Create a Migration](create-migration.md)
- [Run Migrations](run-migrations.md)
- [Migration DSL Reference](../../reference/api/migration-dsl.md)
