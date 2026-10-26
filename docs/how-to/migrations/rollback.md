# Rollback Migrations

This guide shows you how to rollback database migrations.

## Rollback Last Migration

```crystal
migrator = MyDB.migrator(config)
migrator.rollback
puts "Rolled back one migration"
```

`rollback(steps = 1)` rolls back the newest applied migration. Note that `down(steps)` defaults to **all** migrations, so call `migrator.down` without an argument only when you mean to undo everything. On SQLite and PostgreSQL the whole rollback runs in one transaction; on MySQL and CockroachDB each statement commits on its own. It prints a table of the migrations it reverted.

## Rollback Multiple Migrations

```crystal
# Rollback last 3 migrations
migrator.rollback(3)
```

## Rollback to Specific Version

Count the applied migrations newer than the target and roll back that many:

```crystal
target = 5_i64
steps = migrator.applied_migrations.count { |record| record.version > target }
migrator.rollback(steps) if steps > 0
```

`migrator.down_to(version)` exists, but it rolls back `position + 1` migrations, where `position` is the index of `version` in the ordered list of all registered migrations. That only equals "roll back to `version`" for some layouts, so prefer the explicit count above.

## Rollback All Migrations

```crystal
# Rollback everything (use with caution!)
migrator.down
```

## Check Before Rollback

```crystal
puts "Current version: #{migrator.last.try(&.version) || 0}"
puts "Applied migrations: #{migrator.applied_migrations.size}"

# Only rollback if there are migrations to rollback
if migrator.applied_migrations.any?
  migrator.rollback
  puts "Rolled back to version: #{migrator.last.try(&.version) || 0}"
else
  puts "No migrations to rollback"
end
```

## Safe Rollback Script

```crystal
# src/rollback.cr
require "./database"
require "../migrations/*"

config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  auto_sync: true
)

migrator = MyDB.migrator(config)

current = migrator.last.try(&.version) || 0_i64
puts "Current version: #{current}"

if current == 0
  puts "No migrations to rollback"
  exit 0
end

print "Rollback migration #{current}? (y/n): "
if gets.try(&.strip) == "y"
  migrator.rollback
  puts "Rolled back to version: #{migrator.last.try(&.version) || 0}"
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

When you try to rollback, the exception aborts the rollback and, on SQLite and PostgreSQL, nothing is reverted:

```crystal
begin
  migrator.rollback
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
  migrator.down

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
migrator.rollback

# Verify
after = migrator.applied_migrations.size
puts "Rolled back: #{before} -> #{after} migrations"
```

## Related

- [Create a Migration](create-migration.md)
- [Run Migrations](run-migrations.md)
- [Migration DSL Reference](../../reference/api/migration-dsl.md)
