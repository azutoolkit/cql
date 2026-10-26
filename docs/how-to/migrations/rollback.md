# Rollback Migrations

Undo applied migrations by version. The built-in step counts include pending migrations, so name the version.

## Roll Back to a Version

```crystal
# Reverts every applied migration newer than *version*, whatever is pending
def rollback_to(migrator : CQL::Migrator, version : Int64) : Nil
  steps = CQL::Migrator.migrations.count { |migration| migration.version > version }
  migrator.down(steps) if steps > 0
end

applied = migrator.applied_migrations.map(&.version).sort  # => [1, 2, 3, 4, 5]

rollback_to(migrator, applied[-2]? || 0_i64)  # the newest applied one  -> [1, 2, 3, 4]
rollback_to(migrator, 2_i64)                  # back to version 2       -> [1, 2]
rollback_to(migrator, 0_i64)                  # every migration         -> []
```

`down(n)` walks the `n` newest *registered* migrations and reverts the applied ones among them, so counting the
registered migrations newer than the target reverts exactly the applied ones above it. Each call runs in one
transaction on SQLite and PostgreSQL, statement by statement on MySQL and CockroachDB, and prints the reverted ones.

## Know What the Built-in Calls Revert

| Call | Reverts |
| :--- | :--- |
| `migrator.rollback` | the newest registered migration if it is applied, else nothing (`down(1)`) |
| `migrator.rollback(n)`, `migrator.down(n)` | the applied ones among the `n` newest registered |
| `migrator.down` | every applied migration |
| `migrator.down_to(v)` | the applied ones among the newest *position of v + 1* registered, not "down to v" |
| `migrator.redo` | `rollback`, then `up` |

```crystal
# ❌ 1-5 applied: the second rollback looks at 5 again and reverts nothing
migrator.rollback
migrator.rollback
migrator.applied_migrations.map(&.version)  # => [1, 2, 3, 4]

# ❌ 1-5 registered, 1-3 applied: down_to reverts the wrong ones
migrator.down_to(3_i64)                     # reverts 3      -> [1, 2]
migrator.down_to(1_i64)                     # reverts nothing (5 is pending)

# ✅ Name the version
rollback_to(migrator, 1_i64)                # -> [1]
```

## Add a Rollback Command

```crystal
# src/migrate.cr (see Run Migrations), with rollback_to defined above
case ARGV[0]?
when "up" then migrator.up
when "rollback"
  versions = migrator.applied_migrations.map(&.version).sort
  rollback_to(migrator, versions[-2]? || 0_i64)
when "version" then puts migrator.applied_migrations.max_of?(&.version) || 0
else                abort "Usage: crystal src/migrate.cr up|rollback|version"
end
```

```bash
crystal src/migrate.cr rollback
crystal src/migrate.cr version   # 4
```

A `down` that runs in a new process needs the tables and columns it touches declared on the schema; see
[Create a Migration](create-migration.md#write-a-migration).

## Handle Irreversible Migrations

```crystal
class DropLegacyUsers < CQL::Migration(6)
  def up
    schema.exec("DROP TABLE legacy_users")
  end

  def down
    raise "Cannot rollback: table was dropped with data"
  end
end

begin
  rollback_to(migrator, 4_i64)
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
