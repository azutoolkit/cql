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
the column from the database but not from `AppDB`'s declaration, so model queries on the table then fail with
`no such column: users.bio` until the process restarts.
{% endtab %}

{% tab title="MySQL and CockroachDB" %}
```crystal
AppDB.transaction do
  AppDB.alter(:users) { add_column :bio, String }
  # CQL::DialectError: MySQL does not support schema changes inside a transaction
end
```

DDL commits implicitly here, so `AppDB.alter`, `AppDB.build`, a table's `create!`, `drop!` and `truncate!`, and
building or running a migrator raise before running any DDL. Run them outside the transaction.
{% endtab %}
{% endtabs %}

## Set Isolation Levels

`AppDB.transaction` and `Model.transaction` take no options; the native PostgreSQL engine's `transaction` takes `isolation:`, `read_only:`, `deferrable:` and `synchronous_commit:`, as [Transactions: Isolation and Savepoints](../postgres-native/tls-and-poolers.md#transactions-isolation-and-savepoints) shows.

## Observe Transactions

`CQL::Telemetry.subscribe_transactions` reports each `Begin`, `Commit` and `Rollback` with its duration; see [Telemetry](../observability/telemetry.md#transactions).

## See Also

- [Create Records](create.md)
- [Update Records](update.md)
- [Add Optimistic Locking](../models/optimistic-locking.md)
- [Telemetry](../observability/telemetry.md#transactions)
- [Configure TLS, Poolers, Timeouts and Transactions](../postgres-native/tls-and-poolers.md#transactions-isolation-and-savepoints)
