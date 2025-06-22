# Reading Records

CQL provides a comprehensive set of methods for reading data from your database. This guide covers the various ways to retrieve records using CQL's query interface.

---

## Basic Query Construction

CQL uses a fluent query builder pattern that allows you to construct complex SQL queries using idiomatic Crystal code.

Let's begin by selecting user data from a `users` table:

```crystal
query = CQL::Query.new(schema)
query.select(:name, :age).from(:users).where(name: "Alice").all(User)
```

This query will return all users with the name "Alice", casting the result to the `User` type.

---

## Query Merging

CQL provides powerful query merging capabilities that allow you to combine multiple queries into a single query. This is useful for building complex queries dynamically or combining query conditions from different sources.

### Basic Query Merging

You can merge two queries using the `merge` method:

```crystal
# Create two separate queries
query1 = CQL::Query.new(schema)
query1.select(:name, :email).from(:users).where(city: "New York")

query2 = CQL::Query.new(schema)
query2.select(:age).from(:users).where(active: true)

# Merge the queries
query1.merge(query2)

# The merged query combines both conditions and selects all specified columns
users = query1.all(User)
# Equivalent to: SELECT name, email, age FROM users WHERE city = 'New York' AND active = true
```

### Merging Different Query Components

Query merging intelligently combines various query components:

#### Column Selection

```crystal
query1 = CQL::Query.new(schema).select(:name).from(:users)
query2 = CQL::Query.new(schema).select(:email).from(:users)

query1.merge(query2)
# Result: SELECT name, email FROM users
```

#### WHERE Conditions

```crystal
query1 = CQL::Query.new(schema).from(:users).where(age: 18..65)
query2 = CQL::Query.new(schema).from(:users).where(active: true)

query1.merge(query2)
# Result: WHERE age BETWEEN 18 AND 65 AND active = true
```

#### ORDER BY Clauses

```crystal
query1 = CQL::Query.new(schema).from(:users).order(name: :asc)
query2 = CQL::Query.new(schema).from(:users).order(email: :desc)

query1.merge(query2)
# Result: ORDER BY name ASC, email DESC
```

#### LIMIT and OFFSET

```crystal
query1 = CQL::Query.new(schema).from(:users).limit(10)
query2 = CQL::Query.new(schema).from(:users).limit(5)

query1.merge(query2)
# Result: Takes the smaller limit (5)

query1 = CQL::Query.new(schema).from(:users).offset(10)
query2 = CQL::Query.new(schema).from(:users).offset(20)

query1.merge(query2)
# Result: Uses the merged query's offset (20)
```

#### DISTINCT

```crystal
query1 = CQL::Query.new(schema).from(:users).select(:city)
query2 = CQL::Query.new(schema).from(:users).select(:name).distinct

query1.merge(query2)
# Result: SELECT DISTINCT city, name FROM users
```

#### GROUP BY and HAVING

```crystal
query1 = CQL::Query.new(schema).from(:orders).group(:customer_id)
query2 = CQL::Query.new(schema).from(:orders).group(:status).having { sum(:total) > 1000 }

query1.merge(query2)
# Result: GROUP BY customer_id, status HAVING sum(total) > 1000
```

#### JOINs

```crystal
query1 = CQL::Query.new(schema).from(:users).join(:address) { |j| j.users.id == j.address.user_id }
query2 = CQL::Query.new(schema).from(:customers).join(:orders) { |j| j.customers.id == j.orders.customer_id }

query1.merge(query2)
# Result: FROM users, customers INNER JOIN address ON users.id = address.user_id
#        INNER JOIN orders ON customers.id = orders.customer_id
```

### Advanced Merging Examples

#### Dynamic Query Building

```crystal
def build_user_query(filters : Hash(Symbol, Any))
  base_query = CQL::Query.new(schema).from(:users)

  filters.each do |key, value|
    filter_query = CQL::Query.new(schema).from(:users).where({key => value})
    base_query.merge(filter_query)
  end

  base_query
end

# Usage
filters = {:active => true, :city => "New York", :age => 18..65}
query = build_user_query(filters)
users = query.all(User)
```

#### Combining Scopes

```crystal
def active_users
  CQL::Query.new(schema).from(:users).where(active: true)
end

def recent_users
  CQL::Query.new(schema).from(:users).where { created_at > 1.week.ago }
end

def admin_users
  CQL::Query.new(schema).from(:users).where(role: "admin")
end

# Combine multiple scopes
query = active_users
query.merge(recent_users)
query.merge(admin_users)

admins = query.all(User)
```

### Error Handling

Query merging includes several safety checks:

#### Schema Validation

```crystal
# Queries must use the same schema
query1 = Schema1.query.from(:users)
query2 = Schema2.query.from(:users)

expect_raises(ArgumentError, "Cannot merge queries: Schemas are different.") do
  query1.merge(query2)
end
```

#### Table Alias Conflicts

```crystal
query1 = CQL::Query.new(schema).from(users: :u)
query2 = CQL::Query.new(schema).from(employees: :u)

expect_raises(ArgumentError, /Merge conflict: Alias 'u'/) do
  query1.merge(query2)
end
```

### Best Practices

1. **Use for Dynamic Queries**: Query merging is ideal for building queries based on user input or dynamic conditions.

2. **Combine Scopes**: Use merging to combine predefined query scopes for reusable query logic.

3. **Performance**: Merged queries are executed as a single SQL statement, which is more efficient than multiple separate queries.

4. **Readability**: Use meaningful variable names for queries to make merging logic clear and maintainable.

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
