---
description: "Short answers, each linking to the page that covers the task."
---

# Frequently Asked Questions

## General

### What is CQL?

A type-safe query DSL and ORM for Crystal: schemas, migrations, a query builder and Active Record models. Start with [Your First CQL App](../tutorials/getting-started/your-first-cql-app.md).

### What databases does CQL support?

SQLite, PostgreSQL, MySQL and CockroachDB. See [Database Support](../reference/database-support.md) for what each supports and [Configure Database Connection](../how-to/configuration/database-connection.md) for their URLs.

### Is CQL stable?

CQL is pre-1.0: `shard.yml` carries a `0.0.x` version, and CI tags a new release for every push to `master`. Pin a version in your `shard.yml` and read the **Upgrade notes** in `CHANGELOG.md` before you update.

## Models

### Should I use `class` or `struct` for models?

Use `class`: `save` assigns the generated id to the instance it is called on, which a struct copy would not see. See [Define a Model](../how-to/models/define-model.md).

### Why is my primary key nullable?

A new record has no id until it is saved. `CQL::ActiveRecord::Model(Int64)` provides `id` (an `Int64?`), `id!` (raises while it is `nil`) and `id=`; see [Define a Model](../how-to/models/define-model.md).

### How do I add a field that isn't in the database?

Mark it with `DB::Field(ignore: true)`. CQL leaves it out of `INSERT` and `UPDATE`, and it is `nil` on records it reads:

```crystal
@[DB::Field(ignore: true)]
property remember_token : String?
```

See [Define a Model](../how-to/models/define-model.md).

## Queries

### How do I write raw SQL?

Pass a fragment with bound values, `User.where("lower(email) = ?", email)`, using `?` or `:name` placeholders but never both in one fragment. `AppDB.exec(sql)` runs a whole statement and returns a `DB::ExecResult`, not rows. See [Use Raw SQL Fragments Safely](../how-to/advanced-sql/raw-fragments.md).

### Why is my query returning an empty array?

Print the SQL and its parameters (next question) and compare them with your data. SoftDeletable models hide soft-deleted records. `where(col: nil)` and `where { col == nil }` match `IS NULL`, but a raw fragment `col = ?` with `nil` matches nothing. See [Filter with Where Clauses](../how-to/querying/filter-records.md) and [Implement Soft Deletes](../how-to/models/soft-delete.md).

### How do I see the SQL a query will run?

Call `to_sql` on the query; `CQL::Telemetry.log_queries` logs every statement CQL runs at debug level. See [Inspect Queries with to_sql and explain](../how-to/querying/explain-and-to-sql.md) and [Telemetry](../how-to/observability/telemetry.md).

## Relationships

### When do I use belongs_to vs has_many?

- `belongs_to`: this model has the foreign key column (`Comment` has `post_id`).
- `has_many`: the other model has the foreign key (`Post` has many `Comment`s).

See [Set Up Belongs To](../how-to/relationships/belongs-to.md) and [Set Up Has Many](../how-to/relationships/has-many.md).

### Why does my relationship fail at compile time?

CQL checks associations while compiling. A `belongs_to` or `has_many` fails when the foreign key getter is missing, the arguments are not literals, or the key types differ. A `Post` with `property user_id : Int32?` cannot belong to a `User` keyed by `Int64`:

```text
CQL belongs_to error in Post: foreign key `:user_id` type Int32 does not match User.id! primary key type Int64. Change `:user_id` to Int64 or update the target model primary key type.
```

Change the foreign key to `Int64?`, or change the related model's key type. See [Set Up Belongs To](../how-to/relationships/belongs-to.md).

### How do I check that models match the schema?

Set `CQL_VALIDATE_SCHEMA_MAPPINGS=1`: each model's getter types are compared with the columns its schema declares, and a mismatch raises `CQL::ActiveRecord::SchemaMappingError` ("CQL schema mapping error in User: ..."). The check runs after all other top-level code, so an application that starts a blocking server never reaches it; run it in CI from a program that only requires your models. See [Fix Schema Mapping Errors](../how-to/troubleshooting/schema-mapping-errors.md).

### How do I eager load associations?

`User.preload(:posts).all` loads a `has_many`, `belongs_to` or `has_one` association with one extra query. `preload` ignores `many_to_many`; [Avoid N+1 Queries](../how-to/performance/n-plus-one.md) shows how to load those through the join model.

## Migrations

### How do I add a column to an existing table?

Call `add_column` inside `schema.alter` in a migration. It takes the options `column` does, so `null: false, default: ...` works on a table with rows; see [Add Columns](../how-to/migrations/add-columns.md#add-a-column-with-a-default).

### How do I roll back a migration?

`migrator.rollback` reverts the newest applied migration, `rollback(2)` the two newest and `down` every one; pending migrations do not count as steps. `migrator.down_to(version)` reverts every applied migration newer than `version` and keeps `version` applied. See [Rollback Migrations](../how-to/migrations/rollback.md).

### What if a migration fails halfway through?

On SQLite and PostgreSQL, `migrator.up` runs in one transaction, so a failure rolls the whole run back. On MySQL and CockroachDB each statement commits on its own: earlier migrations of the run stay applied and recorded, and the failing one is not recorded. Undo its partial changes by hand, fix it, and run `migrator.up` again. See [Fix Migration Errors](../how-to/troubleshooting/migration-errors.md).

## Performance

### How do I avoid N+1 queries?

Preload the association, `Post.preload(:user).all`, instead of reading it inside a loop. See [Avoid N+1 Queries](../how-to/performance/n-plus-one.md) and [Optimize Queries](../how-to/performance/optimize-queries.md).

### Should I add indexes?

Index foreign key columns, and the columns your `WHERE` and `ORDER BY` clauses use most. Declare them in the schema (`index: true` on a column, or `index [...]`) or add them in a migration with `create_index`. See [Create Indexes](../how-to/migrations/indexes.md).

## Troubleshooting

### "Connection refused" error

The server is not running, or the URL names the wrong host or port. Check the server with `pg_isready` or `mysqladmin ping`, then the URL. See [Fix Connection Errors](../how-to/troubleshooting/connection-errors.md).

### "Table does not exist" error

The table was never created in this database. Run `migrator.up`, or create a declared table with `AppDB.users.create!`. See [Run Migrations](../how-to/migrations/run-migrations.md).

### Validation failed, but I don't know why

`save` returns `false`; `save!` and the instance method `record.create!` raise `CQL::RecordInvalid`, whose message joins the errors. `user.errors` lists each field and message. See [Fix Validation Errors](../how-to/troubleshooting/validation-errors.md).

## Best Practices

### Should I use `save` or `save!`?

- `save` returns `false` for an invalid record or when a `before_*` callback returns `false`; an empty `errors` means a callback halted it.
- `save!` raises instead: `CQL::RecordInvalid` for an invalid record, `CQL::RecordNotSaved` for a halting callback.

See [Use Callbacks](../how-to/models/use-callbacks.md).

### When should I use transactions?

When several writes must succeed or fail together: an exception inside `User.transaction { ... }` rolls them all back. See [Use Transactions](../how-to/data-operations/transactions.md).

### How do I test my models?

Use a separate test database and empty the tables between examples, or roll each example back. See [Set Up Test Databases](../how-to/testing/test-database.md).
