# Lock Rows

This guide shows you how to lock the rows a query reads with `lock`, for example to claim jobs from a queue or to update a balance safely.

## Lock for update

`lock` appends `FOR UPDATE` after the rest of the query, including `LIMIT`:

```crystal
AppDB.query.from(:orders).select(:id).limit(1).lock
```

PostgreSQL:

```sql
SELECT orders.id FROM orders LIMIT $1 FOR UPDATE
```

Parameters keep their text order: `where(customer_id: 3).limit(2).lock` ends with `orders.customer_id = $1 LIMIT $2 FOR UPDATE`.

## Signature

```crystal
query.lock(mode : Symbol = :update, skip_locked : Bool = false, nowait : Bool = false)
```

| Call | Clause appended |
| --- | --- |
| `lock` / `lock(:update)` | `FOR UPDATE` |
| `lock(:share)` | `FOR SHARE` |
| `lock(skip_locked: true)` | `FOR UPDATE SKIP LOCKED` |
| `lock(:update, nowait: true)` | `FOR UPDATE NOWAIT` |

`skip_locked:` skips rows another transaction holds, which is the usual way to let several workers take jobs without waiting for each other. `nowait:` fails immediately instead of waiting.

## Lock inside a transaction

A lock only lasts until the transaction ends, so read and write inside one. Queries run inside `transaction` use the transaction's connection:

```crystal
AppDB.transaction do |tx|
  id = AppDB.query.from(:jobs).select(:id)
    .where(status: "pending")
    .order(id: :asc)
    .limit(1)
    .lock(skip_locked: true)
    .get(as: Int64)

  if id
    AppDB.update.table(:jobs).set(status: "running").where(id: id).commit
  end
end
```

If another worker already holds the first pending row, `SKIP LOCKED` moves on to the next one.

## Lock model queries

Model query builders do not have `lock` themselves. Apply it to the underlying query with `with_query`, which returns a new builder:

```crystal
Job.query
  .where { status == "pending" }
  .with_query { |query| query.limit(1).lock(skip_locked: true) }
  .to_a
```

For optimistic concurrency without database locks see [Add Optimistic Locking](../models/optimistic-locking.md).

## Merging

`merge` carries a row lock along. If the other query has none, the current query keeps its own:

```crystal
AppDB.query.from(:orders).select(:id).merge(other.lock(skip_locked: true))
# ... FOR UPDATE SKIP LOCKED
```

## Errors

| Mistake | Result |
| --- | --- |
| `lock(:exclusive)` | `ArgumentError` "Unknown lock mode" (use `:update` or `:share`) |
| `lock(skip_locked: true, nowait: true)` | `ArgumentError` "Use skip_locked or nowait, not both" |
| Generating SQL for SQLite | `CQL::DialectError` "SQLite does not support row locking" |

## Dialect notes

- PostgreSQL, MySQL and CockroachDB support `lock`. Examples in the specs: `FOR UPDATE NOWAIT` on MySQL, plain `FOR UPDATE` on CockroachDB.
- SQLite has no row locks (it serializes writers). The error surfaces when SQL is generated, so `to_sql` raises too. Use a transaction instead.
- `FOR SHARE`, `SKIP LOCKED` and `NOWAIT` availability depends on your server version (MySQL has them from 8.0).

## Related

- [Use Transactions](../data-operations/transactions.md)
- [Add Optimistic Locking](../models/optimistic-locking.md)
- [Inspect Queries with to_sql and explain](explain-and-to-sql.md)
