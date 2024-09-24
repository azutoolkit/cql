# Updating Records

The `CQL::Update` class in the CQL (Crystal Query Language) module is designed to represent and execute SQL `UPDATE` statements in a clean and structured manner. This guide will walk you through using the class to update records in a database, providing real-world examples and detailed explanations for each method.

---

#### Key Features

1. **Update records** in a database with a simple and readable syntax.
2. **Set column values** dynamically using hashes or keyword arguments.
3. **Filter records** with flexible `WHERE` conditions.
4. **Return updated columns** after executing the query.
5. **Chainable methods** for building complex queries effortlessly.

---

#### Real-World Example: Updating a User's Data

Let’s start with a simple example of updating a user’s name and age in the `users` table.

```crystal
update = CQL::Update.new(schema)
  .table(:users)
  .set(name: "John", age: 30)
  .where { |w| w.id == 1 }
  .commit
```

This example updates the user with `id = 1` to have the name "John" and age 30.

---

### Core Methods

Below is a detailed breakdown of the key methods in the `CQL::Update` class and how to use them.

#### 1. `table(table : Symbol)`

**Purpose**: Specifies the table to update.

- **Parameters**: `table` — A symbol representing the table name.
- **Returns**: `Update` object (for chaining).

**Real-World Example: Setting the Target Table**

```crystal
update.table(:users)
```

This sets the `users` table as the target for the update operation.

---

#### 2. `set(setters : Hash(Symbol, DB::Any))`

**Purpose**: Specifies the column values to update using a hash.

- **Parameters**: `setters` — A hash where keys are column names and values are the new values for those columns.
- **Returns**: `Update` object (for chaining).

**Real-World Example: Updating Multiple Columns**

```crystal
update
  .table(:users)
  .set(name: "John", age: 30)
```

This sets the `name` and `age` columns to new values for the target record(s).

---

#### 3. `set(**fields)`

**Purpose**: Specifies the column values to update using keyword arguments.

- **Parameters**: `fields` — Column-value pairs as keyword arguments.
- **Returns**: `Update` object (for chaining).

**Real-World Example: Using Keyword Arguments**

```crystal
update
  .table(:users)
  .set(name: "Alice", active: true)
```

This sets the `name` to "Alice" and `active` to `true`.

---

#### 4. `where(**fields)`

**Purpose**: Adds a `WHERE` clause to filter the records to be updated.

- **Parameters**: `fields` — A hash where keys are column names and values are the conditions to match.
- **Returns**: `Update` object (for chaining).

**Real-World Example: Filtering by a Condition**

```crystal
update
  .table(:users)
  .set(name: "John", age: 30)
  .where(id: 1)
```

This adds a condition to only update the user where `id = 1`.

---

#### 5. `where(&block)`

**Purpose**: Adds a `WHERE` clause using a block for more complex conditions.

- **Parameters**: Block that db_contexts the condition using a filter builder.
- **Returns**: `Update` object (for chaining).

**Real-World Example: Using a Block for Conditions**

```crystal
update
  .table(:users)
  .set(name: "John")
  .where { |w| w.id == 1 && w.active == true }
```

This example updates the user where both `id = 1` and `active = true`.

---

#### 6. `commit`

**Purpose**: Executes the `UPDATE` query and commits the changes to the database.

- **Returns**: A `DB::Result` object, which represents the result of the query execution.

**Real-World Example: Committing the Update**

```crystal
update = CQL::Update.new(schema)
  .table(:users)
  .set(name: "John", age: 30)
  .where { |w| w.id == 1 }
  .commit
```

This commits the changes to the `users` table, updating the user with `id = 1`.

---

#### 7. `back(*columns : Symbol)`

**Purpose**: Specifies the columns to return after the update.

- **Parameters**: `columns` — An array of symbols representing the columns to return.
- **Returns**: `Update` object (for chaining).

**Real-World Example: Returning Updated Columns**

```crystal
update
  .table(:users)
  .set(name: "John", age: 30)
  .where(id: 1)
  .back(:name, :age)
  .commit
```

This will return the updated `name` and `age` columns after the update.

---

#### 8. `to_sql(gen = @schema.gen)`

**Purpose**: Generates the SQL query and the parameters required for the `UPDATE` statement.

- **Parameters**: `gen` — The generator used for SQL generation (default: schema generator).
- **Returns**: A tuple containing the SQL query string and the parameters.

**Real-World Example: Generating SQL for an Update**

```crystal
update = CQL::Update.new(schema)
  .table(:users)
  .set(name: "John", age: 30)
  .where(id: 1)

sql, params = update.to_sql
puts sql     # "UPDATE users SET name = $1, age = $2 WHERE id = $3"
puts params  # ["John", 30, 1]
```

This generates the raw SQL query and its associated parameters without executing it.

---

### Putting It All Together

Let’s combine multiple methods to handle a more advanced use case. Suppose you want to update a user's data, but only if they are active, and you want to return their updated email address afterward:

```crystal
update = CQL::Update.new(schema)

result = update
  .table(:users)
  .set(name: "Charlie", email: "charlie@example.com")
  .where { |w| w.id == 1 && w.active == true }
  .back(:email)
  .commit

puts result  # This will return the updated email address of the user.
```

In this query:

- We specify the `users` table.
- We update both the `name` and `email` of the user.
- We filter the update to only apply to the active user with `id = 1`.
- We return the updated `email` after the update is committed.

---

### Conclusion

The `CQL::Update` class provides a simple yet powerful interface for building and executing `UPDATE` queries in a Crystal application. With chainable methods for setting values, applying conditions, and controlling the output, you can easily handle any update operation.

Whether you are updating single records or large batches, the flexibility of `CQL::Update` ensures that your queries remain clean, maintainable, and efficient.
