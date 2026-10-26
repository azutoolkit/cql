---
description: "Undo applied migrations by step count or by naming the version to go back to."
---

# Rollback Migrations

## Roll Back the Newest Migrations

```crystal
migrator.applied_migrations.map(&.version).sort  # => [1, 2, 3, 4, 5]

migrator.rollback      # reverts 5     -> [1, 2, 3, 4]
migrator.rollback(2)   # reverts 4, 3  -> [1, 2]
migrator.down(1)       # same as rollback: reverts 2 -> [1]
```

Steps count applied migrations only, newest version first; pending migrations are skipped. Each call runs in one
transaction on SQLite and PostgreSQL, statement by statement on MySQL and CockroachDB, and prints the reverted ones.

## Roll Back to a Version

```crystal
migrator.down_to(2_i64)   # reverts every applied migration newer than 2; 2 stays applied -> [1, 2]
migrator.down_to(0_i64)   # reverts every applied migration
migrator.down_to(9_i64)   # no migration has version 9: does nothing
```

| Call | Reverts |
| :--- | :--- |
| `migrator.rollback` | the newest applied migration (`down(1)`) |
| `migrator.rollback(n)`, `migrator.down(n)` | the `n` newest applied migrations |
| `migrator.down` | every applied migration |
| `migrator.down_to(v)` | every applied migration newer than `v`; `v` stays applied |
| `migrator.redo` | `rollback`, then `up` |

## Add a Rollback Command

```crystal
# src/migrate.cr (see Run Migrations)
case ARGV[0]?
when "up"       then migrator.up
when "rollback" then migrator.rollback
when "down_to"  then migrator.down_to(ARGV[1].to_i64)
when "version"  then puts migrator.applied_migrations.max_of?(&.version) || 0
else                 abort "Usage: crystal src/migrate.cr up|rollback|down_to VERSION|version"
end
```

```bash
crystal src/migrate.cr rollback
crystal src/migrate.cr version      # 4
crystal src/migrate.cr down_to 2
```

A `down` that runs in a new process needs the tables and columns it touches declared on the schema; see
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
