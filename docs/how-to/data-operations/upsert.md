# Upsert Records

Insert a row, or update the existing one when it collides with a unique key, with `Insert#on_conflict` and `Insert#upsert`.

The examples use an `accounts` table with a unique `email`:

```crystal
AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./app.db") do
  table :accounts do
    primary :id, Int64, auto_increment: true
    column :email, String, unique: true
    column :name, String
    column :visits, Int32, default: 0
  end
end
```

## Update on Conflict

`on_conflict(*columns)` names the unique key; `do_update` says what to change:

```crystal
AppDB.insert.into(:accounts)
  .values(email: "a@x.io", name: "Ada")
  .on_conflict(:email)
  .do_update(:name)
  .commit
# PostgreSQL: INSERT INTO accounts (email, name) VALUES ($1, $2) ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name

insert = AppDB.insert.into(:accounts).values(email: "a@x.io", name: "Ada")
insert.on_conflict(:email).do_update(:name, visits: 9) # positional: incoming value; keyword: bound value
# ... DO UPDATE SET name = EXCLUDED.name, visits = $3   params: ["a@x.io", "Ada", 9]
insert.on_conflict(:email).do_update                   # no arguments: every column outside the target
# ... DO UPDATE SET name = EXCLUDED.name
```

## Keep the Existing Row

```crystal
AppDB.insert.into(:accounts)
  .values(email: "a@x.io", name: "Other")
  .on_conflict(:email)
  .do_nothing
  .commit
# ... ON CONFLICT (email) DO NOTHING

insert.on_conflict(:email, :name).do_nothing # composite key: ON CONFLICT (email, name) DO NOTHING
```

## Upsert Many Rows

```crystal
rows = [
  {:email => "a@x.io", :name => "Ada Lovelace"} of Symbol => DB::Any,
  {:email => "g@x.io", :name => "Grace"} of Symbol => DB::Any,
]

AppDB.insert.into(:accounts).upsert(rows, conflict: [:email], update: [:name]).commit
# INSERT INTO accounts (email, name) VALUES ($1, $2), ($3, $4) ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name

AppDB.insert.into(:accounts).upsert(rows, conflict: [:email])                       # every non-target column
AppDB.insert.into(:accounts).upsert(rows, conflict: [:email], update: [] of Symbol) # DO NOTHING
```

For models, `Model.upsert_all(rows, on_conflict: :email)` batches the rows and keeps `id` and `created_at`; see [Create Records](create.md).

## Get the Row Back

```crystal
insert.on_conflict(:email).do_update(:name).back(:id) # RETURNING comes after the conflict clause
# PostgreSQL, CockroachDB: ... DO UPDATE SET name = EXCLUDED.name RETURNING accounts.id
# SQLite: CQL::SQLiteUnsupportedFeatureError "... RETURNING clause (before SQLite 3.35.0)"
# MySQL: the RETURNING clause is left out of the SQL
```

## Check Each Dialect

```crystal
upsert = AppDB.insert.into(:accounts).values(email: "a@x.io", name: "Ada")
  .on_conflict(:email).do_update(:name, visits: 9)

upsert.to_sql(Expression::Generator.new(CQL::Adapter::Postgres)) # also CockroachDB; SQLite (3.24+) binds ?
# ... ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name, visits = $3
upsert.to_sql(Expression::Generator.new(CQL::Adapter::MySql))
# ... ON DUPLICATE KEY UPDATE name = VALUES(name), visits = ?
# MySQL do_nothing: ... ON DUPLICATE KEY UPDATE email = email

upsert.to_sql(Expression::Generator.new(CQL::Adapter::Postgres, quote_identifiers: true))
# INSERT INTO "accounts" ("email", "name") ... ON CONFLICT ("email") DO UPDATE SET "name" = EXCLUDED."name", "visits" = $3
```

{% hint style="warning" %}
MySQL ignores the conflict target: any unique key that collides triggers `ON DUPLICATE KEY UPDATE`.
{% endhint %}

## Avoid These Errors

```crystal
AppDB.insert.into(:accounts).values(email: "x", name: "y").do_nothing
# ArgumentError: Call on_conflict(...) before do_nothing (do_update likewise)
AppDB.insert.into(:accounts).values(email: "x", name: "y").on_conflict(:email).to_sql
# ArgumentError: on_conflict needs do_nothing or do_update
insert.on_conflict(:nope)
# ArgumentError: Column nope not found in accounts
AppDB.insert.into(:accounts).query(AppDB.query.from(:users).select(:email, :name)).on_conflict(:email).do_nothing.to_sql
# ArgumentError: ON CONFLICT is not supported with INSERT ... SELECT
```

A statement from `build` is a snapshot: a later `do_update` on the same `Insert` does not change it.

## See Also

- [Create Records](create.md)
- [Use Transactions](transactions.md)
- [Inspect Queries with to_sql and explain](../querying/explain-and-to-sql.md)
- [The query DSL: before and after](../../explanation/dsl-before-after.md)
