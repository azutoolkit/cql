---
description: "Find the error your migration raised, then apply its fix."
---

# Fix Migration Errors

Check which migrations have run first, as in [Check Status](../migrations/run-migrations.md#check-status). SQLite messages below come from SQLite. PostgreSQL errors go through CQL's native driver, which prints a fixed title for SQLSTATE classes whose server text can quote values; the server's own text is in `server_message`:

```crystal
begin
  migrator.up
rescue ex : CQL::Postgres::ServerError # the PostgreSQL errors below inherit from it
  ex.message        # => "ERROR: syntax error or access rule violation (SQLSTATE 42P07)"
  ex.sqlstate       # => "42P07"
  ex.server_message # => "relation \"users\" already exists"; may quote bound values
end
```

## Table already exists

```text
SQLite3::Exception: table users already exists
CQL::Postgres::SyntaxOrAccessError: ERROR: syntax error or access rule violation (SQLSTATE 42P07)
```

**Cause:** a raw `CREATE TABLE` ran on a table that exists. `Table#create!` emits `CREATE TABLE IF NOT EXISTS`, so it never raises this. If the table is correct and only the record is missing, record the version by hand (CQL has no helper):

```crystal
# CQL.build_migrator records in schema_migrations (test_migrations in test), AppDB.migrator in cql_schema_migrations
AppDB.exec("INSERT INTO schema_migrations (name, version) VALUES ('CreateUsers', 1)")
```

## Table not found

```text
CQL::Schema::Error: Table 'comments' not found
SQLite3::Exception: no such table: comments
CQL::Postgres::UndefinedTable: ERROR: undefined table (SQLSTATE 42P01)
```

**Cause:** the first comes from `schema.alter :comments` when the schema block does not declare `comments`; declare it. The others mean the table was never created: run the migration that creates it first (versions run in ascending order).

## Column already exists

```text
SQLite3::Exception: duplicate column name: email
CQL::Postgres::SyntaxOrAccessError: ERROR: syntax error or access rule violation (SQLSTATE 42701)
```

**Cause:** the migration already ran, or the column was added by hand:

```crystal
migrator.applied_migrations.map(&.version) # did the migration run?
schema.tables[:users].columns.keys         # the schema's declaration, not the live database
```

## Adding a NOT NULL column fails

```text
SQLite3::Exception: Cannot add a NOT NULL column with default value NULL
CQL::Postgres::NotNullViolation: ERROR: column "name" of relation "users" contains null values (SQLSTATE 23502)
```

```crystal
# ✅ add_column ignores default:, so write the column in SQL with its default
schema.exec("ALTER TABLE users ADD COLUMN name TEXT NOT NULL DEFAULT 'Unknown'")
```

[Add a Column With a Default](../migrations/add-columns.md#add-a-column-with-a-default) explains the cause and the nullable-then-backfill alternative.

## Column cannot be dropped

```text
CQL::Postgres::ServerError: ERROR: server error (SQLSTATE 2BP01)
CQL::SQLiteUnsupportedFeatureError: SQLite does not support dropping foreign keys
```

**Cause:** a foreign key or index depends on the column (2BP01). Drop them first:

```crystal
schema.alter :posts do
  drop_foreign_key :fk_posts_user_id # name CQL gives a key added with alter; a key declared in a
                                     # table block is named by the database (PostgreSQL: posts_user_id_fkey)
  drop_index :idx_posts_user_id      # the default name for index [:user_id] on posts
  drop_column :user_id
end
# ALTER TABLE posts DROP CONSTRAINT fk_posts_user_id; DROP INDEX IF EXISTS idx_posts_user_id; ALTER TABLE posts DROP COLUMN user_id;
```

`drop_column` on a column the schema does not declare only logs `Column nope does not exist in table ...` and emits no SQL. SQLite cannot drop foreign keys or change column types (`SQLite does not support ALTER COLUMN syntax`), so rebuild the table:

```crystal
# SQLite, in a migration: rebuild posts without user_id (or with a new column type)
schema.exec("CREATE TABLE posts_new (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL)")
schema.exec("INSERT INTO posts_new (id, title) SELECT id, title FROM posts")
schema.exec("DROP TABLE posts")
schema.exec("ALTER TABLE posts_new RENAME TO posts")
```

## Foreign key violation

```text
SQLite3::Exception: FOREIGN KEY constraint failed
CQL::Postgres::ForeignKeyViolation: ERROR: insert or update on table "posts" violates foreign key constraint "posts_user_id_fkey" (SQLSTATE 23503)
```

**Cause:** a row points at a parent that does not exist. Insert parents first, or make the column nullable and use `on_delete: :set_null`. SQLite checks foreign keys only with `foreign_keys=1`, which `CQL.build_schema` adds.

## Schema update failed

```text
CQL::Migrator::Error: Schema update failed: Could not check out a connection in 10.0 seconds
CQL::Migrator::Error: Schema update failed: Unable to create directory: 'db/schema': File exists
```

**Cause:** with `auto_sync` on, the migrator dumps the schema file after `up` and `down`. The dump needs two connections, so a pool of one (the test default) times out; a path under an existing file cannot be created.

```crystal
CQL.configure { |c| c.pool_size = 2 } # or migrate with CQL::MigratorConfig.new(auto_sync: false)
```

## A migration raised mid-run

{% tabs %}
{% tab title="SQLite and PostgreSQL" %}
One `migrator.up` or `migrator.down` runs in a single transaction: a failure rolls back the whole run, recorded versions included, so fix the migration and run `up` again.
{% endtab %}

{% tab title="MySQL and CockroachDB" %}
Each statement commits, so earlier migrations of the run stay applied. Recover by hand:

```crystal
schema.tables.keys                                        # tables the schema declares (not the live database)
schema.exec("DELETE FROM schema_migrations WHERE version = 5") # table: migrator.config.migration_table_name
schema.partial_table.drop!                                # DROP TABLE IF EXISTS partial_table
migrator.up
```
{% endtab %}
{% endtabs %}

To start a development database over, see [Refresh a Development Database](../migrations/rollback.md#refresh-a-development-database).

## See Also

- [Create a Migration](../migrations/create-migration.md)
- [Run Migrations](../migrations/run-migrations.md)
- [Add Columns](../migrations/add-columns.md)
- [Rollback Migrations](../migrations/rollback.md)
- [Configure CQL](../configuration/configure-cql.md#build_migrator-versus-schemamigrator)
- [Fix Connection Errors](connection-errors.md)
