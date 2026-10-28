---
description: "Build a migrator for your schema, apply the pending migrations, and check what has run."
---

# Run Migrations

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

With `auto_sync: true`, every `up` and `down` rewrites the schema file from the live database, creating missing
directories; if that write fails, the run logs a warning and keeps the old file. Building the migrator writes nothing.
Pass `auto_sync: false` in production and in tests so the file is left alone.

## Apply Pending Migrations

```crystal
migrator.up             # every pending migration, in version order, then prints the applied table
migrator.up(2)          # the 2 oldest pending migrations
migrator.up_to(5_i64)   # every pending migration up to and including version 5; raises CQL::Migrator::Error
                        # if no migration has that version
```

{% tabs %}
{% tab title="SQLite and PostgreSQL" %}
The whole run, migration records included, is one transaction on one connection: a failing migration rolls back
everything the run did. A migration with `disable_ddl_transaction!` runs alone between two such transactions, so a
failure keeps what ran before it.
{% endtab %}

{% tab title="MySQL and CockroachDB" %}
Each statement commits on its own, so a failure leaves the run's earlier migrations applied. Inside an open transaction,
building a migrator raises `CQL::DialectError`, and so do `up`, `up_to`, `down`, `down_to` and `rollback` when they have a
migration to run; with nothing to do they return. Listing `pending_migrations` only reads.
{% endtab %}
{% endtabs %}

On PostgreSQL an advisory lock serialises migrators: `Migrator.new` takes it before it creates the migrations table, and
a run takes it when a first pick finds migrations to apply or roll back. A second `up` waits for the first, then applies
only the migrations it picked that are still pending, so it never applies one twice; when the first rolled back an
older migration meanwhile, it raises `CQL::Migrator::Error` instead of applying newer ones on top of it. A migration
with `disable_ddl_transaction!` runs outside the lock: run one migrator at a time while one is pending.
Building a migrator waits too while another process runs migrations. A run with nothing to pick takes no lock and no
check; listing `pending_migrations` takes no lock, runs no DDL and returns the snapshot of the transaction it runs in.

The wait lasts at most `lock_timeout` (60 seconds by default), then `CQL::Migrator::Error` names the migrations table
and nothing more runs (what the run committed before that wait stays). The bound replaces the server's `lock_timeout` for this wait, even a shorter one, and a bound under
1 ms counts as 1 ms (PostgreSQL reads 0 as no bound). It bounds only the wait for the lock: the migrations run under the
connection's own `lock_timeout`. `CQL.configure` has no setting for it: pass your `MigratorConfig` to `schema.migrator`
or as the second argument of `CQL.build_migrator`.

```crystal
CQL::MigratorConfig.new(lock_timeout: 5.minutes) # wait longer for another process's run
CQL::MigratorConfig.new(lock_timeout: nil)       # wait as long as the server's lock_timeout allows
```

Run migrations at READ COMMITTED: inside a REPEATABLE READ or SERIALIZABLE transaction, or under such a
`default_transaction_isolation`, building a migrator and a run that has migrations to apply or roll back raise
`CQL::Migrator::Error`.

A `down`, `down_to` or `rollback` raises `CQL::Migrator::Error` and rolls back nothing when its pick under the lock
differs from its pick before it, as when the run it waited for changed the applied migrations. `redo` locks its rollback
and its `up` separately, so two `redo`s can interleave: run those from one process. On SQLite a concurrent run fails with
`database is locked`. MySQL and CockroachDB take no migration lock, so two migrators can both apply a migration before
either records it: run migrations from one process.

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

{% code title="src/migrate.cr" %}
```crystal
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
{% endcode %}

```bash
crystal src/migrate.cr up
crystal src/migrate.cr status    # Applied: 5, pending: 0
```

[Rollback Migrations](rollback.md) adds a `rollback` command.

## Deploy One Migration at a Time

On SQLite and PostgreSQL, commit each migration with `up(1)` so that one failure does not undo the others:

{% code title="src/deploy_migrations.cr" %}
```crystal
require "./database"
require "../db/migrations/*"

migrator = AppDB.migrator(CQL::MigratorConfig.new(auto_sync: false))
pending = migrator.pending_migrations

if pending.empty?
  puts "No pending migrations"
  exit 0
end

pending.each do |migration|
  puts "Running migration #{migration.version} (#{migration.name})..."
  begin
    migrator.up(1)  # the oldest pending one: this migration
  rescue ex
    puts "FAILED: #{ex.message}"
    exit 1
  end
end
puts "All migrations completed"
```
{% endcode %}

```bash
crystal src/deploy_migrations.cr   # exits 1 at the first failure; the migrations before it stay applied
```

Run it on a copy of production data first, and back the database up.

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
