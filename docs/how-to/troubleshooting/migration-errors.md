# Fix Migration Errors

This guide helps you diagnose and fix common migration errors.

## Common Error: Table Already Exists

**Error:**
```
relation "users" already exists
```

**Cause:** Another statement created the table (for example a raw `CREATE TABLE`, or a hand-written `schema.exec`). `Table#create!` itself emits `CREATE TABLE IF NOT EXISTS`, so it will not raise this error.

**Solutions:**

1. Check migration status:
```crystal
migrator.applied_migrations.each { |record| puts "#{record.version} #{record.name}" }
migrator.print_pending_migrations
```

2. CQL has no "mark as applied" helper. If the table exists and is correct, insert the version into the migrations table (`cql_schema_migrations` by default, columns `name`, `version`):
```crystal
schema.exec("INSERT INTO cql_schema_migrations (name, version) VALUES ('CreateUsers', 1)")
```

3. Drop and recreate (development only; `drop!` is `DROP TABLE IF EXISTS`):
```crystal
schema.users.drop!
```

## Common Error: Table Does Not Exist

**Error:**
```
relation "users" does not exist
```

**Cause:** Trying to alter or reference a table that wasn't created.

**Solutions:**

1. Run migrations in order:
```crystal
migrator.up  # Run all pending migrations
```

2. Check migration order - ensure create comes before alter

## Common Error: Column Already Exists

**Error:**
```
column "email" of relation "users" already exists
```

**Solutions:**

1. Check whether the migration already ran (`migrator.applied_migrations`), or whether the column was added by hand. CQL has no `column_exists?` helper; the table's declared columns are in `schema.tables[:users].columns`, which mirrors the schema definition, not necessarily the live database.

2. Remove the column first if replacing:
```crystal
def up
  schema.alter :users do
    drop_column :email
    add_column :email, String, null: false
  end
end
```

`drop_column` on a column the table definition does not know only logs an error and emits no SQL.

## Common Error: Cannot Drop Column

**Error:**
```
cannot drop column "user_id" because other objects depend on it
```

**Cause:** Foreign key or index depends on the column. (SQLite cannot drop foreign keys at all and raises `CQL::SQLiteUnsupportedFeatureError`; rebuild the table.)

**Solutions:**

1. Drop dependencies first:
```crystal
def up
  schema.alter :posts do
    drop_foreign_key :fk_posts_user_id   # default name is fk_<table>_<columns>
    drop_index :idx_posts_user_id
    drop_column :user_id
  end
end
```

## Common Error: Null Constraint Violation

**Error:**
```
column "name" contains null values
```

**Cause:** Adding NOT NULL column to table with existing data.

**Solutions:**

1. Add with default value:
```crystal
schema.alter :users do
  add_column :name, String, null: false, default: "Unknown"
end
```

2. Add as nullable, update, then add constraint:
```crystal
def up
  schema.alter :users do
    add_column :name, String, null: true
  end

  schema.exec("UPDATE users SET name = 'Unknown' WHERE name IS NULL")

  # change_column only takes a name and a type; to add NOT NULL use raw SQL
  schema.exec("ALTER TABLE users ALTER COLUMN name SET NOT NULL")   # PostgreSQL / CockroachDB
end
```

## Common Error: Foreign Key Violation

**Error:**
```
insert or update on table "posts" violates foreign key constraint
```

**Cause:** Referenced record doesn't exist.

**Solutions:**

1. Ensure parent records exist first
2. Set foreign key to nullable:
```crystal
bigint :user_id, null: true
```

3. Use ON DELETE CASCADE or SET NULL (the column must be nullable for `:set_null`):
```crystal
foreign_key [:user_id], references: :users, on_delete: :set_null
```

## Debugging Migrations

```crystal
migrator = MyDB.migrator(config)

puts "Applied migrations: #{migrator.applied_migrations.map(&.version)}"
puts "Pending migrations: #{migrator.pending_migrations.map(&.version)}"
puts "Current version: #{migrator.last.try(&.version) || 0}"
```

## Reset Database (Development Only)

```crystal
def reset_database
  migrator = MyDB.migrator(config)

  puts "Rolling back all migrations..."
  migrator.down   # no argument: roll back every applied migration

  puts "Running all migrations..."
  migrator.up

  puts "Database reset complete"
end
```

## Migration Raised Mid-Run

On SQLite and PostgreSQL, `migrator.up` and `migrator.down` run all migrations in one database transaction, so a failing migration rolls back everything that run did (including the recorded versions). MySQL and CockroachDB commit each statement on its own, so a failure there leaves the earlier migrations of the run applied and recorded; follow the steps below.

## Stuck Migration

If a migration failed halfway:

1. Check what was created:
```crystal
# Tables CQL knows about (the schema definition, not the live database)
schema.tables.keys
```

2. Manually fix state:
```sql
-- Remove from migration tracking
DELETE FROM cql_schema_migrations WHERE version = 5;
-- (the table name is MigratorConfig#migration_table_name)
```

3. Drop partially created objects:
```crystal
schema.partial_table.drop!   # DROP TABLE IF EXISTS
```

4. Re-run migration:
```crystal
migrator.up
```

## Common Error: Schema File Cannot Be Written

**Error:**
```
Migrator::Error: Schema update failed: ...
```

**Cause:** With `auto_sync: true` (the default), `up` and `down` rewrite the schema file at `MigratorConfig#schema_file_path`. A missing directory or unwritable path fails the run.

**Solutions:** Create the directory, point `schema_file_path` somewhere writable, or pass `auto_sync: false`.

## Related

- [Create a Migration](../migrations/create-migration.md)
- [Run Migrations](../migrations/run-migrations.md)
- [Rollback Migrations](../migrations/rollback.md)
