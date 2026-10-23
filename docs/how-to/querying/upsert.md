# Upsert Records

This guide shows you how to insert a row or update the existing one when it conflicts with a unique key, using `Insert#on_conflict` and `Insert#upsert`.

The examples use an `accounts` table with a unique `email`, plus `name` and `visits` columns.

```crystal
AppDB = CQL::Schema.define(:app, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./app.db") do
  table :accounts do
    primary :id, Int32
    column :email, String, unique: true
    column :name, String
    column :visits, Int32, default: 0
  end
end
```

## Update on conflict

`on_conflict(*columns)` names the unique key; `do_update` says what to change:

```crystal
AppDB.insert.into(:accounts)
  .values(email: "a@x.io", name: "Ada")
  .on_conflict(:email)
  .do_update(:name)
  .commit
```

On PostgreSQL this renders (values stay bound as `$1`, `$2`):

```sql
INSERT INTO accounts (email, name) VALUES ($1, $2) ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name
```

Arguments to `do_update`:

- **Positional columns** (`do_update(:name)`) take the incoming row's value.
- **Keyword arguments** (`do_update(:name, visits: 9)`) set explicit values. They are bound as parameters after the row values: `DO UPDATE SET name = EXCLUDED.name, visits = $3`, with params `["a@x.io", "Ada", 9]`.
- **No arguments** (`do_update`) refreshes every column that is not part of the conflict target.

## Keep the existing row

```crystal
AppDB.insert.into(:accounts)
  .values(email: "a@x.io", name: "Other")
  .on_conflict(:email)
  .do_nothing
  .commit
```

```sql
... ON CONFLICT (email) DO NOTHING
```

## Composite keys

```crystal
insert.on_conflict(:email, :name).do_nothing
# ... ON CONFLICT (email, name) DO NOTHING
```

## Upsert many rows

`upsert(rows, conflict:, update:)` inserts every row in one statement and updates the `update` columns of rows that already exist:

```crystal
rows = [
  {:email => "a@x.io", :name => "Ada Lovelace"} of Symbol => DB::Any,
  {:email => "g@x.io", :name => "Grace"} of Symbol => DB::Any,
]

AppDB.insert.into(:accounts)
  .upsert(rows, conflict: [:email], update: [:name])
  .commit
```

```sql
INSERT INTO accounts (email, name) VALUES ($1, $2), ($3, $4) ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name
```

Omit `update:` to refresh every non-target column. An empty `update: [] of Symbol` means "update nothing" and renders `DO NOTHING`.

## Get the row back

`back` keeps working with a conflict clause; `RETURNING` comes after it (PostgreSQL):

```crystal
insert.on_conflict(:email).do_update(:name).back(:id)
# ... DO UPDATE SET name = EXCLUDED.name RETURNING accounts.id
```

## Dialect differences

| Dialect | `do_update(:name, visits: 9)` | `do_nothing` |
| --- | --- | --- |
| PostgreSQL, CockroachDB, SQLite | `ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name, visits = $3` (`?` on SQLite) | `ON CONFLICT (email) DO NOTHING` |
| MySQL | `ON DUPLICATE KEY UPDATE name = VALUES(name), visits = ?` | `ON DUPLICATE KEY UPDATE email = email` |

- On MySQL the conflict target is ignored: any unique key that collides triggers `ON DUPLICATE KEY UPDATE`.
- SQLite needs 3.24+.
- Identifiers are quoted when `quote_identifiers: true` (`ON CONFLICT ("email") DO UPDATE SET "name" = EXCLUDED."name"`, `` `name` = VALUES(`name`) `` on MySQL).

To see the SQL for another dialect, pass a generator: `insert.to_sql(Expression::Generator.new(CQL::Adapter::MySql))`.

## Errors

| Mistake | Result |
| --- | --- |
| `do_nothing` / `do_update` before `on_conflict` | `ArgumentError` mentioning `on_conflict` |
| `on_conflict` without `do_nothing` or `do_update` when building SQL | `ArgumentError` "do_nothing or do_update" |
| Unknown column | `ArgumentError` "Column nope not found in accounts" |
| `.query(select)` (INSERT ... SELECT) with a conflict clause | `ArgumentError`; upsert is not supported with INSERT ... SELECT |

Calling `do_update` again after building a statement does not change the statement you already built.

## Related

- [Create Records](../data-operations/create.md)
- [Use Transactions](../data-operations/transactions.md)
- [The query DSL: before and after](../../explanation/dsl-before-after.md)
