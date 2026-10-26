# Optimizing Queries in CQL

> [!TIP]
> Query optimization in CQL centers on three core principles: minimizing network round trips via eager loading, reducing memory footprint through column projections, and inspecting execution plans early.

---

## Quick Reference: Performance Anti-Patterns vs. CQL Best Practices

| Strategy | Anti-Pattern (Slow / High Memory) | CQL Best Practice (Optimized) |
| :--- | :--- | :--- |
| **N+1 Avoidance** | Reading an association inside a loop | `Post.preload(:user).all` |
| **Field Projection** | Loading full models to read two columns | `User.select(:id, :email).all` |
| **Batch Processing** | `User.all.each { ... }` (loads every row) | `User.find_in_batches(batch_size: 1000) { ... }` |
| **Aggregates** | `.all.size`, `.count > 0` | `.count`, `.exists?` |
| **Bulk Writes** | `create!` / `save` in a loop | `User.insert_all(rows)` / `User.upsert_all(rows, on_conflict: :email)` |

---

## 1. Preventing N+1 Query Problems

An N+1 problem is one query for the parent records plus one query per parent for an association.

### Eager Loading (`preload`)

`preload` loads an association for every fetched record with one extra query.

```crystal
# Bad: 1 query for posts + 1 query per post
posts = Post.all
posts.each { |post| puts post.user.try(&.name) }

# Good: 2 queries total
posts = Post.preload(:user).all
posts.each { |post| puts post.user.try(&.name) }

# Several associations, one extra query each
users = User.preload(:posts, :profile).all
```

The second query is `SELECT ... FROM users WHERE users.id IN (?, ?, ...)`.

| `preload` | Behavior |
| :--- | :--- |
| Supported | `has_many`, `belongs_to`, `has_one` (`belongs_to` and `has_one` with the default `cache: true`) |
| Silently ignored | `many_to_many`, and names that match no association |
| Applied by | `all` and `to_a`; not by `first`, `each` or `all(as:)` |
| Raises | `ArgumentError` when chained after a partial `select` |
| Chunking | Ids are split under the dialect's bind limit (`Dialect#max_bind_params`, 999 on SQLite) |

### Filtering Through an Association (`joins`)

`joins` filters by the associated table in one query; the block takes typed conditions on the association.

```crystal
# Posts written by Ada: one query with INNER JOIN users
posts = Post.query.joins(:user) { user.name == "Ada" }.all

# Keep posts that have no user
posts = Post.query.left_joins(:user).all
```

| | `preload` | `joins` / `left_joins` |
| :--- | :--- | :--- |
| Queries | 1 + 1 per association | 1 |
| Populates `post.user` | Yes | No |
| Use it to | Read associated records | Filter or sort by associated columns |

> [!NOTE]
> A join only filters. Reading `post.user` after a join still queries per post unless you also `preload(:user)`. See [Avoid N+1 Queries](n-plus-one.md) for `many_to_many`, manual batch loading and detection.

---

## 2. Column Projection

Select only the columns you read.

```crystal
rows = User.select(:id, :email).all   # Array(User::Row)
rows.first.email                      # => String? ("ada@example.com")
rows.first.name                       # => nil (not selected)

emails = User.where(active: true).pluck(:email, as: String)  # Array(String)
pairs  = User.pluck(:id, :name, as: {Int64, String})         # Array({Int64, String})
newest = User.order(id: :desc).pick(:id, as: Int64)          # first row's value
```

| Method | Returns | Use it when |
| :--- | :--- | :--- |
| `select(*columns)` | `Model::Row` structs with nilable getters; unselected columns are `nil` | You need several fields per row and keep chaining (`where`, `order`, `limit`) |
| `pluck(*columns, as:)` | `Array(T)`, or an array of tuples for several columns | You need plain values, no model objects |
| `pick(column, as:)` | The first row's value, or `nil` | You need one value |

---

## 3. Batch Processing

Walk large tables in fixed-size batches instead of loading every row.

```crystal
# Bad: loads every matching row into memory at once
User.where(active: true).all.each { |user| user.update!(processed: true) }

# Good: 1,000 rows per query, one record at a time
User.where(active: true).find_each(batch_size: 1000) do |user|
  user.update!(processed: true)
end

# Good: 1,000 rows per query, one array at a time
User.where(active: true).find_in_batches(batch_size: 1000) do |batch|
  batch.each { |user| user.update!(processed: true) }
end
```

| Query shape | Paging | Cost per batch | Safe to change filtered columns or delete visited rows |
| :--- | :--- | :--- | :--- |
| No `order`, `select`, `distinct`, `group` or `having` | Keyset: `WHERE id > ? ORDER BY id LIMIT ?` | Constant (index seek) | Yes |
| Any of those | `LIMIT ? OFFSET ?` in your order, primary key appended as a tiebreaker | Grows with depth (rescans earlier rows) | No; later batches skip rows |

> [!NOTE]
> Batching ignores the query's own `limit` and `offset` and walks every matching row. `batch_size` must be positive, or `ArgumentError` is raised.

For pages shown to users, use `User.order(id: :asc).limit(20).offset(40).all`, or a cursor (`User.where { id > last_id }.order(id: :asc).limit(20).all`) on large tables. See [Use Cursor Pagination](../querying/cursor-pagination.md).

---

## 4. Pushing Aggregates to the Database

Let the database count, sum and deduplicate.

| Need | Avoid | Use | SQL sent |
| :--- | :--- | :--- | :--- |
| How many rows | `User.where(active: true).all.size` | `User.where(active: true).count` | `SELECT COUNT(*) ...` |
| Any match | `User.where(email: email).count > 0` | `User.where(email: email).exists?` | `SELECT users.id ... LIMIT ?` |
| Totals | `User.all.sum(&.age)` | `User.sum(:age)`, `average`, `maximum`, `minimum` | `SELECT SUM(users.age) ...` |
| One column | `User.all.map(&.email)` | `User.pluck(:email, as: String)` | `SELECT users.email ...` |
| Distinct values | `User.all.map(&.age).uniq` | `User.distinct(:age, as: Int32)` | `SELECT DISTINCT users.age ...` |

Count per parent in one grouped query instead of calling `post.comments.count` in a loop:

```crystal
counts = MyDB.query
  .from(:comments)
  .select(:post_id, count: :id)
  .group(:post_id)
  .all(as: {Int64, Int64})
  .to_h

posts.each { |post| puts counts[post.id!]? || 0 }
```

> [!TIP]
> `count` drops `ORDER BY`, and counts through a subquery when the query has a `limit` or `offset`. `Model.size` also runs `COUNT`; only `.all.size` loads the rows.

---

## 5. Bulk Writes

Send many rows per statement instead of one statement per record.

```crystal
# One multi-row INSERT per chunk
User.insert_all([{name: "Ada", email: "ada@example.com"}, {name: "Grace", email: "grace@example.com"}])

# Insert, or update on a unique-key conflict
User.upsert_all([{email: "ada@example.com", name: "Ada L."}], on_conflict: :email)

# has_many: sets user_id on every row
user.insert_posts_all([{title: "One"}, {title: "Two"}])

# One SELECT for ids, then DELETE ... WHERE id IN (...) per chunk
User.where(active: false).delete_all
```

| Method | Statements | Validations / callbacks | Notes |
| :--- | :--- | :--- | :--- |
| `insert_all(rows, batch_size: nil)` | One `INSERT` per chunk | Skipped | Rows per statement: `max_bind_params / columns`, or `batch_size:`. Several statements run in one transaction. Missing `created_at` / `updated_at` are filled in. |
| `upsert_all(rows, on_conflict:, update: nil, batch_size: nil)` | One `INSERT ... ON CONFLICT` per chunk | Skipped | `on_conflict:` names the unique column(s). `update:` picks the columns overwritten; by default every inserted column except the conflict columns, the primary key and `created_at`. |
| `insert_<name>_all(rows)` | One `INSERT` per chunk | Skipped | `has_many` only; overrides the foreign key on every row. |
| `delete_all` (on a query) | One `SELECT` + one `DELETE ... IN` per chunk | Skipped | Falls back to loading and deleting each record in a transaction when the model has destroy callbacks, a `dependent:` association or a `many_to_many`. |

Send only changed columns on update with dirty tracking:

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::DirtyTracking
  # ...
end

user.name = "Ada Lovelace"
user.save!   # UPDATE users SET name = ?, updated_at = ? WHERE users.id = ?
user.save!   # nothing changed: no UPDATE
```

See [Create Records](../data-operations/create.md) and [Track Changes and Update Only Changed Columns](../models/dirty-tracking.md).

---

## 6. Indexing Filtered and Ordered Columns

Index the columns your `where`, `order`, `preload` and `joins` use.

```crystal
# New table: declared in the table block, created by schema.users.create!
schema.table :users do
  primary :id, Int64
  column :email, String
  column :status, String, index: true
  index [:email], unique: true
end

# Existing table: inside schema.alter
schema.alter :posts do
  create_index :idx_posts_user_published, [:user_id, :published_at]
end
```

| Query | Index |
| :--- | :--- |
| `Post.where(user_id: id)` | `[:user_id]`, or a composite index that starts with `user_id` |
| `Post.where(user_id: id).order(published_at: :desc)` | `[:user_id, :published_at]` (equality column first) |
| `User.preload(:posts)`, `Post.query.joins(:user)` | The foreign key, `posts.user_id` |
| `User.where(email: email).exists?`, `upsert_all(..., on_conflict: :email)` | Unique `[:email]` |

See [Create Indexes](../migrations/indexes.md) for naming rules and migrations.

---

## 7. Aggregating in One Round Trip with CTEs

Compute intermediate results in the database with `WITH` instead of loading rows and combining them in Crystal.

```crystal
spend = AppDB.query.from(:orders)
  .select(:customer_id)
  .sum(:total, as: :spent)
  .group(:customer_id)

big_spenders = AppDB.query
  .with(:totals, spend)
  .from(:totals).select(:customer_id)
  .where { totals.spent > 100 }
  .all(as: Int64)
```

```sql
WITH totals AS (SELECT orders.customer_id, SUM(orders.total) AS spent FROM orders GROUP BY orders.customer_id)
SELECT totals.customer_id FROM totals WHERE totals.spent > ?
```

| Method | Declares |
| :--- | :--- |
| `with(name, query)` | `WITH name AS (query)` |
| `with(name) { ... }` | A CTE built from a query that can read the CTEs declared before it |
| `with_recursive(name, anchor) { ... }` | `WITH RECURSIVE` (`UNION ALL`; pass `all: false` for `UNION`) |

> [!NOTE]
> CTEs live on `CQL::Query` (`AppDB.query`), not on model classes or `QueryBuilder`. See [Use CTEs and Recursive CTEs](../querying/ctes.md).

---

## 8. Inspecting Queries

Check the SQL and the plan before a query reaches production.

```crystal
query = User.where(email: "ada@example.com")

query.to_sql                                    # => "SELECT users.id, ... FROM users WHERE users.email = ?"
query.to_sql_with_params                        # => {"SELECT ...", ["ada@example.com"]}
query.query.to_sql(for: CQL::Adapter::Postgres) # => {"... WHERE users.email = $1", ["ada@example.com"]}

puts query.query.explain                        # SQLite: SEARCH users USING INDEX idx_users_email (email=?)
puts query.query.explain(analyze: true)         # PostgreSQL / MySQL: runs the statement, reports real timings
```

| Tool | Shows |
| :--- | :--- |
| `QueryBuilder#to_sql` / `#to_sql_with_params` | The SQL, and the SQL with its bound values |
| `CQL::Query#to_sql(for: adapter)` | The SQL for another dialect, without a connection |
| `CQL::Query#explain(analyze: false)` | The database's plan, one line per row |
| `CQL::Telemetry.alert_on_slow(100.milliseconds) { ... }` | Statements slower than the threshold (`event.sql`, `event.duration`) |
| `CQL::Telemetry.log_queries` | Every statement, as debug log lines |
| `CQL::Performance.enable_development_mode!` then `critical_issues` | Profiler and N+1 detector findings |

Reading the plan:

| Dialect | Full scan | Index used |
| :--- | :--- | :--- |
| SQLite | `SCAN users` | `SEARCH users USING INDEX idx_users_email (email=?)` |
| PostgreSQL | `Seq Scan on users` | `Index Scan using idx_users_email on users` |
| MySQL | `type` is `ALL` | `key` names the index |

```crystal
CQL::Telemetry.alert_on_slow(100.milliseconds) do |event|
  Log.warn { "Slow query (#{event.duration.total_milliseconds.round(2)}ms): #{event.sql}" }
end
```

> [!NOTE]
> `explain(analyze: true)` executes the statement, and raises `CQL::DialectError` on SQLite. Keep SQL logging and the performance monitor off in production unless you are investigating: each adds several microseconds per query. See [How CQL Keeps Queries Fast](../../explanation/performance-design.md).

---

## See Also

- [Avoid N+1 Queries](n-plus-one.md)
- [Profile Queries and Detect N+1](query-profiler.md)
- [Telemetry](telemetry.md)
- [Monitor Performance](monitoring.md)
- [Benchmark CQL](benchmark.md)
- [Inspect Queries with to_sql and explain](../querying/explain-and-to-sql.md)
- [Use CTEs and Recursive CTEs](../querying/ctes.md)
- [Create Indexes](../migrations/indexes.md)
- [How CQL Keeps Queries Fast](../../explanation/performance-design.md)
