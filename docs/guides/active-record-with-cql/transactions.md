# Transactions in CQL

This comprehensive guide demonstrates how to use transactions with CQL's Active Record pattern. We'll explore transactions through a practical banking application example, explaining each concept step by step.

## What are Transactions?

In database systems, a transaction represents a unit of work that should be processed reliably and independently of other transactions. Imagine you're transferring money between two bank accounts - you want to ensure that the money is both withdrawn from one account AND deposited to another. If either operation fails, both should be reversed to maintain data integrity.

Transactions provide four critical guarantees, known as ACID properties:

- **Atomicity**: All operations within a transaction are treated as a single, indivisible unit. Either all operations succeed completely, or none of them take effect at all. There's no possibility of partial completion that could leave your database in an inconsistent state.

- **Consistency**: A transaction transforms the database from one valid state to another valid state, maintaining all predefined rules, constraints, and data integrity. For example, the total amount of money in the banking system remains constant before and after a transfer.

- **Isolation**: Even when multiple transactions are executing concurrently, each transaction operates as if it were running alone. The intermediate states of a transaction are invisible to other transactions until the transaction completes.

- **Durability**: Once a transaction is committed (completed successfully), its changes are permanent and will survive system failures like power outages or crashes. The database guarantees that committed data won't be lost.

## Understanding Transactions in CQL

CQL (Crystal Query Language) provides a clean, Ruby-like syntax for handling database transactions through its Active Record implementation. Let's start with a basic example:

```crystal
# Basic transaction pattern in CQL
BankAccount.transaction do |tx|
  # All database operations in this block form a single transaction

  # 1. Retrieve data
  account = BankAccount.find(1)

  # 2. Modify data
  account.balance += 100.0

  # 3. Save changes
  account.save!

  # Any unhandled exception will automatically roll back the entire transaction
  # You can also use tx.rollback to manually roll back when needed
end
```

When this code executes:
1. CQL begins a transaction by sending a `BEGIN` command to the database
2. All SQL operations inside the block are part of this transaction
3. If all operations succeed and no exceptions occur, CQL automatically sends a `COMMIT` command
4. If any exception occurs, CQL automatically sends a `ROLLBACK` command

This behavior ensures that your database operations either all succeed or all fail together, maintaining data integrity.

## Banking Application Example

### 1. Schema Definition

```crystal
BANKING_DB = CQL::Schema.define(:banking_db, "postgresql://localhost/banking", CQL::Adapter::PostgreSQL) do
  table :bank_accounts do
    column :id, Int32, primary: true, auto: true
    column :account_number, String
    column :owner_name, String
    column :balance, Float64
    column :created_at, Time
    column :updated_at, Time
  end

  table :transactions do
    column :id, Int32, primary: true, auto: true
    column :amount, Float64
    column :transaction_type, String # "deposit", "withdrawal", "transfer"
    column :from_account_id, Int32, null: true
    column :to_account_id, Int32, null: true
    column :status, String # "pending", "completed", "failed"
    column :created_at, Time

    foreign_key :from_account_id, references: :bank_accounts, on_delete: :cascade
    foreign_key :to_account_id, references: :bank_accounts, on_delete: :cascade
  end

  table :audit_logs do
    column :id, Int32, primary: true, auto: true
    column :action, String
    column :entity_type, String
    column :entity_id, Int32
    column :data, String # JSON data
    column :created_at, Time
  end
end
```

### 2. Model Definitions

```crystal
struct BankAccount
  include CQL::ActiveRecord::Model(Int32)
  include CQL::ActiveRecord::Transactional

  db_context BANKING_DB, :bank_accounts

  property id : Int32?
  property account_number : String
  property owner_name : String
  property balance : Float64
  property created_at : Time
  property updated_at : Time

  # Methods that delegate to service objects
  def withdraw(amount : Float64) : Bool
    BankingServices::WithdrawalService.execute(self, amount)
  end

  def deposit(amount : Float64) : Bool
    BankingServices::DepositService.execute(self, amount)
  end

  def transfer_to(recipient : BankAccount, amount : Float64) : Bool
    BankingServices::TransferService.execute(self, recipient, amount)
  end
end

struct Transaction
  include CQL::ActiveRecord::Model(Int32)

  db_context BANKING_DB, :transactions

  property id : Int32?
  property amount : Float64
  property transaction_type : String
  property from_account_id : Int32?
  property to_account_id : Int32?
  property status : String
  property created_at : Time

  belongs_to :from_account, BankAccount, foreign_key: :from_account_id
  belongs_to :to_account, BankAccount, foreign_key: :to_account_id
end

struct AuditLog
  include CQL::ActiveRecord::Model(Int32)

  db_context BANKING_DB, :audit_logs

  property id : Int32?
  property action : String
  property entity_type : String
  property entity_id : Int32
  property data : String
  property created_at : Time
end
```

## Transaction Usage Patterns

### When Should You Use Transactions?

Transactions are essential when multiple database operations need to be treated as a single unit of work. Use transactions when:

1. **Modifying related data across multiple tables** - For example, recording a sale might require updating inventory, creating an order record, and recording payment details.

2. **Ensuring data consistency** - When one operation's validity depends on another (like ensuring an account has enough funds before withdrawing).

3. **Maintaining referential integrity** - When you need to ensure that related records across different tables remain consistent.

4. **Preventing race conditions** - When multiple users or processes might be updating the same data simultaneously.

In our banking application, transactions are vital for operations like money transfers, where partial completion (debiting one account without crediting another) would be catastrophic.

### Two Ways to Use Transactions in CQL

CQL provides two main approaches to working with transactions:

#### 1. Direct Transaction Blocks

```crystal
# Direct transaction block on any model that includes CQL::ActiveRecord::Transactional
BankAccount.transaction do |tx|
  # Your operations here

  # Optional: Manually roll back when needed
  if some_condition
    tx.rollback
    return
  end
end
```

#### 2. Service Objects Pattern (Recommended)

For complex business logic, the service objects pattern provides a cleaner, more maintainable approach by:
- Encapsulating related operations
- Centralizing validation logic
- Providing clear error handling
- Simplifying testing

Let's look at how this works with our WithdrawalService example:

```crystal
module BankingServices
  class WithdrawalService
    # Class method for convenient execution
    def self.execute(account : BankAccount, amount : Float64) : Bool
      new(account, amount).execute
    end

    # Initialize with required data
    def initialize(@account : BankAccount, @amount : Float64)
    end

    # Main execution method
    def execute : Bool
      # First validate before starting transaction
      validate!

      # Begin transaction
      BankAccount.transaction do |tx|
        # Step 1: Update account balance
        @account.balance -= @amount
        @account.updated_at = Time.utc
        @account.save!

        # Step 2: Create transaction record for audit trail
        Transaction.create!(
          amount: @amount,
          transaction_type: "withdrawal",
          from_account_id: @account.id,
          status: "completed",
          created_at: Time.utc
        )

        # Step 3: Log detailed audit information
        AuditLog.create!(
          action: "withdrawal",
          entity_type: "bank_account",
          entity_id: @account.id.not_nil!,
          data: {
            account: @account.account_number,
            amount: @amount
          }.to_json,
          created_at: Time.utc
        )

        # Return success
        true
      end
    rescue ex : Exception
      # Handle any exceptions and log the error
      Log.error { "Withdrawal failed: #{ex.message}" }
      false
    end

    # Validation occurs before transaction begins
    private def validate!
      raise "Withdrawal amount must be positive" if @amount <= 0
      raise "Insufficient funds" if @account.balance < @amount
    end
  end
```

### DepositService

```crystal
  class DepositService
    def self.execute(account : BankAccount, amount : Float64) : Bool
      new(account, amount).execute
    end

    def initialize(@account : BankAccount, @amount : Float64)
    end

    def execute : Bool
      validate!

      BankAccount.transaction do |tx|
        # Update account balance
        @account.balance += @amount
        @account.updated_at = Time.utc
        @account.save!

        # Create transaction record
        Transaction.create!(
          amount: @amount,
          transaction_type: "deposit",
          to_account_id: @account.id,
          status: "completed",
          created_at: Time.utc
        )

        # Log the audit
        AuditLog.create!(
          action: "deposit",
          entity_type: "bank_account",
          entity_id: @account.id.not_nil!,
          data: {
            account: @account.account_number,
            amount: @amount
          }.to_json,
          created_at: Time.utc
        )

        true
      end
    rescue ex : Exception
      Log.error { "Deposit failed: #{ex.message}" }
      false
    end

    private def validate!
      raise "Deposit amount must be positive" if @amount <= 0
    end
  end
```

### TransferService

```crystal
  class TransferService
    def self.execute(from_account : BankAccount, to_account : BankAccount, amount : Float64) : Bool
      new(from_account, to_account, amount).execute
    end

    def initialize(@from_account : BankAccount, @to_account : BankAccount, @amount : Float64)
    end

    def execute : Bool
      validate!

      BankAccount.transaction do |tx|
        # Update sender balance
        @from_account.balance -= @amount
        @from_account.updated_at = Time.utc
        @from_account.save!

        # Update recipient balance
        @to_account.balance += @amount
        @to_account.updated_at = Time.utc
        @to_account.save!

        # Create transaction record
        Transaction.create!(
          amount: @amount,
          transaction_type: "transfer",
          from_account_id: @from_account.id,
          to_account_id: @to_account.id,
          status: "completed",
          created_at: Time.utc
        )

        # Log the audit
        AuditLog.create!(
          action: "money_transfer",
          entity_type: "bank_account",
          entity_id: @from_account.id.not_nil!,
          data: {
            from_account: @from_account.account_number,
            to_account: @to_account.account_number,
            amount: @amount
          }.to_json,
          created_at: Time.utc
        )

        true
      end
    rescue ex : Exception
      Log.error { "Transfer failed: #{ex.message}" }
      false
    end

    private def validate!
      raise "Transfer amount must be positive" if @amount <= 0
      raise "Cannot transfer to the same account" if @from_account.id == @to_account.id
      raise "Insufficient funds" if @from_account.balance < @amount
    end
  end
end
```

## Practical Transaction Examples

Let's walk through complete, real-world examples of using transactions in our banking application. These examples will demonstrate how transactions ensure data integrity across multiple operations.

### Creating Accounts

First, let's create two accounts for our examples:

```crystal
# Create accounts outside a transaction since these are independent operations
alice_account = BankAccount.create!(
  account_number: "ACC-001",
  owner_name: "Alice Smith",
  balance: 1000.0,
  created_at: Time.utc,
  updated_at: Time.utc
)

bob_account = BankAccount.create!(
  account_number: "ACC-002",
  owner_name: "Bob Jones",
  balance: 500.0,
  created_at: Time.utc,
  updated_at: Time.utc
)

puts "Alice's initial balance: $#{alice_account.balance}" # $1000.0
puts "Bob's initial balance: $#{bob_account.balance}"     # $500.0
```

### Example 1: Simple Transfer Transaction

Let's look at what happens in a successful money transfer:

```crystal
# Using the TransferService which internally uses a transaction
success = BankingServices::TransferService.execute(
  alice_account,     # from account
  bob_account,       # to account
  150.0              # amount to transfer
)

if success
  # Reload accounts to see updated balances
  alice_account = BankAccount.find(alice_account.id)
  bob_account = BankAccount.find(bob_account.id)

  puts "Transfer successful!"
  puts "Alice's new balance: $#{alice_account.balance}" # $850.0
  puts "Bob's new balance: $#{bob_account.balance}"     # $650.0
else
  puts "Transfer failed"
end
```

Behind the scenes, here's what happened:
1. The service started a database transaction
2. It decreased Alice's balance by $150
3. It increased Bob's balance by $150
4. It created a transaction record for auditing
5. It created an audit log entry
6. All changes were committed as a single unit

If any step failed, the entire operation would have been rolled back, and both balances would remain unchanged.

### Example 2: Model Convenience Methods

Our `BankAccount` model provides convenient methods that call the service objects internally:

```crystal
# These methods call the respective service objects, which use transactions
alice_account.transfer_to(bob_account, 100.0)  # Transfer $100 from Alice to Bob
bob_account.deposit(200.0)                     # Deposit $200 to Bob's account
alice_account.withdraw(50.0)                   # Withdraw $50 from Alice's account

# Check updated balances
alice_account = BankAccount.find(alice_account.id)
bob_account = BankAccount.find(bob_account.id)
puts "Alice's balance after operations: $#{alice_account.balance}" # $700.0
puts "Bob's balance after operations: $#{bob_account.balance}"     # $950.0
```

### Example 3: Error Handling and Automatic Rollback

What happens when a transaction fails? Let's try to transfer more money than Alice has:

```crystal
# Attempt to transfer more money than available
begin
  # This should fail because Alice doesn't have $2000
  result = alice_account.transfer_to(bob_account, 2000.0)

  if !result
    puts "Transfer failed due to business rule validation"

    # Check that balances are unchanged
    alice_account = BankAccount.find(alice_account.id)
    bob_account = BankAccount.find(bob_account.id)
    puts "Alice's balance remains: $#{alice_account.balance}" # Still $700.0
    puts "Bob's balance remains: $#{bob_account.balance}"     # Still $950.0
  end
rescue ex
  puts "Error: #{ex.message}" # "Insufficient funds"

  # Balances remain unchanged due to automatic transaction rollback
  alice_account = BankAccount.find(alice_account.id)
  bob_account = BankAccount.find(bob_account.id)
end
```

The transaction automatically rolled back when the validation check in `TransferService` raised an exception, so no money was transferred, and no records were created.

### Example 4: Manual Transaction Control

Sometimes you need more direct control over transactions. Here's how to manually start, commit, or roll back transactions:

```crystal
# Using a transaction block with manual rollback logic
BankAccount.transaction do |tx|
  # Find accounts
  alice = BankAccount.find(alice_account.id)
  bob = BankAccount.find(bob_account.id)

  # Update balances
  alice.balance -= 300.0
  alice.save!

  bob.balance += 300.0
  bob.save!

  # Create transaction record
  transaction_record = Transaction.create!(
    amount: 300.0,
    transaction_type: "transfer",
    from_account_id: alice.id,
    to_account_id: bob.id,
    status: "completed",
    created_at: Time.utc
  )

  # Imagine some business rule that might cause us to roll back
  if alice.balance < 300.0 # For example, minimum balance requirement
    puts "Transaction would leave insufficient minimum balance"
    tx.rollback # Explicitly roll back all changes
    return false
  end

  # If we reach here, the transaction will be committed automatically
  puts "Manual transaction completed successfully"
end
```

This example shows that you can explicitly roll back a transaction when a specific condition is detected, giving you precise control over the transaction's outcome.

## Querying Transaction History

```crystal
# Get all transfers from a specific account
transfers_from = Transaction.query
  .from(:transactions)
  .where(from_account_id: alice_account.id)
  .all(Transaction)

# Get all money received by an account
transfers_to = Transaction.query
  .from(:transactions)
  .where(to_account_id: bob_account.id)
  .all(Transaction)

# Get account balance history through audit logs
account_history = AuditLog.query
  .from(:audit_logs)
  .where(entity_type: "bank_account", entity_id: alice_account.id)
  .order(created_at: :desc)
  .all(AuditLog)
```

## Best Practices for Transactions in CQL

Working with database transactions requires careful attention to ensure your application remains reliable and performs well. Here are detailed best practices to follow:

### 1. Keep transactions short and focused

Long-running transactions can cause several problems:
- They hold database locks longer, potentially blocking other operations
- They increase the risk of deadlocks when multiple transactions are running
- They're more likely to fail because they touch more data

Consider this example of a good transaction scope:

```crystal
# Good: Focused transaction that only handles the critical operations
def transfer_money(from_account, to_account, amount)
  BankAccount.transaction do |tx|
    # Only the essential balance updates are in the transaction
    from_account.balance -= amount
    from_account.save!

    to_account.balance += amount
    to_account.save!
  end

  # Non-critical operations happen outside the transaction
  send_notification_email(from_account.owner_name, amount)
  log_transfer_for_analytics(from_account.id, to_account.id, amount)
end
```

### 2. Validate data before entering transactions

Perform input validation outside the transaction when possible to avoid starting transactions that will inevitably fail:

```crystal
# Good: Validate before starting the transaction
def transfer_money(from_account, to_account, amount)
  # Validate outside the transaction
  raise "Amount must be positive" if amount <= 0
  raise "Insufficient funds" if from_account.balance < amount
  raise "Cannot transfer to same account" if from_account.id == to_account.id

  # Only start transaction after validation
  BankAccount.transaction do |tx|
    # Transaction code here...
  end
end
```

### 3. Handle exceptions properly

Always handle exceptions that might occur during a transaction:

```crystal
def transfer_money(from_account, to_account, amount)
  BankAccount.transaction do |tx|
    # Transaction code...
  end
rescue ex : DB::Error
  # Handle database-specific errors
  Log.error { "Database error during transfer: #{ex.message}" }
  notify_admin("Database error occurred", ex.message)
  false
rescue ex : Exception
  # Handle other exceptions
  Log.error { "Error during transfer: #{ex.message}" }
  false
end
```

### 4. Consider isolation levels when necessary

For advanced use cases, you might need to specify transaction isolation levels:

```crystal
# Example of setting isolation level (if supported by CQL)
BankAccount.transaction(isolation_level: :serializable) do |tx|
  # This transaction runs with serializable isolation
  # ensuring the highest level of data integrity
end
```

### 5. Avoid nested transactions when possible

While some databases support nested transactions, they can be confusing and may not work as expected:

```crystal
# Avoid this pattern
BankAccount.transaction do |tx1|
  # Some operations...

  BankAccount.transaction do |tx2|
    # More operations...

    # Which transaction does this rollback affect?
    tx2.rollback if some_condition
  end
end
```

Instead, refactor to use a single transaction or create separate methods with their own transactions.

## Troubleshooting Common Transaction Issues

When working with transactions, you might encounter these common issues:

### 1. Deadlocks

Deadlocks occur when multiple transactions are waiting for locks held by each other:

```crystal
# Transaction 1                 | # Transaction 2
BankAccount.transaction do      | BankAccount.transaction do
  account_a = BankAccount.find(1) |   account_b = BankAccount.find(2)
  account_a.balance += 100      |   account_b.balance += 100
  account_a.save!               |   account_b.save!
                               |
  account_b = BankAccount.find(2) |   account_a = BankAccount.find(1)
  account_b.balance -= 100      |   account_a.balance -= 100
  account_b.save!               |   account_a.save!
end                            | end
```

**Solution**: Always access resources in the same order:

```crystal
# Both transactions should access accounts in ID order
def transfer_between_accounts(account1, account2, amount)
  # Sort accounts by ID to ensure consistent access order
  first, second = [account1, account2].sort_by(&.id)

  BankAccount.transaction do |tx|
    # Now both transactions will access accounts in the same order,
    # preventing deadlocks
    first.reload  # Get fresh data
    second.reload

    # Perform operations...
  end
end
```

### 2. Silent Transaction Failures

Sometimes transactions fail silently if exceptions are swallowed:

```crystal
# Problematic: Exception is caught but failure is ignored
def transfer_money(from_account, to_account, amount)
  begin
    BankAccount.transaction do |tx|
      # Transaction code...
    end
  rescue ex
    # Bad: Just logging without returning failure status
    Log.error { ex.message }
  end

  # This will always execute, even if the transaction failed!
  send_success_notification
end
```

**Solution**: Always propagate or properly handle transaction failures:

```crystal
# Better approach
def transfer_money(from_account, to_account, amount)
  begin
    BankAccount.transaction do |tx|
      # Transaction code...
    end

    # Only send notification if transaction succeeded
    send_success_notification
    return true
  rescue ex
    Log.error { ex.message }
    send_failure_notification
    return false
  end
end
```

### 3. Connection Issues

Database connections can fail during transactions:

**Solution**: Implement reconnection logic and retry mechanisms:

```crystal
def transfer_with_retry(from_account, to_account, amount, max_retries = 3)
  retries = 0

  begin
    BankAccount.transaction do |tx|
      # Transaction code...
    end
  rescue ex : DB::ConnectionError
    retries += 1
    if retries <= max_retries
      Log.warn { "Connection failed, retrying (#{retries}/#{max_retries})" }
      sleep(0.5 * retries)  # Exponential backoff
      retry
    else
      Log.error { "Max retries reached for transaction" }
      raise
    end
  end
end
```

## The Service Objects Pattern: A Deep Dive

The service objects pattern is particularly valuable for complex transaction logic. Here's why you should consider it:

### 1. Single Responsibility Principle

Each service handles one specific business operation, making your code easier to understand:

```crystal
# Each service has a clear, focused purpose
module BankingServices
  class DepositService
    # Handles only deposits
  end

  class WithdrawalService
    # Handles only withdrawals
  end

  class TransferService
    # Handles only transfers
  end
end
```

### 2. Better Testability

Services can be tested in isolation without complex setup:

```crystal
# Testing a service is straightforward
def test_withdrawal_service
  account = BankAccount.new(id: 1, balance: 1000.0, account_number: "TEST-001", owner_name: "Test User")

  # Test successful withdrawal
  result = BankingServices::WithdrawalService.execute(account, 500.0)
  assert result == true
  assert account.balance == 500.0

  # Test insufficient funds
  result = BankingServices::WithdrawalService.execute(account, 1000.0)
  assert result == false
  assert account.balance == 500.0  # Balance unchanged
end
```

### 3. Code Organization

Complex business logic is separated from your models, keeping them focused on data structure:

```crystal
# Model stays focused on structure, not behavior
struct BankAccount
  include CQL::ActiveRecord::Model(Int32)

  property id : Int32?
  property balance : Float64
  # Other properties...

  # Simple delegation to service objects
  def withdraw(amount)
    BankingServices::WithdrawalService.execute(self, amount)
  end
end
```

### 4. Reusable Business Logic

Services can be called from different parts of your application:

```crystal
# In a controller
post "/withdraw" do |env|
  account_id = env.params.json["account_id"].as(Int32)
  amount = env.params.json["amount"].as(Float64)

  account = BankAccount.find(account_id)

  # Use the service directly
  result = BankingServices::WithdrawalService.execute(account, amount)

  if result
    {success: true, balance: account.balance}.to_json
  else
    {success: false, error: "Withdrawal failed"}.to_json
  end
end

# In a background job
def process_scheduled_payments
  scheduled_payments.each do |payment|
    # Reuse the same service
    BankingServices::WithdrawalService.execute(payment.account, payment.amount)
  end
end
```

### 5. Clear Error Management

Services provide a consistent way to handle and report errors:

```crystal
module BankingServices
  class WithdrawalService
    # ...

    def execute
      begin
        validate!
        perform_withdrawal
        true
      rescue ValidationError => e
        # Business validation error
        @errors << e.message
        false
      rescue DatabaseError => e
        # Technical error
        Log.error { "Database error: #{e.message}" }
        @errors << "Technical error occurred"
        false
      end
    end

    def errors
      @errors
    end
  end
end
```

By implementing these best practices and understanding common issues, you'll be able to use transactions effectively in your CQL applications, ensuring data integrity while maintaining good performance and code quality.
