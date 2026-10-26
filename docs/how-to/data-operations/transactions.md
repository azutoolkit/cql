# Use Transactions

Make several writes succeed or fail together, nest savepoints, and observe transactions.

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

{% hint style="warning" %}
On MySQL and CockroachDB, DDL commits implicitly, so schema changes inside a transaction raise `CQL::DialectError` before running any DDL: `AppDB.alter`, `AppDB.build`, a table's `create!`, `drop!` and `truncate!`, and building or running a migrator. On SQLite and PostgreSQL they nest as a SAVEPOINT.
{% endhint %}

## Set Isolation Levels (Native PostgreSQL Engine)

`AppDB.transaction` and `Model.transaction` take no options. `CQL::Postgres::AsyncEngine#transaction` does; pin
statements to it with `using`:

```crystal
engine = CQL::Postgres::AsyncEngine.connect(ENV["DATABASE_URL"])

engine.transaction(isolation: :serializable) do |tx|
  AppDB.insert.into(:accounts).values(name: "outer").using(tx).commit
  tx.savepoint do |inner|
    AppDB.insert.into(:accounts).values(name: "inner").using(inner).commit
    raise DB::Rollback.new             # undoes only "inner"; savepoint returns nil
  end
end

engine.transaction(isolation: :repeatable_read, read_only: true, deferrable: true) do |tx|
  AppDB.query.from(:accounts).select(:name).using(tx).all(as: String)
end

engine.transaction(synchronous_commit: false) do |tx| # SET LOCAL; a crash may lose this commit
  AppDB.insert.into(:accounts).values(name: "audit").using(tx).commit
end
# isolation: :read_uncommitted, :read_committed, :repeatable_read, :serializable
# deferrable: true raises ArgumentError on CockroachDB; a scope used after its block raises CQL::Postgres::TransactionClosed
```

## Observe Transactions

```crystal
CQL::Telemetry.subscribe_transactions("metrics") do |event|
  # event.state    => Begin, Commit or Rollback (CQL::Telemetry::TransactionState)
  # event.id       => shared by a Begin and its Commit/Rollback
  # event.duration => time since Begin (zero for Begin; includes pool wait)
  # event.nested   => true for a savepoint opened by a nested transaction { }
  # event.error    => what caused a Rollback (DB::Rollback included)
  Log.info { "tx #{event.id} #{event.state} #{event.duration}" }
end

CQL::Telemetry.unsubscribe_transactions("metrics")
```

The `transaction(tx)` overloads emit no events, and a manual `tx.rollback` is reported as `Commit`.

## See Also

- [Create Records](create.md)
- [Update Records](update.md)
- [Add Optimistic Locking](../models/optimistic-locking.md)
- [Telemetry](../observability/telemetry.md#transactions)
- [Configure TLS, Poolers, Timeouts and Transactions](../postgres-native/tls-and-poolers.md#transactions-isolation-and-savepoints)
