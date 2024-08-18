# Deleting Records

The `Cql::Delete` class provides a structured and flexible way to build and execute SQL `DELETE` queries in your Crystal applications. This guide will help you understand how to create delete queries, apply conditions, and execute them to remove records from your database.

***

#### Key Features

1. **Delete records** from any table in a straightforward manner.
2. **Filter records** to delete using flexible `WHERE` conditions.
3. **Return columns** after deletion if needed.
4. **Chainable syntax** for clean and maintainable query building.

***

#### Real-World Example: Deleting a User Record

Let’s start with a simple example of deleting a user from the `users` table where the `id` is 1.

```crystal
delete = Cql::Delete.new(schema)
  .from(:users)
  .where(id: 1)
  .commit
```

This query deletes the record in the `users` table where `id = 1`.

***

### Core Methods

The following section provides a breakdown of the key methods available in the `Cql::Delete` class and how to use them effectively.

#### 1. `from(table : Symbol)`

**Purpose**: Specifies the table from which records will be deleted.

* **Parameters**: `table` — A symbol representing the table name.
* **Returns**: `Delete` object (for chaining).

**Real-World Example: Specifying the Table**

```crystal
delete.from(:users)
```

This sets the `users` table as the target for the delete operation.

***

#### 2. `where(**fields)`

**Purpose**: Adds a `WHERE` clause to filter the records to be deleted.

* **Parameters**: `fields` — A key-value hash where keys represent column names and values represent the conditions to match.
* **Returns**: `Delete` object (for chaining).

**Real-World Example: Filtering by Conditions**

```crystal
delete
  .from(:users)
  .where(id: 1)
```

This filters the query to only delete the user where `id = 1`.

***

#### 3. `where(&block)`

**Purpose**: Adds a `WHERE` clause using a block for more complex filtering conditions.

* **Parameters**: A block that defines the filtering logic using a filter builder.
* **Returns**: `Delete` object (for chaining).

**Real-World Example: Using a Block for Conditions**

```crystal
delete
  .from(:users)
  .where { |w| w.age < 30 }
```

This deletes all users where the `age` is less than 30.

***

#### 4. `commit`

**Purpose**: Executes the delete query and commits the changes to the database.

* **Returns**: A `DB::Result` object representing the result of the query execution.

**Real-World Example: Committing the Delete**

```crystal
delete = Cql::Delete.new(schema)
  .from(:users)
  .where(id: 1)
  .commit
```

This deletes the user from the `users` table where `id = 1` and commits the change.

***

#### 5. `using(table : Symbol)`

**Purpose**: Adds a `USING` clause to the delete query, useful when deleting records based on conditions from another table.

* **Parameters**: `table` — A symbol representing the name of the table to use in the `USING` clause.
* **Returns**: `Delete` object (for chaining).

**Real-World Example: Using Another Table for Deletion**

```crystal
delete
  .from(:users)
  .using(:posts)
  .where { |w| w.posts.user_id == w.users.id }
```

This example deletes users where they are linked to posts based on the condition `posts.user_id = users.id`.

***

#### 6. `back(*columns : Symbol)`

**Purpose**: Specifies the columns to return after the delete operation.

* **Parameters**: `columns` — An array of symbols representing the columns to return.
* **Returns**: `Delete` object (for chaining).

**Real-World Example: Returning Columns After Deletion**

```crystal
delete
  .from(:users)
  .where(id: 1)
  .back(:name, :email)
  .commit
```

This deletes the user with `id = 1` and returns the `name` and `email` of the deleted record.

***

#### 7. `to_sql(gen = @schema.gen)`

**Purpose**: Generates the SQL query and parameters required for the delete operation.

* **Parameters**: `gen` — The generator used for SQL generation (default: schema generator).
* **Returns**: A tuple containing the SQL query string and the parameters.

**Real-World Example: Generating SQL for Deletion**

```crystal
delete = Cql::Delete.new(schema)
  .from(:users)
  .where(id: 1)

sql, params = delete.to_sql
puts sql     # "DELETE FROM users WHERE id = $1"
puts params  # [1]
```

This generates the raw SQL query and its associated parameters without executing it.

***

### Putting It All Together

Let’s combine multiple methods to handle a more advanced use case. Suppose you want to delete a user from the `users` table where they have no associated posts, and you want to return the deleted user’s name and email:

```crystal
delete = Cql::Delete.new(schema)

result = delete
  .from(:users)
  .using(:posts)
  .where { |w| w.posts.user_id == w.users.id && w.posts.id.nil? }
  .back(:name, :email)
  .commit

puts result  # This returns the name and email of the deleted user(s).
```

In this query:

* We specify the `users` table as the target for deletion.
* We use the `posts` table to filter users without any posts.
* We return the `name` and `email` of the deleted user(s).

***

### Conclusion

The `Cql::Delete` class provides an intuitive and powerful interface for deleting records in your Crystal applications. With chainable methods for setting conditions, joining tables, and selecting return columns, you can easily construct and execute delete queries with precision and clarity.

Whether you need to delete specific records or perform complex, condition-based deletions, the `Cql::Delete` class ensures that your queries are efficient and maintainable.
