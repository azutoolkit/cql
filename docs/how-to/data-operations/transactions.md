# Use Transactions

This guide shows you how to use database transactions to ensure multiple operations succeed or fail together.

## Basic Transaction

Wrap operations in a transaction block:

```crystal
User.transaction do
  user = User.create!(name: "John", email: "john@example.com")
  Profile.create!(user_id: user.id.not_nil!, bio: "Hello")
end
# Both records created, or neither
```

`Model.transaction` delegates to `Schema#transaction`, yields the `DB::Transaction` (the block may ignore it), and returns the block's value (`nil` when the block raised `DB::Rollback`).

## Automatic Rollback on Error

If any operation fails, all changes are rolled back:

```crystal
User.transaction do
  user = User.create!(name: "John", email: "john@example.com")
  raise "Something went wrong!"  # Triggers rollback
  Profile.create!(user_id: user.id.not_nil!, bio: "Hello")
end
# Neither record is created
```

The exception is re-raised after the rollback, so wrap the call in `begin`/`rescue` if the caller should keep running.

## Handle Transaction Errors

```crystal
begin
  User.transaction do
    user = User.create!(name: "John", email: "john@example.com")
    # ... more operations
  end
  puts "Transaction successful"
rescue ex
  puts "Transaction failed: #{ex.message}"
end
```

## Transfer Between Records

Classic use case - moving money between accounts:

```crystal
def transfer(from_id : Int64, to_id : Int64, amount : BigDecimal)
  Account.transaction do
    from = Account.find!(from_id)
    to = Account.find!(to_id)

    raise "Insufficient funds" if from.balance < amount

    from.balance -= amount
    to.balance += amount

    from.save!
    to.save!
  end
end
```

## Create Related Records

```crystal
def create_post_with_comments(author : User, title : String, comments : Array(String))
  Post.transaction do
    post = Post.create!(
      title: title,
      body: "Post body",
      user_id: author.id.not_nil!
    )

    comments.each do |comment_text|
      Comment.create!(
        body: comment_text,
        post_id: post.id.not_nil!,
        user_id: author.id
      )
    end

    post
  end
end
```

## Operations Inside One Transaction

Everything run on the same fiber inside the block, including `schema.exec` and queries, joins the same transaction:

```crystal
User.transaction do
  user = User.create!(name: "John", email: "john@example.com")

  # These are all part of the same transaction
  3.times do |i|
    Post.create!(
      title: "Post #{i + 1}",
      body: "Content",
      user_id: user.id.not_nil!
    )
  end
end
```

## Manual Rollback

Raise `DB::Rollback` to roll back without an error propagating (the block ends quietly):

```crystal
User.transaction do
  user = User.create!(name: "John", email: "john@example.com")

  raise DB::Rollback.new("changed my mind") if some_condition_fails

  # Continue with more operations
end
```

Any other exception also rolls back, but is re-raised. Calling `tx.rollback` on the yielded transaction rolls back too; note that `Telemetry` still reports such a transaction as `Commit` (see below).

## Transaction with Return Value

The block's value is returned (`nil` after a `DB::Rollback`):

```crystal
result = User.transaction do
  user = User.create!(name: "John", email: "john@example.com")
  profile = Profile.create!(user_id: user.id.not_nil!)
  {user: user, profile: profile}
end

puts "Created user: #{result.try(&.[:user].name)}"
```

## Savepoints (Nested Transactions)

Pass the outer transaction to `Model.transaction` to open a savepoint. Rolling back the inner block leaves the outer work intact:

```crystal
User.transaction do |tx|
  User.create!(name: "Outer")

  User.transaction(tx) do |inner|
    User.create!(name: "Inner")
    inner.rollback            # or: raise DB::Rollback.new
  end
end
# "Outer" is committed, "Inner" is not
```

If the inner block raises any other exception and it propagates out of the outer block too, everything is rolled back.

A nested `transaction` call on the same fiber, through `schema.transaction { }` or `Model.transaction { }`, needs no `tx` argument: it runs as a SAVEPOINT on the outer connection, so the whole nest uses one connection. An inner `DB::Rollback` or error undoes only the inner block. If the outer block rescues an inner error, the outer transaction still commits; if the error propagates, everything is rolled back. Fibers spawned inside the block do not join the transaction; they check out their own connection. `schema.alter`, `schema.build` and a table's `create!`, `drop!` and `truncate!` nest as a SAVEPOINT the same way on SQLite and PostgreSQL; on MySQL and CockroachDB they raise `CQL::DialectError` inside a transaction.

```crystal
schema.transaction do
  User.create!(name: "Outer")
  schema.transaction do
    User.create!(name: "Inner")
    raise DB::Rollback.new    # undoes only "Inner"
  end
end
```

On the native PostgreSQL engine, `tx.savepoint { |inner| ... }` does the same:

```crystal
engine = CQL::Postgres::AsyncEngine.connect(ENV["DATABASE_URL"])

engine.transaction do |tx|
  AppDB.insert.into(:accounts).values(name: "outer").using(tx).commit
  tx.savepoint do |inner|
    AppDB.insert.into(:accounts).values(name: "inner").using(inner).commit
    raise DB::Rollback.new   # undoes only "inner"
  end
end
```

A failing savepoint block is rolled back to its savepoint and its exception propagates, unless it is `DB::Rollback`, in which case `savepoint` returns `nil`. A scope used after its transaction ended raises `CQL::Postgres::TransactionClosed`.

## Isolation Levels and Transaction Options

`Schema#transaction` and `Model.transaction` take no options. On the native PostgreSQL/CockroachDB engine, `AsyncEngine#transaction` accepts them per transaction:

```crystal
engine.transaction(isolation: :serializable) { |tx| ... }
engine.transaction(isolation: :repeatable_read, read_only: true, deferrable: true) { |tx| ... }
engine.transaction(synchronous_commit: false) { |tx| ... }   # SET LOCAL; a crash may lose this commit
```

`isolation:` takes `:read_uncommitted`, `:read_committed`, `:repeatable_read` or `:serializable` (`CQL::Postgres::IsolationLevel`). `deferrable: true` raises `ArgumentError` on CockroachDB. Statements must be pinned to the transaction with `.using(tx)`. See the [native PostgreSQL driver guide](../postgres-native/README.md).

## Transaction Events

Subscribe to begin/commit/rollback of every `Schema#transaction`:

```crystal
CQL::Telemetry.subscribe_transactions("metrics") do |event|
  # event.state    => Begin, Commit or Rollback (CQL::Telemetry::TransactionState)
  # event.id       => shared by the Begin and its Commit/Rollback
  # event.duration => time since Begin (zero for Begin; includes pool wait)
  # event.nested   => a transaction was already open on this fiber
  # event.error    => what caused a Rollback, if anything
  Log.info { "tx #{event.id} #{event.state} #{event.duration}" }
end

CQL::Telemetry.unsubscribe_transactions("metrics")
```

`DB::Rollback` is reported as a `Rollback` with that error. A nested `transaction { }` emits its own Begin and Commit/Rollback events with `nested: true`; the `Model.transaction(tx)` and `schema.transaction(tx)` overloads emit none. See [Telemetry](../performance/telemetry.md).

## Cleanup Operations

Ensure cleanup happens even on failure:

```crystal
begin
  User.transaction do
    # Operations that might fail
    user = User.create!(name: "John", email: "john@example.com")
    external_api.create_account(user)  # Might fail
  end
rescue ex
  # Handle or log the error
  Log.error { "Transaction failed: #{ex.message}" }
  raise ex
end
```

## Verify Transaction Behavior

```crystal
initial_count = User.count

begin
  User.transaction do
    User.create!(name: "Test", email: "test@example.com")
    raise "Rollback!"
  end
rescue
end

User.count == initial_count  # => true (rolled back)
```

## Related

- [Create Records](create.md)
- [Update Records](update.md)
- [Add Optimistic Locking](../models/optimistic-locking.md)
