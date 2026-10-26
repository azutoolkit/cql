# What is an ORM?

An object-relational mapper (ORM) maps tables to classes and rows to objects, so application code reads and writes typed objects instead of SQL strings and result-set columns. CQL is an ORM for Crystal.

## Without an ORM, Every Query Is SQL Text Plus a Tuple

```crystal
# crystal-db alone: you write the SQL and name each column's type
name, email = AppDB.exec_query do |conn|
  conn.query_one("SELECT name, email FROM users WHERE id = ?", 1, as: {String, String})
end

# CQL: a typed object
user = User.find!(1) # User; User.find(1) returns User? (nil when the row is missing)
user.email
```

The raw version works, but the SQL, the column order and the types are repeated at every call site. Rename a column and the compiler cannot point you to them.

## A Model Maps One Table

```crystal
class User
  include CQL::ActiveRecord::Model(Int64) # adds id : Int64?, nil until saved
  db_context AppDB, :users                # the schema and table

  property name : String                  # column users.name
  property email : String                 # column users.email

  def initialize(@name : String, @email : String)
  end
end
```

The class stands for the table and each instance for one row. CQL decodes rows into `User` with `DB::Serializable` and writes the properties back when you save.

## Method Calls Become SQL With Bound Values

| Call | SQL CQL sends (SQLite) |
| :--- | :--- |
| `User.find(1)` | `SELECT users.id, users.name, users.email FROM users WHERE users.id = ? LIMIT ?` |
| `User.where(name: "Ada").all` | `SELECT users.id, users.name, users.email FROM users WHERE users.name = ?` |
| `User.count` | `SELECT COUNT(*) FROM users` |
| `user.save` on a new record | `INSERT INTO users (name, email) VALUES (?, ?)` |
| `user.save` on a saved record | `UPDATE users SET name = ?, email = ? WHERE users.id = ?` |
| `post.user` (a `belongs_to`) | `SELECT users.id, users.name, users.email FROM users WHERE users.id = ? LIMIT ?` |

Associations replace hand-written joins: a `posts.user_id` column becomes `belongs_to :user, User, :user_id` on `Post`, and `post.user` returns `User?`. See [Set Up Belongs To](../how-to/relationships/belongs-to.md).

## What the Mapping Buys You

| Benefit | How CQL provides it |
| :--- | :--- |
| Type safety | Assigning an `Int32` to `user.name` is a compile error, and so is `User.query.where { name == 1 }`. See [Safety Guardrails](safety-guardrails.md). |
| Injection safety | Every value is sent as a bound parameter, never spliced into the SQL text. |
| Portability | The same query renders `?` placeholders for SQLite and MySQL and `$1` for PostgreSQL and CockroachDB. |
| One place to change | A new column is one property on the model plus one migration. |

```crystal
query = User.where(email: "ada@example.com").query
query.to_sql                              # => {"SELECT ... WHERE users.email = ?", ["ada@example.com"]}
query.to_sql(for: CQL::Adapter::Postgres) # => {"SELECT ... WHERE users.email = $1", ["ada@example.com"]}
```

## Where an ORM Gets in the Way, CQL Has Exits

Mapping every row to an object is not always the right tool:

| Situation | Exit |
| :--- | :--- |
| Reports and analytics | A raw fragment (`User.where("lower(email) = ?", email)`) or a whole statement on the pooled connection, shown below |
| Bulk writes | `User.insert_all(rows)` sends multi-row `INSERT`s and skips per-record validations and callbacks |
| Reading a few columns | `User.pluck(:email, as: String)` or `User.select(:id, :email)` instead of full models |
| Database-specific features | Generated SQL for each dialect, plus `Schema#exec` for DDL you write yourself |

```crystal
rows = AppDB.exec_query do |conn|
  conn.query_all(<<-SQL, 10, as: {String, Int64})
    SELECT u.name, COUNT(p.id) AS post_count
    FROM users u
    LEFT JOIN posts p ON p.user_id = u.id
    GROUP BY u.id, u.name
    HAVING COUNT(p.id) > ?
    SQL
end
```

`exec_query` yields the schema's pooled `DB::Connection`, or the fiber's transaction connection, so raw statements and model calls can share a transaction. Bind values with `?` there too, never with string interpolation. See [Use Raw SQL Fragments Safely](../how-to/advanced-sql/raw-fragments.md) and [Optimize Queries](../how-to/performance/optimize-queries.md).

## Two Patterns: Active Record and Repository

CQL's models follow the [Active Record pattern](active-record-pattern.md): an object carries its data and saves itself (`user.save`). For domain code that must not know about the database, CQL also supports the [Repository pattern](repository-pattern.md), through the generic `CQL::Repository(T, Pk)` or a repository you write around a model.
