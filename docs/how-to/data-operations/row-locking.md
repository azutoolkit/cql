---
description: "Lock the rows a query reads with CQL::Query#lock, to claim jobs from a queue or to update a balance safely."
---

# Lock Rows

Row locks work on PostgreSQL, MySQL and CockroachDB, not on SQLite.

## Lock for Update

`lock` appends `FOR UPDATE` after the rest of the query, `LIMIT` included:

```crystal
AppDB.query.from(:orders).select(:id).limit(1).lock.to_sql(for: CQL::Adapter::Postgres)
# => {"SELECT orders.id FROM orders LIMIT $1 FOR UPDATE", [1]}

AppDB.query.from(:orders).select(:id).where(customer_id: 3).limit(2).lock.to_sql(for: CQL::Adapter::Postgres)
# => {"... WHERE orders.customer_id = $1 LIMIT $2 FOR UPDATE", [3, 2]}   params keep their text order
```

## Choose the Lock

```crystal
query = AppDB.query.from(:orders).select(:id)

query.lock                          # FOR UPDATE (mode defaults to :update)
query.lock(:share)                  # FOR SHARE
query.lock(skip_locked: true)       # FOR UPDATE SKIP LOCKED: skip rows another transaction holds
query.lock(:update, nowait: true)   # FOR UPDATE NOWAIT: fail at once instead of waiting
query.lock(:share, skip_locked: true) # FOR SHARE SKIP LOCKED

query.lock(:exclusive)                       # ArgumentError: Unknown lock mode :exclusive (use :update or :share)
query.lock(skip_locked: true, nowait: true)  # ArgumentError: Use skip_locked or nowait, not both
```

## Claim a Job Inside a Transaction

A lock lasts until the transaction ends, so read and write inside one. Queries run inside `transaction` use its connection:

```crystal
AppDB.transaction do
  id = AppDB.query.from(:jobs).select(:id)
    .where(status: "pending")
    .order(id: :asc)
    .limit(1)
    .lock(skip_locked: true) # another worker's row is skipped, not waited for
    .get(as: Int64)
  # SELECT jobs.id FROM jobs WHERE jobs.status = $1 ORDER BY jobs.id ASC LIMIT $2 FOR UPDATE SKIP LOCKED

  AppDB.update.table(:jobs).set(status: "running").where(id: id).commit if id
end
```

## Lock Model Queries

`QueryBuilder` has no `lock`. Apply it to the underlying `CQL::Query` with `with_query`, which returns a new builder:

```crystal
job = Job.query
  .where { status == "pending" }
  .with_query { |query| query.limit(1).lock(skip_locked: true) }
  .first
# SELECT jobs.id, jobs.status FROM jobs WHERE jobs.status = $1 LIMIT $2 FOR UPDATE SKIP LOCKED
```

For optimistic concurrency without database locks, see [Add Optimistic Locking](../models/optimistic-locking.md).

## Merge Locked Queries

```crystal
locked = AppDB.query.from(:orders).select(:customer_id).lock(skip_locked: true)
unlocked = AppDB.query.from(:orders).select(:customer_id)

# merge carries the other query's lock; when the other has none, the current one is kept
AppDB.query.from(:orders).select(:id).merge(locked)        # ... FOR UPDATE SKIP LOCKED
AppDB.query.from(:orders).select(:id).lock.merge(unlocked) # ... FOR UPDATE
```

## Check Each Dialect

{% tabs %}
{% tab title="PostgreSQL" %}
```crystal
query.lock(skip_locked: true).to_sql(for: CQL::Adapter::Postgres)  # ... FOR UPDATE SKIP LOCKED
```
{% endtab %}

{% tab title="MySQL" %}
```crystal
query.lock(:update, nowait: true).to_sql(for: CQL::Adapter::MySql)  # ... FOR UPDATE NOWAIT
```
{% endtab %}

{% tab title="CockroachDB" %}
```crystal
query.lock.to_sql(for: CQL::Adapter::CockroachDB)  # ... FOR UPDATE
```
{% endtab %}

{% tab title="SQLite" %}
```crystal
query.lock.to_sql # on a SQLite schema: CQL::DialectError "SQLite does not support row locking (FOR UPDATE / FOR SHARE)"
```

{% hint style="warning" %}
SQLite has no row locks (it serializes writers), so use a plain transaction there. The error is raised when SQL is generated, so `to_sql`, `all` and `first` raise it too.
{% endhint %}
{% endtab %}
{% endtabs %}

{% hint style="info" %}
`FOR SHARE`, `SKIP LOCKED` and `NOWAIT` depend on the server version; MySQL has them from 8.0.
{% endhint %}

## See Also

- [Use Transactions](transactions.md)
- [Add Optimistic Locking](../models/optimistic-locking.md)
- [Inspect Queries with to_sql and explain](../querying/explain-and-to-sql.md)
