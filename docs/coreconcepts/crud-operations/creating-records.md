# Creating Records

The `CQL::Insert` class in the CQL (Crystal Query Language) module is a powerful tool designed to simplify the process of inserting records into a database. As a software developer, you'll find this class essential for building `INSERT` queries in a clean, readable, and chainable way.

In this guide, we’ll walk through the core functionality, explain each method in detail, and provide real-world examples to help you understand how to integrate `CQL::Insert` into your applications.

---

#### Key Features

1. **Insert records into any table with ease**.
2. **Insert multiple records in a single query**.
3. **Insert records using data fetched from another query**.
4. **Get the last inserted ID after an insert**.
5. **Chainable, intuitive syntax** for building complex queries.

---

#### Real-World Example: Inserting User Data

Let’s start with a simple example of inserting a new user into the `users` table.

```crystal
insert
  .into(:users)
  .values(name: "Alice", email: "alice@example.com", age: 29)
  .commit
```

This example demonstrates how you can insert a new user with their name, email, and age using the `values` method, followed by `commit` to execute the insert.

---

### Core Methods

Let's dive into the individual methods and how you can use them.

#### 1. `into(table : Symbol)`

**Purpose**: Specifies the table into which the data will be inserted. This is your starting point for any insert operation.

- **Parameter**: `table` (Symbol) — The name of the table to insert into.
- **Returns**: `Insert` object (enabling chaining).

**Example**:

```crystal
insert.into(:users)
```

In the above code, we're targeting the `users` table. This is where subsequent data will be inserted.

---

#### 2. `values(**fields)`

**Purpose**: Specifies the data (fields and values) to insert. The `values` method can accept either a hash or keyword arguments.

- **Parameter**: `fields` (Hash or keyword arguments) — A mapping of column names to their values.
- **Returns**: `Insert` object (for chaining).

**Real-World Example 1: Adding a Single User**

```crystal
insert
  .into(:users)
  .values(name: "Bob", email: "bob@example.com", age: 35)
  .commit
```

Here, we’re adding a new user named Bob, specifying their `name`, `email`, and `age`.

**Real-World Example 2: Adding Multiple Users in One Query**

```crystal
insert
  .into(:users)
  .values([
    {name: "John", email: "john@example.com", age: 30},
    {name: "Jane", email: "jane@example.com", age: 25}
  ]).commit
```

This example demonstrates how you can insert multiple users in a single query. It’s efficient and reduces database round trips.

---

#### 3. `last_insert_id(as type : PrimaryKeyType = Int64)`

**Purpose**: Retrieves the ID of the last inserted row. This is incredibly useful when you need to work with the inserted record immediately after an insert, especially in cases where the primary key is automatically generated.

- **Parameter**: `type` (default: `Int64`) — The data type of the returned ID.
- **Returns**: The last inserted ID as `Int64` or the specified type.

**Example**:

```crystal
last_id = insert
  .into(:users)
  .values(name: "Charlie", email: "charlie@example.com", age: 22)
  .last_insert_id
puts last_id  # Outputs the last inserted ID
```

---

#### 4. `query(query : Query)`

**Purpose**: Instead of manually specifying values, you can use data fetched from another query to populate the insert. This is useful in situations like copying data from one table to another.

- **Parameter**: `query` — A query object that fetches the data to insert.
- **Returns**: `Insert` object (for chaining).

**Real-World Example: Copying Data from One Table to Another**

Imagine you want to copy user data from an archive table (`archived_users`) to the main `users` table.

```crystal
insert
  .into(:users)
  .query(select.from(:archived_users).where(active: true))
  .commit
```

In this example, we’re selecting all active users from `archived_users` and inserting them into the `users` table in one go.

---

#### 5. `back(*columns : Symbol)`

**Purpose**: After an insert operation, you may want to return certain columns, like an ID or timestamp. The `back` method allows you to specify which columns should be returned.

- **Parameter**: `columns` — One or more symbols representing the columns to return.
- **Returns**: `Insert` object (for chaining).

**Example**:

```crystal
insert
  .into(:users)
  .values(name: "David", email: "david@example.com", age: 28)
  .back(:id)
  .commit
```

In this case, after inserting the new user, we’re returning the `id` of the newly inserted row.

---

#### 6. `commit`

**Purpose**: Executes the built `INSERT` query and commits the transaction to the database. This is the final step in your insert operation.

- **Returns**: The result of the insert, typically the number of affected rows or the last inserted ID.

**Example**:

```crystal
insert
  .into(:users)
  .values(name: "Eva", email: "eva@example.com", age: 31)
  .commit
```

This will execute the `INSERT` statement and commit it to the database, saving the new user’s data.

---

#### Advanced Example: Using Insert with Chained Operations

Let’s consider a more advanced example where you insert a new user, return their ID, and use it in subsequent operations.

```crystal
user_id = insert
  .into(:users)
  .values(name: "Frank", email: "frank@example.com", age: 27)
  .last_insert_id

# Now use `user_id` in another query, e.g., to insert into a related table
insert
  .into(:user_profiles)
  .values(user_id: user_id, bio: "Software developer from NYC", twitter: "@frankdev")
  .commit
```

In this example, after inserting the new user, we immediately get the `user_id` and use it to insert data into the `user_profiles` table.

---

### Handling Errors

In case an insert operation fails, the `commit` method automatically logs the error and raises an exception. This allows you to catch and handle the error as needed in your application.

**Example**:

```crystal
begin
  insert
    .into(:users)
    .values(name: nil)  # This will likely fail due to a NOT NULL constraint
    .commit
rescue ex
  puts "Insert failed: #{ex.message}"
end
```

---

### Conclusion

The `CQL::Insert` class provides a flexible, chainable interface for inserting data into a database, whether you're inserting a single record, multiple records, or even records based on the results of a query. Its intuitive API makes it easy to use in real-world applications, and with error handling built-in, it helps ensure robust database operations.

With its simple syntax and powerful features, `CQL::Insert` streamlines your database interactions, allowing you to focus on building great features in your Crystal applications.
