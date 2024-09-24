# Reading Records

The `CQL::Query` class is designed to simplify the creation and execution of SQL queries. By using a structured, chainable API, you can build complex SQL queries while maintaining clean and readable code.

This guide walks you through how to create, modify, and execute queries using real-world examples. We'll also explore various methods for selecting, filtering, joining, and ordering data, with a focus on practical use cases.

---

#### Key Features

1. **Select columns and filter records** using simple, chainable methods.
2. **Join tables** for complex queries involving multiple relationships.
3. **Aggregate data** using functions like `COUNT`, `SUM`, and `AVG`.
4. **Order and limit** your result sets for more precise control.
5. **Fetch results** as objects or raw data for immediate use in your application.

---

#### Real-World Example: Fetching User Data

Let's begin by selecting user data from a `users` table:

```crystal
query = CQL::Query.new(schema)
query.select(:name, :age).from(:users).where(name: "Alice").all(User)
```

This query will return all users with the name "Alice", casting the result to the `User` type.

---

### Core Methods

Below is a breakdown of the key methods in the `CQL::Query` class and how you can use them in your applications.

#### 1. `select(*columns : Symbol)`

**Purpose**: Specifies the columns to select in the query.

- **Parameters**: `columns` — One or more symbols representing the columns you want to select.
- **Returns**: `Query` object for chaining.

**Real-World Example: Selecting Columns**

```crystal
query = CQL::Query.new(schema)
query.select(:name, :email).from(:users)
```

This query selects the `name` and `email` columns from the `users` table.

---

#### 2. `from(*tables : Symbol)`

**Purpose**: Specifies the tables to query from.

- **Parameters**: `tables` — One or more symbols representing the tables to query from.
- **Returns**: `Query` object for chaining.

**Real-World Example: Querying a Table**

```crystal
query.from(:users)
```

This query selects from the `users` table.

---

#### 3. `where(hash : Hash(Symbol, DB::Any))`

**Purpose**: Adds filtering conditions to the query.

- **Parameters**: `hash` — A key-value hash representing the column and its corresponding value for the `WHERE` clause.
- **Returns**: `Query` object for chaining.

**Real-World Example: Filtering Data**

```crystal
query.from(:users).where(name: "Alice", age: 30)
```

This will generate a query with the `WHERE` clause: `WHERE name = 'Alice' AND age = 30`.

---

#### 4. `all(as : Type)`

**Purpose**: Executes the query and returns all matching results, casting them to the specified type.

- **Parameters**: `as` — The type to cast the results to.
- **Returns**: An array of the specified type.

**Real-World Example: Fetching All Results**

```crystal
users = query.select(:name, :email).from(:users).all(User)
```

This will return all users as an array of `User` objects.

---

#### 5. `first(as : Type)`

**Purpose**: Executes the query and returns the first matching result, casting it to the specified type.

- **Parameters**: `as` — The type to cast the result to.
- **Returns**: The first matching result of the query.

**Real-World Example: Fetching the First Result**

```crystal
user = query.select(:name, :email).from(:users).where(name: "Alice").first(User)
```

This returns the first user with the name "Alice".

---

#### 6. `count(column : Symbol = :*)`

**Purpose**: Adds a `COUNT` aggregate function to the query, counting the specified column.

- **Parameters**: `column` — The column to count (default is `*`, meaning all rows).
- **Returns**: `Query` object for chaining.

**Real-World Example: Counting Rows**

```crystal
count = query.from(:users).count(:id).get(Int64)
```

This will count the number of rows in the `users` table and return the result as an `Int64`.

---

#### 7. `join(table : Symbol, on : Hash)`

**Purpose**: Adds a `JOIN` clause to the query, specifying the table and the condition for joining.

- **Parameters**:
  - `table`: The table to join.
  - `on`: A hash representing the join condition, mapping columns from one table to another.
- **Returns**: `Query` object for chaining.

**Real-World Example: Joining Tables**

```crystal
query
  .from(:users)
  .join(:orders, on: {users.id => orders.user_id})
```

This query joins the `users` table with the `orders` table on the condition that `users.id` equals `orders.user_id`.

---

#### 8. `order(*columns : Symbol)`

**Purpose**: Specifies the columns by which to order the results.

- **Parameters**: `columns` — The columns to order by.
- **Returns**: `Query` object for chaining.

**Real-World Example: Ordering Results**

```crystal
query.from(:users).order(:name, :age)
```

This orders the query results by `name` first and then by `age`.

---

#### 9. `limit(value : Int32)`

**Purpose**: Limits the number of rows returned by the query.

- **Parameters**: `value` — The number of rows to return.
- **Returns**: `Query` object for chaining.

**Real-World Example: Limiting Results**

```crystal
query.from(:users).limit(10)
```

This limits the query to return only the first 10 rows.

---

#### 10. `get(as : Type)`

**Purpose**: Executes the query and returns a scalar value, such as the result of an aggregate function (e.g., `COUNT`, `SUM`).

- **Parameters**: `as` — The type to cast the result to.
- **Returns**: The scalar result of the query.

**Real-World Example: Getting a Scalar Value**

```crystal
total_users = query.from(:users).count(:id).get(Int64)
```

This returns the total number of users as an `Int64`.

---

#### 11. `each(as : Type, &block)`

**Purpose**: Iterates over each result, yielding each row to the provided block.

- **Parameters**:
  - `as`: The type to cast each row to.
  - `&block`: The block to execute for each row.
- **Returns**: Nothing (used for iteration).

**Real-World Example: Iterating Over Results**

```crystal
query.from(:users).each(User) do |user|
  puts user.name
end
```

This will print the name of each user in the `users` table.

---

#### 12. `distinct`

**Purpose**: Sets the `DISTINCT` flag to return only unique rows.

- **Returns**: `Query` object for chaining.

**Real-World Example: Fetching Distinct Results**

```crystal
query.from(:users).distinct
```

This will generate a query that returns only distinct rows from the `users` table.

---

### Putting It All Together

Let's create a real-world example that combines several methods. Suppose you want to fetch the first 5 users who have placed an order, ordered by their name, and return the result as `User` objects:

```crystal
query = CQL::Query.new(schema)

users = query
  .select(:name, :email)
  .from(:users)
  .join(:orders, on: {users.id => orders.user_id})
  .where(active: true)
  .order(:name)
  .limit(5)
  .all(User)

users.each do |user|
  puts "Name: #{user.name}, Email: #{user.email}"
end
```

In this query:

- We select the `name` and `email` columns from `users`.
- We join the `orders` table to ensure the user has placed an order.
- We filter for active users (`where(active: true)`).
- We order the results by `name`.
- We limit the results to 5 users.

---

### Conclusion

The `CQL::Query` class offers a flexible and intuitive API for building and executing SQL queries in your Crystal applications. With methods for selecting, joining, filtering, and aggregating data, you can handle even the most complex queries with ease.

Whether you're building basic queries or handling complex database operations, the `CQL::Query` class provides the tools you need to write clean, efficient, and maintainable code.
