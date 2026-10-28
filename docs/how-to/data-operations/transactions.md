---
description: "Make several writes succeed or fail together, and nest savepoints."
---

# Use Transactions

## Wrap Writes in a Transaction

```crystal
profile = User.transaction do
  user = User.create!(name: "John", email: "john@example.com")
  Profile.create!(user_id: user.id!, bio: "Hello")
end
profile # => Profile, the block's value
```

`Model.transaction` is `AppDB.transaction` on the model's schema. It yields the `DB::Transaction` (the block may
ignore it) and returns the block's value. Every statement the block runs on the same fiber joins the transaction:
model calls, `AppDB.query`, `AppDB.exec`, and `AppDB.alter` on SQLite and PostgreSQL. Fibers spawned inside it check
out their own connection and do not see its uncommitted rows.

## Roll Back

```crystal
# Any exception rolls back, then propagates
begin
  User.transaction do
    User.create!(name: "John", email: "john@example.com")
    raise "Something went wrong!"
  end
rescue ex
  puts "Transaction failed: #{ex.message}"   # no user was created
end

# DB::Rollback rolls back quietly; the call returns nil
result = User.transaction do
  User.create!(name: "John", email: "john@example.com")
  raise DB::Rollback.new("changed my mind")
end
result # => nil
```

```crystal
def transfer(from_id : Int64, to_id : Int64, cents : Int64)
  Account.transaction do
    from = Account.find!(from_id)
    to = Account.find!(to_id)
    raise "Insufficient funds" if from.balance_cents < cents

    from.balance_cents -= cents
    to.balance_cents += cents
    from.save!
    to.save!
  end
end
```

## Nest Savepoints

```crystal
AppDB.transaction do
  User.create!(name: "Outer", email: "outer@example.com")
  AppDB.transaction do                # SAVEPOINT on the same connection
    User.create!(name: "Inner", email: "inner@example.com")
    raise DB::Rollback.new            # undoes only "Inner"
  end
end
# "Outer" is committed, "Inner" is not

User.transaction do |tx|
  User.transaction(tx) do |inner|     # explicit form, same SAVEPOINT
    User.create!(name: "Inner", email: "inner@example.com")
    inner.rollback
  end
end
```

An inner exception undoes the inner block. If the outer block rescues it, the outer work still commits; if it
propagates, everything rolls back.

## Change the Schema Inside a Transaction

{% tabs %}
{% tab title="SQLite and PostgreSQL" %}
```crystal
AppDB.transaction do
  AppDB.alter(:users) { add_column :bio, String } # a SAVEPOINT inside the transaction
  AppDB.update.table(:users).set(bio: "").commit  # an exception here also undoes the column
end
```

`AppDB.build`, a table's `create!`, `drop!` and `truncate!`, and migrator runs nest the same way. A rollback removes
the column from both the database and `AppDB`'s declaration, so model queries keep working, also when the `alter`'s
savepoint committed before the outer block raised. A manual `tx.rollback`, or a rollback of a transaction you opened yourself and passed in with `schema.transaction(tx)`, leaves the declaration as altered.
{% endtab %}

{% tab title="MySQL and CockroachDB" %}
```crystal
AppDB.transaction do
  AppDB.alter(:users) { add_column :bio, String }
  # CQL::DialectError: MySQL does not support schema changes inside a transaction
end
```

DDL commits implicitly here, so `AppDB.alter`, `AppDB.build`, a table's `create!`, `drop!` and `truncate!`, and
building or running a migrator raise before running any DDL. Run them outside the transaction. An `alter` that fails
part-way is not undone, in the database or in `AppDB`'s declaration.
{% endtab %}
{% endtabs %}

## Set Isolation Levels and Read-Only Mode

```crystal
AppDB.transaction(isolation: :serializable) do
  # SET TRANSACTION ISOLATION LEVEL SERIALIZABLE ran first on PostgreSQL and CockroachDB, before BEGIN on MySQL
  User.create!(name: "John", email: "john@example.com")
end

AppDB.transaction(read_only: true) do
  # SET TRANSACTION READ ONLY ran the same way: the database refuses a write to a table here
  User.count
end
```

`isolation:` takes `:read_uncommitted`, `:read_committed`, `:repeatable_read` or `:serializable`. PostgreSQL runs
`:read_uncommitted` as read committed and the other levels as asked; CockroachDB may run a level weaker than
serializable as serializable. With `read_only: true` the database refuses writes to permanent tables on the
transaction's connection (SQLSTATE `25006` on PostgreSQL); given both, one `SET TRANSACTION` sets them. MySQL refuses
`SET TRANSACTION` inside a transaction, so CQL runs it just before BEGIN, on the transaction's connection. SQLite
transactions are always serializable and may write, so it takes `:serializable` only and no `read_only:`. Anything
else on SQLite, and `isolation:` or `read_only:` inside an `AppDB.transaction` on the same fiber (a savepoint keeps
its transaction's modes), raise before the transaction begins: `CQL::DialectError`, or `ArgumentError` for the nested
call. `Model.transaction` takes the same `isolation:` and `read_only:`, for its model's schema only (a model of
another schema runs outside the transaction, and can write); a model's own `def self.transaction(&)` redefines only
the call without them. The native PostgreSQL engine's `transaction` also takes `deferrable:` and
`synchronous_commit:`, as
[Transactions: Isolation and Savepoints](../postgres-native/tls-and-poolers.md#transactions-isolation-and-savepoints) shows.

{% hint style="warning" %}
`read_only: true` guards against accidental writes by the block's own queries; it is not access control. Temporary
tables and session state (`set_config`, advisory locks, `LISTEN`) stay writable, and code in the block can end the mode:
a `COMMIT`, `SET TRANSACTION READ WRITE` before the first query on PostgreSQL, or DDL on MySQL, which commits
implicitly. Fibers spawned in the block use connections of their own. To enforce read-only access, connect as a
database role without write privileges, or to a read-only replica.
{% endhint %}

## Observe Transactions

`CQL::Telemetry.subscribe_transactions` reports each `Begin`, `Commit` and `Rollback` with its duration; see [Telemetry](../observability/telemetry.md#transactions).

## See Also

- [Create Records](create.md)
- [Update Records](update.md)
- [Add Optimistic Locking](../models/optimistic-locking.md)
- [Telemetry](../observability/telemetry.md#transactions)
- [Configure TLS, Poolers, Timeouts and Transactions](../postgres-native/tls-and-poolers.md#transactions-isolation-and-savepoints)
