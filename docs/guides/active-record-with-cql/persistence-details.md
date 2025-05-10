# Persistence Details

Beyond basic CRUD operations, CQL Active Record models offer methods to understand and manage their persistence state.

This guide assumes you have a model defined, for example:

```crystal
# struct User
#   include CQL::ActiveRecord::Model(Int64)
#   db_context AcmeDB, :users
#   property id : Int64?
#   # ... other properties ...
# end
```

---

## Checking Persistence Status

It's often useful to know if a model instance represents a record that already exists in the database or if it's a new record that hasn't been saved yet.

### `persisted?`

The `persisted?` instance method returns `true` if the record is considered to be saved in the database, and `false` otherwise. Typically, this means the instance has a non-nil primary key (`id`).

```crystal
# New, unsaved record
new_user = User.new(name: "Temp User", email: "temp@example.com")
puts "Is new_user persisted? #{new_user.persisted?}" # => false
puts "new_user ID: #{new_user.id.inspect}" # => nil (assuming id is Int64? and auto-generated)

# Save the record
if new_user.save
  puts "User saved."
  puts "Is new_user persisted now? #{new_user.persisted?}" # => true
  puts "new_user ID after save: #{new_user.id.inspect}"    # => 1 (or some other generated ID)
else
  puts "Failed to save new_user."
end

# Loaded record
existing_user = User.find?(new_user.id.not_nil!) # Find the user we just saved
if existing_user
  puts "Is existing_user persisted? #{existing_user.persisted?}" # => true
  puts "existing_user ID: #{existing_user.id.inspect}"
end
```

Use `persisted?` to:

- Differentiate between new and existing records in forms or views.
- Decide whether an update or an insert operation is appropriate in more manual scenarios.
- Conditionally execute logic based on whether a record is already in the database.

### `new_record?` (Conceptual / Alias for `!persisted?`)

Some ORMs provide a `new_record?` method, which is typically the opposite of `persisted?`. While CQL's core `Persistence` module might not explicitly define `new_record?`, you can achieve the same by checking `!instance.persisted?`.

```crystal
user = User.new(name: "Another Temp", email: "another@example.com")
if !user.persisted?
  puts "This is a new record (not persisted)."
end
```

---

## Reloading Records

Sometimes, the data for a record in your application might become stale if the corresponding row in the database has been changed by another process or a different part of your application. The `reload!` method allows you to refresh an instance's attributes from the database.

### `reload!`

The `reload!` instance method fetches the latest data from the database for the current record (identified by its primary key) and updates the instance's attributes in place.

- If the record no longer exists in the database (e.g., it was deleted by another process), `reload!` will typically raise a `DB::NoResultsError` or a similar `RecordNotFound` exception.

```crystal
# Assume user_jane exists and her email is "jane.doe@example.com"
user_jane = User.find_by!(email: "jane.doe@example.com")
puts "Initial name for Jane: #{user_jane.name}"

# Simulate an external update to the database for this user
# (In a real scenario, this would happen outside this code flow)
# For example, directly via SQL: UPDATE users SET name = 'Jane Updated Externally' WHERE id = user_jane.id;

# Now, reload user_jane to get the latest data
try
  user_jane.reload!
  puts "Reloaded name for Jane: #{user_jane.name}" # Should show "Jane Updated Externally"

  # If user_jane was deleted externally before reload!
  # user_jane.reload! # This would raise DB::NoResultsError
rescue DB::NoResultsError
  puts "Record for user '#{user_jane.name}' (ID: #{user_jane.id}) no longer exists in the database."
rescue ex : Exception
  puts "An error occurred during reload: #{ex.message}"
end
```

Use `reload!` when:

- You need to ensure you are working with the most up-to-date version of a record, especially before performing critical operations or displaying sensitive data.
- You suspect an instance's state might be out of sync with the database due to concurrent operations.

---

Understanding these persistence details helps in managing the lifecycle and state of your Active Record model instances effectively.
