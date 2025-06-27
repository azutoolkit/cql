# Transactions in CQL Active Record

Transactions ensure data integrity by grouping multiple database operations into a single atomic unit. In CQL, all operations within a transaction either succeed together or are rolled back together, maintaining consistency even when errors occur.

---

## What are Transactions?

A transaction is a sequence of database operations that are treated as a single unit of work. Transactions provide the ACID properties:

- **Atomicity**: All operations succeed or all are rolled back
- **Consistency**: Database remains in a valid state
- **Isolation**: Transactions don't interfere with each other
- **Durability**: Committed changes are permanent

**Common Use Case**: Transferring money between bank accounts requires both debiting one account and crediting another. If either operation fails, both must be rolled back to prevent data corruption.

---

## Basic Transaction Usage

CQL provides transaction support through the `Transactional` module. Include it in your models to access the `transaction` class method:

```crystal
class User
  include CQL::ActiveRecord::Model(Int32)
  include CQL::ActiveRecord::Transactional  # Enables transaction support

  db_context AppDB, :users

  property id : Int32?
  property name : String
  property email : String
  property balance : Float64 = 0.0

  def initialize(@name : String, @email : String, @balance : Float64 = 0.0)
  end
end
```

### Simple Transaction Block

Use the `Model.transaction` method to wrap operations in a transaction:

```crystal
User.transaction do |tx|
  # All operations within this block are part of a single transaction
  user1 = User.create!(name: "Alice", email: "alice@example.com", balance: 100.0)
  user2 = User.create!(name: "Bob", email: "bob@example.com", balance: 50.0)

  # If any operation fails, all changes are automatically rolled back
end
# Transaction is automatically committed if no exceptions occur
```

### Handling Rollbacks

Transactions automatically roll back if an exception is raised:

```crystal
User.transaction do |tx|
  user = User.create!(name: "Charlie", email: "charlie@example.com")

  # This will cause the entire transaction to roll back
  raise "Something went wrong!"

  # This line will never execute
  User.create!(name: "David", email: "david@example.com")
end
# No users are created because the transaction was rolled back
```

### Manual Rollback with DB::Rollback

Use `DB::Rollback` to roll back without raising an unhandled exception:

```crystal
User.transaction do |tx|
  user = User.create!(name: "Eve", email: "eve@example.com")

  if some_business_condition_failed
    # Roll back gracefully without propagating an exception
    raise DB::Rollback.new("Business logic requires rollback")
  end

  # This line won't execute if rollback occurred
  user.update!(balance: 100.0)
end
# Transaction is rolled back, but no exception is raised outside the block
```

### Explicit Transaction Control

You can manually control transaction state using the yielded transaction object:

```crystal
User.transaction do |tx|
  user = User.create!(name: "Frank", email: "frank@example.com")

  if user.id.nil?
    tx.rollback  # Explicitly roll back
    return       # Exit the block
  end

  user.update!(balance: 200.0)
  # Transaction commits automatically at the end
end
```

---

## Nested Transactions (Savepoints)

CQL supports nested transactions using database savepoints. This allows you to create sub-transactions within a larger transaction:

```crystal
User.transaction do |outer_tx|
  # Outer transaction operations
  user1 = User.create!(name: "Alice", email: "alice@example.com", balance: 100.0)

  # Nested transaction with savepoint
  User.transaction(outer_tx) do |inner_tx|
    user2 = User.create!(name: "Bob", email: "bob@example.com", balance: 50.0)

    # This only rolls back the inner transaction
    inner_tx.rollback
  end

  # user1 is still created, user2 is rolled back
  user1.update!(balance: 150.0)  # This still succeeds
end
# Final result: Alice exists with balance 150.0, Bob doesn't exist
```

### Nested Transaction Examples

#### Inner Success, Outer Success

```crystal
User.transaction do |outer_tx|
  user1 = User.create!(name: "Outer User", email: "outer@example.com")

  User.transaction(outer_tx) do |inner_tx|
    user2 = User.create!(name: "Inner User", email: "inner@example.com")
    # Both operations succeed
  end
end
# Result: Both users are created
```

#### Inner Rollback, Outer Success

```crystal
User.transaction do |outer_tx|
  user1 = User.create!(name: "Outer User", email: "outer@example.com")

  User.transaction(outer_tx) do |inner_tx|
    user2 = User.create!(name: "Inner User", email: "inner@example.com")
    raise DB::Rollback.new("Inner rollback")
  end

  # Outer transaction continues normally
end
# Result: Only "Outer User" is created
```

#### Inner Exception, Full Rollback

```crystal
begin
  User.transaction do |outer_tx|
    user1 = User.create!(name: "Outer User", email: "outer@example.com")

    User.transaction(outer_tx) do |inner_tx|
      user2 = User.create!(name: "Inner User", email: "inner@example.com")
      raise "Critical error!"  # Standard exception
    end
  end
rescue exception
  puts "Transaction failed: #{exception.message}"
end
# Result: No users are created (full rollback)
```

---

## Practical Example: Bank Transfer

Here's a complete example showing how to use transactions for a bank transfer operation:

```crystal
class Account
  include CQL::ActiveRecord::Model(Int32)
  include CQL::ActiveRecord::Transactional

  db_context BankDB, :accounts

  property id : Int32?
  property account_number : String
  property balance : Float64
  property created_at : Time?
  property updated_at : Time?

  def initialize(@account_number : String, @balance : Float64 = 0.0)
  end

  def self.transfer(from_account : Account, to_account : Account, amount : Float64)
    raise "Invalid transfer amount" if amount <= 0
    raise "Insufficient funds" if from_account.balance < amount

    transaction do |tx|
      # Reload accounts to get fresh data (important for concurrency)
      from_account.reload
      to_account.reload

      # Re-check after reload
      raise "Insufficient funds after reload" if from_account.balance < amount

      # Perform the transfer
      from_account.balance -= amount
      to_account.balance += amount

      # Save both accounts
      from_account.save!
      to_account.save!

      # Create audit log entry
      TransferLog.create!(
        from_account_id: from_account.id,
        to_account_id: to_account.id,
        amount: amount,
        timestamp: Time.utc
      )
    end
  end
end

# Usage
alice = Account.create!(account_number: "ACC001", balance: 500.0)
bob = Account.create!(account_number: "ACC002", balance: 200.0)

# Transfer $100 from Alice to Bob
Account.transfer(alice, bob, 100.0)

# Verify balances
alice.reload  # balance: 400.0
bob.reload    # balance: 300.0
```

---

## Error Handling

### Catching Transaction Errors

```crystal
begin
  User.transaction do |tx|
    User.create!(name: "", email: "invalid")  # Validation error
  end
rescue CQL::ActiveRecord::Validations::ValidationError => e
  puts "Validation failed: #{e.message}"
rescue DB::Error => e
  puts "Database error: #{e.message}"
rescue Exception => e
  puts "Unexpected error: #{e.message}"
end
```

### Transaction without Exception Handling

If you don't want exceptions to be raised, check operation success manually:

```crystal
success = false
User.transaction do |tx|
  user = User.new(name: "Test", email: "test@example.com")

  if user.save  # Returns false if validation fails
    success = true
  else
    tx.rollback
  end
end

if success
  puts "User created successfully"
else
  puts "User creation failed"
end
```

---

## Best Practices

### Keep Transactions Short

```crystal
# Good: Short transaction
User.transaction do |tx|
  user.update!(balance: new_balance)
  AuditLog.create!(action: "balance_update", user_id: user.id)
end

# Bad: Long transaction with external calls
User.transaction do |tx|
  user.update!(balance: new_balance)
  send_email_notification(user)  # Avoid external calls in transactions
  process_complex_calculation()   # Avoid long-running operations
end
```

### Validate Before Transactions

```crystal
# Good: Validate first
def transfer(from_account, to_account, amount)
  raise "Invalid amount" if amount <= 0
  raise "Insufficient funds" if from_account.balance < amount

  Account.transaction do |tx|
    # Transaction logic here
  end
end
```

### Handle Concurrent Access

```crystal
# Use consistent ordering to prevent deadlocks
def transfer(account1, account2, amount)
  # Always access accounts in ID order to prevent deadlocks
  from_account, to_account = [account1, account2].sort_by(&.id)

  Account.transaction do |tx|
    from_account.reload  # Get fresh data
    to_account.reload
    # Transfer logic...
  end
end
```

### Nested Transaction Guidelines

```crystal
# Good: Use nested transactions for optional sub-operations
User.transaction do |outer_tx|
  user = User.create!(name: "John", email: "john@example.com")

  # Optional profile creation - failure doesn't affect user creation
  User.transaction(outer_tx) do |inner_tx|
    UserProfile.create!(user_id: user.id, bio: "Optional bio")
  rescue ProfileCreationError
    inner_tx.rollback  # Only roll back profile creation
  end
end
```

---

## Performance Considerations

- **Transaction Duration**: Keep transactions as short as possible to reduce lock contention
- **Batch Operations**: Group related operations together in a single transaction
- **Avoid External Calls**: Don't make HTTP requests or other I/O operations within transactions
- **Index Usage**: Ensure proper indexes exist on columns used in transaction queries
- **Connection Pooling**: CQL automatically manages database connections within transactions

---

## Common Pitfalls

1. **Long-running transactions**: Avoid operations that take a long time within transaction blocks
2. **Nested transaction confusion**: Remember that `DB::Rollback` only affects the current transaction level
3. **Forgetting to reload**: When dealing with concurrent access, reload records within transactions
4. **Exception handling**: Don't catch and ignore exceptions within transactions unless you explicitly roll back

---

The CQL transaction system provides a robust foundation for maintaining data integrity in your Crystal applications. Use transactions whenever you need to ensure that multiple database operations succeed or fail together.
