# Fix Migration Errors

This guide helps you diagnose and fix common migration errors.

## Common Error: Table Already Exists

**Error:**
```
relation "users" already exists
```

**Cause:** Running migration twice or table was created manually.

**Solutions:**

1. Check migration status:
```crystal
puts migrator.applied_migrations
```

2. Mark migration as applied (if table exists and is correct):
```crystal
migrator.mark_as_applied(migration_number)
```

3. Drop and recreate (development only):
```crystal
schema.users.drop! if schema.table?(:users)
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

1. Check if column exists before adding:
```crystal
def up
  unless schema.column_exists?(:users, :email)
    schema.alter :users do
      add_column :email, String
    end
  end
end
```

2. Remove the column first if replacing:
```crystal
def up
  schema.alter :users do
    drop_column :email if column_exists?(:email)
    add_column :email, String, null: false
  end
end
```

## Common Error: Cannot Drop Column

**Error:**
```
cannot drop column "user_id" because other objects depend on it
```

**Cause:** Foreign key or index depends on the column.

**Solutions:**

1. Drop dependencies first:
```crystal
def up
  schema.alter :posts do
    drop_foreign_key [:user_id]
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

  schema.alter :users do
    change_column :name, String, null: false
  end
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

3. Use ON DELETE CASCADE or SET NULL:
```crystal
foreign_key [:user_id], references: :users, on_delete: :set_null
```

## Debugging Migrations

```crystal
migrator = MyDB.migrator(config)

puts "Applied migrations: #{migrator.applied_migrations}"
puts "Pending migrations: #{migrator.pending_migrations}"
puts "Current version: #{migrator.current_version}"
```

## Reset Database (Development Only)

```crystal
def reset_database
  migrator = MyDB.migrator(config)

  puts "Rolling back all migrations..."
  migrator.down_to(0)

  puts "Running all migrations..."
  migrator.up

  puts "Database reset complete"
end
```

## Stuck Migration

If a migration failed halfway:

1. Check what was created:
```crystal
# List tables
schema.tables
```

2. Manually fix state:
```sql
-- Remove from migration tracking
DELETE FROM cql_schema_migrations WHERE version = 5;
```

3. Drop partially created objects:
```crystal
schema.partial_table.drop! if schema.table?(:partial_table)
```

4. Re-run migration:
```crystal
migrator.up
```

## Related

- [Create a Migration](../migrations/create-migration.md)
- [Run Migrations](../migrations/run-migrations.md)
- [Rollback Migrations](../migrations/rollback.md)
