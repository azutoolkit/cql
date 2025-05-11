# Transactions Guide: Ensuring Data Integrity with CQL

This guide explores how to leverage database transactions effectively within your Crystal applications using CQL's Active Record pattern. We will use a practical banking domain example throughout to illustrate key concepts and best practices.

This documentation covers the functionality provided by the `@transactions.md` and `@transactional.cr` modules within the library.

## 1. Introduction to Transactions in CQL

### What are Transactions?

In database systems, a transaction is a single unit of work. This unit comprises one or more operations that are treated as an indivisible sequence. The core principle is that either all operations within the transaction complete successfully (commit) or none of them do (rollback).

Imagine a simple task like transferring money between two bank accounts. This isn't just one database operation; it typically involves:

1.  Debiting the sender's account.
2.  Crediting the recipient's account.

If the debit succeeds but the credit fails (e.g., due to a network error or a constraint violation), the system would be in an inconsistent state – money is gone from one account but didn't appear in the other. Transactions prevent this by ensuring that both steps must succeed together. If the credit fails, the debit is automatically undone.

### Why are they important in domain modeling?

In application development, especially when dealing with complex business logic and multiple related data changes, transactions are crucial for:

- **Maintaining Data Consistency:** Ensuring that your database adheres to all predefined rules and constraints.
- **Preventing Partial Updates:** Avoiding scenarios where only a portion of a multi-step operation completes, leaving data in an invalid state.
- **Handling Concurrency:** Providing a mechanism to manage simultaneous access and modifications to data by multiple users or processes (though concurrency requires careful consideration of isolation levels and potential deadlocks).
- **Simplifying Error Recovery:** If an error occurs within a transaction, you know the database will revert to its state before the transaction began, making error handling and recovery more predictable.

Transactions provide the crucial ACID properties:

- **Atomicity:** The transaction is a single unit; either it completes entirely or has no effect.
- **Consistency:** A transaction brings the database from one valid state to another.
- **Isolation:** Concurrent transactions do not interfere with each other. Each sees the database as if it were running alone.
- **Durability:** Once a transaction is committed, the changes are permanent and survive system failures.

### Supported Features in the library

CQL's Active Record implementation simplifies transaction management in Crystal. By including the `CQL::ActiveRecord::Transactional` module in your model, you gain access to the `transaction` class method. This method provides a block-based interface for executing a series of database operations within a single transaction.

```crystal
# Include this module in your model
struct MyModel
  include CQL::ActiveRecord::Model(Int32)
  include CQL::ActiveRecord::Transactional # <--- Gives access to .transaction

  db_context MY_DB, :my_models

  # ... properties
end

# Use the transaction block
MyModel.transaction do |tx|
  # All database operations within this block form a single transaction
  # If an unhandled exception occurs, the transaction is automatically rolled back
  # You can also use tx.rollback to manually roll back
end
```

## Use Case: Bank Transfer

To demonstrate transactions, we will use a simplified banking application.

### Overview of the domain

The core operation is transferring money between accounts. This operation must be atomic – the debit from one account and the credit to another must happen together. We also need to track these operations for auditing purposes.

### Entities Involved

- **BankAccount:** Stores account details and balance.
- **Transaction:** Records deposits, withdrawals, and transfers.
- **AuditLog:** Provides a detailed log of system activities.

(Detailed schema and model definitions are omitted for brevity, but assume standard columns like `id`, `balance`, `amount`, `type`, `created_at`, etc., as introduced in the schema section of previous versions).

## 3. Writing Transactional Logic with CQL

The core logic for banking operations like withdrawals, deposits, and transfers involves updating one or more `BankAccount` records, creating a `Transaction` record, and often creating an `AuditLog` record. These steps must be performed atomically. This is where the `BankAccount.transaction` block becomes essential.

### The `BankAccount.transaction` Block

Any database operations performed using CQL Active Record methods _inside_ a `BankAccount.transaction do ... end` block are treated as a single unit by the database.

- When the block is entered, a database transaction is started (`BEGIN`).
- When the block completes without raising an exception, the transaction is committed (`COMMIT`), making all changes permanent.
- If any exception is raised _within_ the block, the transaction is automatically rolled back (`ROLLBACK`), discarding all changes made during the transaction.
- You can also explicitly call `tx.rollback` on the yielded transaction object `tx` to manually roll back.

This ensures that if any step of a multi-operation process fails, the entire set of operations is undone, maintaining data integrity.

### Transaction Logic Examples

Here are the core transaction blocks for our banking operations, demonstrating the use of CQL features within the atomic unit:

#### Withdrawal Transaction

This transaction debits a `BankAccount` and records the event.

```crystal
# Conceptual method demonstrating the core transaction logic for withdrawal
def perform_withdrawal_transaction(account : BankAccount, amount : Float64)
  # Assumes validation (amount > 0, sufficient funds) happened BEFORE this block

  BankAccount.transaction do |tx|
    # 1. Update the account balance using CQL Active Record save!
    account.balance -= amount
    account.updated_at = Time.utc
    account.save! # Persists the balance change within the transaction

    # 2. Create a transaction record using CQL Active Record create!
    Transaction.create!( # Creates a new record within the transaction
      amount: amount,
      transaction_type: "withdrawal",
      from_account_id: account.id,
      status: "completed",
      created_at: Time.utc
    )

    # 3. Create an audit log entry using CQL Active Record create!
    AuditLog.create!( # Creates a new record within the transaction
      action: "withdrawal",
      entity_type: "bank_account",
      entity_id: account.id.not_nil!,
      data: { account: account.account_number, amount: amount }.to_json,
      created_at: Time.utc
    )

    # If any of the above .save! or .create! calls fail (e.g., DB error),
    # or if an exception is raised, the transaction will roll back automatically.
  end
end
```

**Why a Transaction is Useful Here:** While a withdrawal is simpler than a transfer, using a transaction ensures that the account balance update _and_ the recording of the transaction/audit log happen together. If the record-keeping fails, the balance change is undone.

#### Deposit Transaction

This transaction credits a `BankAccount` and records the event.

```crystal
# Conceptual method demonstrating the core transaction logic for deposit
def perform_deposit_transaction(account : BankAccount, amount : Float64)
  # Assumes validation (amount > 0) happened BEFORE this block

  BankAccount.transaction do |tx|
    # 1. Update the account balance
    account.balance += amount
    account.updated_at = Time.utc
    account.save! # Persists the balance change within the transaction

    # 2. Create a transaction record
    Transaction.create!( # Creates a new record within the transaction
      amount: amount,
      transaction_type: "deposit",
      to_account_id: account.id,
      status: "completed",
      created_at: Time.utc
    )

    # 3. Create an audit log entry
    AuditLog.create!( # Creates a new record within the transaction
      action: "deposit",
      entity_type: "bank_account",
      entity_id: account.id.not_nil!,
      data: { account: account.account_number, amount: amount }.to_json,
      created_at: Time.utc
    )
  end
end
```

**Why a Transaction is Useful Here:** Similar to withdrawal, it guarantees that the balance update and the logging/recording of the deposit happen together.

#### Transfer Transaction (Highlighting Atomicity)

This is the prime example where transactions are critical. Money must be debited from one account _and_ credited to another _and_ records created, all or nothing.

```crystal
# Conceptual method demonstrating the core transaction logic for transfer
def perform_transfer_transaction(from_account : BankAccount, to_account : BankAccount, amount : Float64)
  # Assumes validation (amount > 0, different accounts, sufficient funds)
  # happened BEFORE this block.
  # Also assumes accounts are sorted by ID outside for deadlock prevention.

  BankAccount.transaction do |tx|
    # Operations within the transaction - ENSURING ATOMICITY

    # 1. Reload accounts to get freshest data under current isolation level
    # This is crucial for handling concurrent access. Use CQL Active Record reload.
    from_account.reload
    to_account.reload

    # Re-validate insufficient funds after reloading
    raise "Insufficient funds after reload" if from_account.balance < amount

    # 2. Debit the sender's account using CQL Active Record save!
    from_account.balance -= amount
    from_account.updated_at = Time.utc
    from_account.save! # Persists the debit within the transaction

    # 3. Credit the recipient's account using CQL Active Record save!
    to_account.balance += amount
    to_account.updated_at = Time.utc
    to_account.save! # Persists the credit within the transaction

    # 4. Create a transaction record using CQL Active Record create!
    Transaction.create!( # Creates a new record within the transaction
      amount: amount,
      transaction_type: "transfer",
      from_account_id: from_account.id,
      to_account_id: to_account.id,
      status: "completed",
      created_at: Time.utc
    )

    # 5. Create an audit log entry using CQL Active Record create!
    AuditLog.create!( # Creates a new record within the transaction
      action: "money_transfer",
      entity_type: "transfer",
      entity_id: nil, # No single entity ID for the transfer action
      data: { from: from_account.account_number, to: to_account.account_number, amount: amount }.to_json,
      created_at: Time.utc
    )

    # If any of these steps (reloading, saving, creating records) fails,
    # the entire transaction is rolled back, guaranteeing that no partial
    # changes are saved to the database.
  end
end
```

**Why a Transaction is Crucial Here:** This is the quintessential transaction use case. The debit and credit _must_ happen together. If the debit succeeds but the credit fails (or vice versa, or if the transaction/audit log creation fails), the transaction ensures that all changes are undone, preventing money from being lost or duplicated. It guarantees **Atomicity**.

### Handling Failures and Rollback

As shown in the conceptual examples, any unhandled exception raised _within_ the `BankAccount.transaction do |tx| ... end` block will automatically trigger a database rollback. This is a key feature that ensures atomicity.

You can also explicitly roll back the transaction using the transaction object yielded to the block:

```crystal
BankAccount.transaction do |tx|
  # Perform some operations...

  if some_business_condition_is_not_met
    puts "Condition not met, rolling back!"
    tx.rollback # Explicitly roll back all changes made so far in this block
    # Note: Raising an exception immediately after tx.rollback is common
    # to stop execution and indicate failure.
    raise "Manual rollback triggered"
  end

  # If no rollback or exception occurs, the transaction is committed here
end
```

When `tx.rollback` is called, the database driver is instructed to perform a rollback. Any subsequent operations within the block before it exits will also be part of the rolled-back transaction.

### Querying Transaction History and Audit Logs using CQL DSL

Use CQL's query builder (`.query`, `.where`, `.order`, `.all`, `.exists?`) to inspect the records created by successful transactions:

```crystal
# Get all transfers from Alice's account
alice_transfer_history = Transaction.query
  .where(from_account_id: alice_account.id)
  .order(created_at: :desc)
  .all(Transaction) # Fetch all matching records as Transaction objects

puts "\n--- Alice's Transfer History ---"
alice_transfer_history.each { |tx| puts "- $#{tx.amount} to Account ID: #{tx.to_account_id} (#{tx.status})" }

# Get all audit logs related to Bob's account
bob_account_audit_logs = AuditLog.query
  .where(entity_type: "bank_account", entity_id: bob_account.id)
  .order(created_at: :asc)
  .all(AuditLog) # Fetch all matching records as AuditLog objects

puts "\n--- Bob's Account Audit Logs ---"
bob_account_audit_logs.each { |log| puts "- #{log.action}: #{log.data}" }
```

## 5. Best Practices

Follow these best practices when working with transactions in CQL:

- **Keep transactions short and focused:** Minimize the amount of work inside a transaction block. Long-running transactions hold locks longer, increasing contention and deadlocks.
- **Validate data before entering transactions:** Perform necessary validation _before_ starting the transaction to avoid unnecessary rollbacks.
- **Encapsulate logic:** Wrap complex transactional logic in dedicated methods or Service Objects for organization and testability.
- **Handle exceptions:** Catch exceptions outside the block for better logging and error handling, while relying on the automatic rollback inside.
- **Ensure Consistent Resource Access Order:** Access multiple records within a transaction in a consistent order (e.g., by primary key ID) to reduce deadlocks.
- **Consider Isolation Levels:** Understand and potentially configure isolation levels for advanced concurrency.
- **Avoid Nested Transactions:** Rely on the single outer transaction.

## 6. Troubleshooting and Gotchas

- **Deadlocks:** Caused by transactions waiting for each other's locks. Consistent resource ordering helps.
- **Silent Transaction Failures:** Ensure errors inside transactions are handled and reported properly outside the block.
- **Connection Issues:** Implement retry logic for transient database connection problems.
- **Misunderstanding Rollback:** Rollback affects _all_ database operations within the transaction block.

By diligently applying these principles and patterns, you can effectively use CQL's transaction capabilities to build robust and reliable applications that maintain data integrity even in the face of errors or concurrent access.
