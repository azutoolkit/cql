---
description: "Undo applied migrations: the newest one, several, or everything newer than a version."
---

# Rollback Migrations

## Roll Back the Newest Migrations

```crystal
migrator.applied_migrations.map(&.version).sort  # => [1, 2, 3, 4, 5]

migrator.rollback     # reverts 5         -> [1, 2, 3, 4]
migrator.rollback(2)  # reverts 4, then 3 -> [1, 2]
```

`rollback(n)` and `down(n)` revert the `n` newest *applied* migrations, highest version first; pending migrations do
not count. Each call runs in one transaction on SQLite and PostgreSQL, statement by statement on MySQL and CockroachDB,
and prints the reverted ones.

## Roll Back to a Version

```crystal
migrator.down_to(2_i64)   # reverts every applied migration newer than 2; 2 stays applied
migrator.down_to(42_i64)  # raises CQL::Migrator::Error: No migration with version 42
```

## Know What the Built-in Calls Revert

| Call | Reverts |
| :--- | :--- |
| `migrator.rollback` | the newest applied migration (`down(1)`) |
| `migrator.rollback(n)`, `migrator.down(n)` | the `n` newest applied migrations |
| `migrator.down_to(v)` | every applied migration newer than `v`; raises `CQL::Migrator::Error` if no migration has version `v` |
| `migrator.down` | every applied migration |
| `migrator.redo` | `rollback`, then `up` (every pending migration) |

## Add a Rollback Command

```crystal
# src/migrate.cr (see Run Migrations)
case ARGV[0]?
when "up"       then migrator.up
when "rollback" then migrator.rollback
when "version"  then puts migrator.applied_migrations.max_of?(&.version) || 0
else                 abort "Usage: crystal src/migrate.cr up|rollback|version"
end
```

```bash
crystal src/migrate.cr rollback
crystal src/migrate.cr version   # 4
```

A `down` that runs in a new process needs the tables it touches, and the columns `rename_column` renames, declared on
the schema; `drop_column` emits its `DROP COLUMN` either way. See
[Create a Migration](create-migration.md#write-a-migration).

## Handle Irreversible Migrations

{% code title="db/migrations/006_drop_legacy_users.cr" %}
```crystal
class DropLegacyUsers < CQL::Migration(6)
  def up
    schema.exec("DROP TABLE legacy_users")
  end

  def down
    raise "Cannot rollback: table was dropped with data"
  end
end
```
{% endcode %}

```crystal
begin
  migrator.down_to(4_i64)
rescue ex
  puts "Rollback failed: #{ex.message}"  # 5 and 6 both stay applied on SQLite and PostgreSQL
end
```

## Refresh a Development Database

```crystal
migrator.down   # every applied migration
migrator.up
```

{% hint style="danger" %}
`migrator.down` without an argument reverts every applied migration and drops their data.
{% endhint %}

## See Also

- [Run Migrations](run-migrations.md)
- [Create a Migration](create-migration.md)
- [Fix Migration Errors](../troubleshooting/migration-errors.md)
- [Migration DSL Reference](../../reference/api/migration-dsl.md)
