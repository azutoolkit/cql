# CRUD Operations

CQL Active Record models provide a rich set of methods for performing CRUD (Create, Read, Update, Delete) operations on your database records. These methods are designed to be intuitive and align with common Active Record patterns.

This guide assumes you have a model defined, for example:

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context AcmeDB, :users
  property id : Int64?
  property name : String
  property email : String
  property active : Bool = false
  # ... other properties and initializers ...
end
```

***

## 1. Creating Records

There are several ways to create new records and persist them to the database.

### `new` + `save` / `save!`

The most fundamental way is to create a new instance of your model using `new` and then call `save` or `save!` to persist it.

* **`save`**: Attempts to save the record. Runs validations. If successful, populates the `id` (if auto-generated) and returns `true`. If validations fail or another `before_save` callback halts the chain, it returns `false` and does not persist the record. The `errors` collection on the instance can be inspected.
* **`save!`**: Similar to `save`, but raises an exception if the record cannot be saved.
  * Raises `CQL::Errors::RecordInvalid` if validations fail.
  * May raise other database-related exceptions or `CQL::Errors::RecordNotSaved` for other save failures.

```crystal
# Using save (returns true/false)
user1 = User.new(name: "John Doe", email: "john.doe@example.com")
if user1.save
  puts "User '#{user1.name}' saved with ID: #{user1.id.not_nil!}"
else
  puts "Failed to save user '#{user1.name}': #{user1.errors.full_messages.join(", ")}"
end

# Using save! (raises on failure)
try
  user2 = User.new(name: "Jane Doe", email: "jane.doe@example.com")
  user2.save!
  puts "User '#{user2.name}' saved with ID: #{user2.id.not_nil!}"
rescue ex : CQL::Errors::RecordInvalid
  puts "Validation error for '#{user2.name}': #{ex.record.errors.full_messages.join(", ")}"
rescue ex : Exception # Catch other potential save errors
  puts "Could not save user '#{user2.name}': #{ex.message}"
end
```

### `create` / `create!` (Class Methods)

These class methods provide a convenient way to instantiate and save a record in a single step.

* **`Model.create(attributes)`**: Creates a new instance with the given attributes (as a Hash or keyword arguments) and attempts to `save` it. Returns the model instance (which might be invalid and not persisted if `save` failed) or `false` if a `before_create` callback halted the process.
* **`Model.create!(attributes)`**: Similar to `create`, but calls `save!` internally. It will raise an exception (`CQL::Errors::RecordInvalid` or other) if the record cannot be created and persisted.

```crystal
# Using create! (raises on failure)
try
  user3 = User.create!(name: "Alice Wonderland", email: "alice@example.com", active: true)
  puts "User '#{user3.name}' created with ID: #{user3.id.not_nil!}"

  # You can also pass a hash:
  attrs = {name: "Bob The Builder", email: "bob@example.com"}
  user4 = User.create!(attrs)
  puts "User '#{user4.name}' created with ID: #{user4.id.not_nil!}"
rescue ex : CQL::Errors::RecordInvalid
  puts "Failed to create user: #{ex.record.errors.full_messages.join(", ")}"
rescue ex : Exception
  puts "Failed to create user: #{ex.message}"
end

# Using create (less common for direct use, as error handling requires checking instance.errors)
user5_attrs = {name: "Valid User", email: "valid@example.com"}
user5 = User.create(user5_attrs)
if user5 && user5.persisted?
  puts "User '#{user5.name}' created."
elsif user5 # Instance returned but not persisted
  puts "Failed to create user '#{user5.name}': #{user5.errors.full_messages.join(", ")}"
else # Create might return false directly
  puts "User creation completely halted (e.g., by a before_create callback)."
end
```

### `find_or_create_by` (Class Method)

This method attempts to find a record matching the given attributes. If found, it returns that record. If not found, it creates and persists a new record with those attributes (plus any additional ones provided if the find attributes are a subset of create attributes).

* It uses `create!` internally for the creation part, so it can raise exceptions if the creation fails (e.g., due to validations).

```crystal
# Attempts to find a user by email. If not found, creates with name and email.
user_charlie = User.find_or_create_by(email: "charlie@example.com", name: "Charlie Brown")
puts "User '#{user_charlie.name}' (ID: #{user_charlie.id.not_nil!}) is present."

# If called again with the same email, it will find the existing record.
# The name attribute here would be ignored if only email is used for finding.
user_charlie_again = User.find_or_create_by(email: "charlie@example.com", name: "Charles Brown (updated attempt)")
puts "Found user '#{user_charlie_again.name}' again (ID: #{user_charlie_again.id.not_nil!}). Name should be 'Charlie Brown' unless attributes were updated separately."

# It's common to pass all necessary attributes for creation:
user_diana = User.find_or_create_by(email: "diana@example.com", name: "Diana Prince", active: true)
puts "User '#{user_diana.name}' created or found."
```

***

## 2. Reading Records

CQL provides various methods to retrieve records from the database. Many of these are covered in detail in the [Querying Guide](../guides/active-record-with-cql/querying.md).

**Summary of Common Finders:**

*   **`Model.all`**: Retrieves all records of the model type. Returns `Array(Model)`.

    ```crystal
    all_users = User.all
    ```
*   **`Model.find?(id : Pk)`** (or `Model.find(id : Pk)`): Finds a record by its primary key. Returns `Model?` (the instance or `nil`).

    ```crystal
    maybe_user = User.find?(1_i64)
    ```
*   **`Model.find!(id : Pk)`**: Finds a record by its primary key. Returns `Model` or raises `DB::NoResultsError` (or similar if not found).

    ```crystal
    # user = User.find!(1_i64)
    ```
*   **`Model.find_by(**attributes)`**: Finds the first record matching the given attributes. Returns `Model?`.

    ```crystal
    active_admin = User.find_by(active: true, role: "admin")
    ```
*   **`Model.find_by!(**attributes)`**: Finds the first record matching attributes. Returns `Model`or raises`DB::NoResultsError`.

    ```crystal
    # specific_user = User.find_by!(email: "jane.doe@example.com")
    ```
*   **`Model.find_all_by(**attributes)`**: Finds all records matching attributes. Returns `Array(Model)`.

    ```crystal
    all_active_users = User.find_all_by(active: true)
    ```
* **`Model.first`**: Retrieves the first record (ordered by primary key). Returns `Model?`.
* **`Model.last`**: Retrieves the last record (ordered by primary key). Returns `Model?`.
* **`Model.count`**: Returns the total number of records as `Int64`.
* **`Model.query.[condition].count`**: Counts records matching specific conditions.

For building more complex queries (e.g., with joins, specific selections, grouping), refer to the [Querying Guide](../guides/active-record-with-cql/querying.md).

***

## 3. Updating Records

To update existing records, you typically load an instance, modify its attributes, and then save it.

### Load, Modify, and `save` / `save!`

This is the standard approach:

```crystal
if user_to_update = User.find_by(email: "john.doe@example.com")
  user_to_update.active = true
  user_to_update.name = "Johnathan Doe"
  # user_to_update.updated_at = Time.utc # Often handled by callbacks or DB

  if user_to_update.save
    puts "User '#{user_to_update.name}' updated."
  else
    puts "Failed to update '#{user_to_update.name}': #{user_to_update.errors.full_messages.join(", ")}"
  end
end

# Using save! for updates (raises on failure)
if user_jane = User.find_by(email: "jane.doe@example.com")
  user_jane.name = "Jane D. Updated"
  begin
    user_jane.save!
    puts "User '#{user_jane.name}' updated successfully with save!"
  rescue ex : CQL::Errors::RecordInvalid
    puts "Failed to update '#{user_jane.name}': #{ex.record.errors.full_messages.join(", ")}"
  rescue ex : Exception
    puts "Failed to update '#{user_jane.name}': #{ex.message}"
  end
end
```

### `update` / `update!` (Instance Methods)

These instance methods provide a shortcut to assign attributes and then save the record.

* **`instance.update(attributes)`**: Assigns the given attributes (Hash or keyword arguments) to the instance and then calls `save`. Returns `true` if successful, `false` otherwise.
* **`instance.update!(attributes)`**: Assigns attributes and calls `save!`. Raises an exception if saving fails (e.g., `CQL::Errors::RecordInvalid`).

```crystal
if user_alice = User.find_by(email: "alice@example.com")
  begin
    # Using update!
    user_alice.update!(active: false, name: "Alice Inactive")
    puts "User '#{user_alice.name}' updated with instance update!"

    # Using update (returns true/false)
    if user_alice.update(name: "Alice Active Again")
      puts "User '#{user_alice.name}' updated with instance update."
    else
      puts "Failed to update Alice with instance update: #{user_alice.errors.full_messages.join(", ")}"
    end
  rescue ex : Exception
    puts "Exception during Alice's update!: #{ex.message}"
  end
end
```

### `Model.update!(id, attributes)` (Class Method)

This class method updates a record identified by its primary key with the given attributes. It typically loads the record, updates attributes, and calls `save!`. Can raise `DB::NoResultsError` if the ID is not found, or validation/save exceptions.

```crystal
# Assuming user_bob was created earlier and user_bob.id is available
if user_bob_id = some_user_id_variable # e.g., user_bob.id.not_nil!
  begin
    User.update!(user_bob_id, active: true, name: "Robert The Great")
    puts "User ID #{user_bob_id} updated via class update!"

    # Can also take a hash for attributes
    # User.update!(user_bob_id, {name: "Robert The Builder Again"})
  rescue ex : DB::NoResultsError
    puts "User ID #{user_bob_id} not found for update."
  rescue ex : CQL::Errors::RecordInvalid
    puts "Validation failed for User ID #{user_bob_id}: #{ex.record.errors.full_messages.join(", ")}"
  rescue ex : Exception
    puts "Failed to update User ID #{user_bob_id}: #{ex.message}"
  end
end
```

### Batch Updates (`Model.update_by`, `Model.update_all`)

These methods allow updating multiple records at once without instantiating each one.

* **`Model.update_by(conditions_hash, updates_hash)`**: Updates all records matching `conditions_hash` with the attributes in `updates_hash`.
* **`Model.update_all(updates_hash)`**: Updates all records in the table with the attributes in `updates_hash`. **Use with extreme caution!**

These methods typically execute a single SQL `UPDATE` statement and do **not** instantiate records, run validations, or trigger callbacks.

```crystal
# Example: Make all users with email ending in '@example.com' inactive.
# Assuming a direct SQL condition is needed or `update_by` supports patterns.
# The exact capabilities of `update_by` for conditions might vary; consult CQL specifics.
# For a simple equality condition:
User.update_by({role: "guest"}, {active: false, updated_at: Time.utc})
puts "Deactivated all guest users."

# Example: Update all users to have a default status (use carefully!)
# User.update_all({status: "pending_review", updated_at: Time.utc})
# puts "Set all users to pending_review status."
```

***

## 4. Deleting Records

Records can be deleted individually or in batches.

### `delete!` (Instance Method)

Deletes the specific model instance from the database.

* Runs `before_destroy` and `after_destroy` callbacks.
* Returns `true` if successful. Returns `false` if a `before_destroy` callback halts the operation.

```crystal
if user_to_delete = User.find_by(email: "charlie@example.com")
  puts "Attempting to delete user: #{user_to_delete.name}"
  if user_to_delete.delete!
    puts "User '#{user_to_delete.name}' deleted successfully."
  else
    puts "Failed to delete user '#{user_to_delete.name}' (perhaps a before_destroy callback halted?)."
  end
else
  puts "User to delete not found."
end
```

### `Model.delete!(id : Pk)` (Class Method)

Deletes the record with the specified primary key directly from the database.

* This method typically does **not** run Active Record callbacks (`before_destroy`, `after_destroy`) as it usually issues a direct SQL `DELETE` command.
* It might raise an exception if the record doesn't exist or if there's a database error.

```crystal
if some_user = User.find_by(email: "user_to_delete_by_id@example.com")
  user_id_to_delete = some_user.id.not_nil!
  begin
    User.delete!(user_id_to_delete)
    puts "User ID #{user_id_to_delete} deleted via class delete! (callbacks likely skipped)."
  rescue ex : Exception
    puts "Failed to delete User ID #{user_id_to_delete} via class delete!: #{ex.message}"
  end
end
```

### Batch Deletes (`Model.delete_by!`, `Model.delete_all`)

These class methods delete multiple records based on conditions or all records from a table.

* **`Model.delete_by!(attributes_hash)`**: Deletes all records matching the `attributes_hash`.
* **`Model.delete_all`**: Deletes all records from the model's table. **Use with extreme caution!**

These methods typically execute direct SQL `DELETE` statements and do **not** instantiate records or run Active Record callbacks.

```crystal
# Delete all users marked as inactive
User.delete_by!(active: false)
puts "Deleted all inactive users (callbacks likely skipped)."

# Delete all records from the users table (USE WITH EXTREME CAUTION!)
# User.delete_all
# puts "Deleted all users from the table (callbacks likely skipped)."
```

Always be careful with batch delete operations, especially `delete_all`, as they can lead to irreversible data loss if not used correctly.

***

This guide covers the primary CRUD operations available in CQL Active Record. For more advanced querying, refer to the [Querying Guide](../guides/active-record-with-cql/querying.md), and for information on lifecycle events and data integrity, see the guides on [Callbacks](callbacks.md) and [Validations](validations.md).
