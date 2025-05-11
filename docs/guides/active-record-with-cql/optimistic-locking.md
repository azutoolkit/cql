# Optimistic Locking in CQL

Optimistic locking is a concurrency control strategy that allows multiple transactions to proceed without blocking each other, while still preventing conflicts from concurrent updates. CQL provides built-in support for optimistic locking through a version column mechanism.

## How It Works

1. A version column (e.g., an integer) is added to your database table.
2. When a record is read, its current version number is also fetched.
3. When an attempt is made to update the record, the ORM includes a condition in the `UPDATE` statement to check if the version number in the database is still the same as when it was fetched.
4. Simultaneously, the `UPDATE` statement also increments this version number.
5. If the version number in the database has changed (meaning another process updated the record in the meantime), the `WHERE` condition (e.g., `WHERE id = ? AND version = ?`) will not match any rows. The update will affect zero rows.
6. The ORM detects that no rows were affected and raises an `OptimisticLockError`, signaling that a concurrent update occurred.
7. The application must then handle this error, typically by reloading the record (to get the new version and latest data) and retrying the update.

## When to Use Optimistic Locking

Optimistic locking is particularly well-suited for scenarios where:

- **Conflicts are Rare:** You expect data conflicts to be infrequent. If conflicts are very common, the overhead of retrying transactions might outweigh the benefits.
- **High Concurrency is Required:** The application needs to support many users or processes accessing the same data concurrently, and you want to avoid the performance bottlenecks associated with pessimistic locking (which locks records for the duration of a transaction).
- **Read-Heavy Workloads:** Read operations are significantly more frequent than write operations. Optimistic locking doesn't impose any overhead on reads.
- **User-Facing Applications:** In applications where a user might have data форм open for a while before submitting changes, optimistic locking can prevent their changes from unknowingly overwriting updates made by others in the interim.
- **Disconnected or Stateless Environments:** Holding database locks across requests in a stateless web application or a distributed system can be complex or impractical. Optimistic locking provides a way to manage concurrency without long-lived locks.
- **Cost of Retry is Low:** The business logic can tolerate and gracefully handle retries. For example, if updating a product description fails due to a conflict, reloading and trying again is often acceptable.

It's generally not recommended if:

- Conflicts are very frequent, as this will lead to many retries and potentially poor performance.
- The cost of a failed transaction retry is very high (e.g., involving complex external API calls that are not idempotent).

## Setting Up Optimistic Locking

### 1. Add a Version Column to Your Table

When defining your table schema, add a version column using the `lock_version` method:

```crystal
table :users do
  primary :id, Int64
  varchar :name, String
  varchar :email, String
  lock_version :version # Adds an integer column named 'version' with default value 1
end
```

The `lock_version` method accepts the following parameters:

- `name` (Symbol): The name of the column (default: `:version`). This column should typically be an `Int32` or `Int64`.
- `as_name` (String?): An optional alias for the column in queries (rarely needed for version columns).
- `null` (Bool): Whether the column can be null (default: `false`). It's crucial that version columns are not nullable.
- `default` (DB::Any): The default value for new records (default: `1`).
- `index` (Bool): Whether to create an index on this column (default: `false`). Indexing might be beneficial if you query by version, but it's not strictly necessary for the locking mechanism itself.

### 2. Use Optimistic Locking with Raw Queries

When using raw queries, you can use the `with_optimistic_lock` method on the `Update` object:

```crystal
# Assuming 'schema' is your CQL::Schema instance
# And we have a record with id=1 and its current version is 5
begin
  update_result = CQL::Update.new(schema)
    .table(:users)
    .set(name: "John Doe", age: 31) # age is an example, ensure your table has it
    .where(id: 1)
    .with_optimistic_lock(version: 5) # Checks for version 5, will set to 6
    .commit

  if update_result.rows_affected == 1
    puts "Update successful!"
  end
rescue CQL::OptimisticLockError
  puts "Conflict detected! Record was updated by another process."
  # Implement retry logic: reload data and try update again
end
```

If another process has already updated the record (version is no longer 5), a `CQL::OptimisticLockError` will be raised by the `.commit` call (or specifically, by the underlying mechanism in `CQL::Update` when `with_optimistic_lock` is used and `rows_affected` is 0).

### 3. Use Optimistic Locking with Active Record

For Active Record models, include the `CQL::ActiveRecord::OptimisticLocking` module and define which column to use with the `optimistic_locking` macro:

```crystal
class User < CQL::ActiveRecord::Base # Assuming Base is your base AR class
  include CQL::ActiveRecord::OptimisticLocking

  # db_context points to your schema and table
  db_context MY_SCHEMA, :users # Replace MY_SCHEMA with your actual schema variable

  # Define properties matching your table columns
  property id : Int64?
  property name : String?
  property email : String?
  property version : Int32? # This will hold the lock version

  # Configure optimistic locking
  optimistic_locking version_column: :version
end
```

This will automatically handle version checking and incrementing when updating records:

```crystal
user = User.find!(1)
user.name = "Johnathan Doe"
begin
  user.update! # Uses optimistic locking automatically
  puts "User updated successfully. New version: #{user.version}"
rescue CQL::OptimisticLockError
  puts "Failed to update user: Optimistic lock conflict."
  # Handle the conflict, e.g., reload and retry
  user.reload!
  puts "Retrying update after reloading. Current version: #{user.version}"
  user.name = "Johnathan Doe" # Re-apply changes if necessary
  user.update! # Retry the update
  puts "User updated successfully on retry. New version: #{user.version}"
end
```

If a concurrent update has occurred, `user.update!` will raise a `CQL::OptimisticLockError`.

## Handling Concurrent Updates

When a `CQL::OptimisticLockError` is caught, your application needs to decide how to proceed. Common strategies include:

1. **Reload and Retry:**

    - Reload the record from the database to get the latest version and data.
    - Re-apply the intended changes to the newly reloaded record.
    - Attempt the update again.
    - You might want to limit the number of retries to avoid infinite loops in high-contention scenarios.

    ```crystal
    user = User.find!(1)
    max_retries = 3
    attempt = 0

    loop do
      attempt += 1
      user.name = "John Doe Updated" # Apply desired changes
      begin
        user.update!
        puts "Update successful!"
        break # Exit loop on success
      rescue CQL::OptimisticLockError
        if attempt >= max_retries
          puts "Max retries reached. Could not update record."
          # Potentially notify user or log a more persistent error
          break
        end
        puts "Optimistic lock conflict. Reloading and retrying (attempt #{attempt}/#{max_retries})..."
        user.reload! # Reloads the record's attributes, including the version
      end
    end
    ```

2. **Inform the User:**

    - If changes are being made through a UI, inform the user that the data has changed since they last viewed it.
    - Show them the updated data and allow them to decide whether to overwrite, merge their changes, or discard their changes.

3. **Merge Changes (Advanced):**
    - If possible and logical, attempt to merge the conflicting changes. This is highly application-specific and can be complex. For example, if one user changed the product description and another changed the price, these changes might be mergeable.

## Best Practices

1. **Use Transactions (Where Appropriate):** While optimistic locking handles concurrent updates to a single record, if your operation involves multiple database changes that must be atomic, ensure these are wrapped in a database transaction. Optimistic locking complements, rather than replaces, the need for transactions for atomicity of complex operations.
2. **Handle Conflicts Gracefully:** Provide a clear and understandable user experience when conflicts occur. Avoid cryptic error messages. Explain that the data was changed by someone else and suggest next steps.
3. **Selective Usage:** Apply optimistic locking to entities where concurrent modification is a realistic concern and data integrity is critical. Not every table or resource needs it. Overusing it can add unnecessary complexity.
4. **Always Reload on Conflict:** Before retrying an update after a conflict, _always_ reload the record. This ensures you have the latest version number and the most current state of other attributes, preventing further issues or lost updates.
5. **Combine with Other Techniques (If Needed):** For highly contended resources where optimistic lock failures become too frequent, you might need to explore other strategies for those specific parts of your application, such as more granular locking, CQRS patterns, or even considering pessimistic locking as a last resort if the cost of retries is too high.
6. **Choose the Right Version Column Type:** Typically, an `INTEGER` or `BIGINT` (`Int32` or `Int64` in Crystal) is suitable. Ensure it won't realistically overflow during the lifetime of a record.
7. **Atomic Increment by Database:** Rely on the database's atomicity for the `UPDATE ... SET version = version + 1 WHERE version = old_version` pattern. CQL's implementation handles this.
8. **Thorough Testing:** Write specific tests for conflict scenarios to ensure your conflict resolution logic works as expected. Simulate concurrent updates in your tests.
9. **Performance Monitoring:** Monitor the frequency of `OptimisticLockError`s. A consistently high rate might indicate that the "optimistic" assumption (conflicts are rare) is not holding for that particular resource, and a different concurrency strategy might be more efficient.

## Database-Specific Considerations

Optimistic locking, as implemented with a version column incremented by the application (via the ORM), is a widely portable pattern that works consistently across most relational databases. The core mechanism relies on standard SQL features (`UPDATE` with a `WHERE` clause checking the version and `SET` to increment it).

Here's how it generally applies to common databases used with Crystal:

### PostgreSQL

- **Behavior:** Works seamlessly. PostgreSQL's robust MVCC (Multi-Version Concurrency Control) architecture is well-suited for optimistic locking.
- **Version Column Type:** `INTEGER` or `BIGINT` are excellent choices.
- **Transactions:** PostgreSQL has strong ACID-compliant transactions. Use them to group related operations where atomicity is required, in conjunction with optimistic locking for individual record updates.
- **No Special Configuration:** No special database-level configuration is typically needed for CQL's optimistic locking to function correctly.

### MySQL

- **Behavior:** Works well, especially with the InnoDB storage engine (which is the default for modern MySQL versions and provides row-level locking and transactions).
- **Version Column Type:** `INT` or `BIGINT` are appropriate.
- **Transactions:** InnoDB supports ACID transactions. As with PostgreSQL, use transactions for atomicity of larger operations.
- **Isolation Levels:** While optimistic locking itself relies on the version check, ensure your transaction isolation level (e.g., `REPEATABLE READ` or `READ COMMITTED` for InnoDB) meets your application's general consistency requirements. Optimistic locking can help reduce the need for stricter isolation levels for the sole purpose of preventing lost updates.

### SQLite3

- **Behavior:** Optimistic locking is fully functional and effective with SQLite.
- **Version Column Type:** `INTEGER` is standard.
- **Concurrency Model:** SQLite, by default, serializes writes at the database level (multiple connections can read concurrently, but writes are typically queued). However, if your application has multiple threads or processes accessing the _same connection_ without proper external synchronization, or if multiple independent processes access the same database file, optimistic locking is still crucial to prevent lost updates.
- **WAL Mode:** Using Write-Ahead Logging (WAL) mode in SQLite can improve concurrency for readers and a single writer. Optimistic locking remains a valuable pattern even with WAL mode to manage conflicts if multiple writers _could_ conceptually attempt updates based on stale data.
- **Simplicity:** For simpler applications or embedded use cases where SQLite shines, optimistic locking provides a straightforward way to handle potential concurrency issues without complex locking mechanisms.

**In summary:** CQL's optimistic locking implementation is designed to be database-agnostic by relying on standard SQL patterns. The primary responsibility of the database is to atomically execute the conditional `UPDATE` statement. The choice of database mainly influences broader aspects like overall transaction management, concurrency capabilities, and performance characteristics, but the optimistic locking logic itself remains consistent.

## Limitations

- **Increased Retries:** Not suitable for high-contention resources where conflicts would occur very frequently, as this leads to many transaction rollbacks and retries, potentially degrading performance.
- **Application-Level Handling:** Requires application logic to catch the `OptimisticLockError` and implement a retry or conflict resolution strategy. It's not transparent like some pessimistic locking mechanisms.
- **Slight Write Overhead:** Each update involves checking and incrementing the version column, which is a minimal but present overhead compared to an update without version checking.
- **"Last Commit Wins" (Effectively):** While it prevents lost updates, the record will reflect the state of the last successful commit. If two users make conflicting changes, the first one to commit "wins" for that version, and the second must handle the conflict.
