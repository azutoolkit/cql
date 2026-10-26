---
description: "Cut round trips, allocations and in-memory work: preload associations, select only the columns you need, and let the database count."
---

# Optimizing Queries in CQL

{% hint style="success" %}
Optimize CQL database operations by minimizing network round trips (**`preload`**), reducing heap allocations (**`select`**), and offloading collection work to the database engine (**`exists?`**, **`count`**).
{% endhint %}

---

## Performance Quick Reference

| Strategy | Anti-Pattern (High Latency / OOM Risk) | CQL Optimized Pattern |
| :--- | :--- | :--- |
| **Association Loading** | Reading an association inside a loop | **`Post.preload(:user).all`** |
| **Column Projection** | Loading full models to read two columns | **`User.select(:id, :email).all`** |
| **Large Datasets** | `User.all.each` | **`User.find_in_batches(batch_size: 1000)`** |
| **Existence Checks** | `User.where(...).to_a.any?` | **`User.where(...).exists?`** |
| **Aggregates** | `User.where(...).to_a.size` | **`User.where(...).count`** |
| **Bulk Ingestion** | `create!` or `save!` in a loop | **`User.insert_all(rows)`** |

---

## 1. Preventing N+1 Queries

Reading an association inside a loop sends one query per record. **`preload`** loads it for every record with one extra query.

```crystal
# ❌ N+1: 1 query for posts + 1 query per post
posts = Post.all
posts.each { |post| puts post.user.try(&.name) }

# ✅ 2 queries: posts, then SELECT ... FROM users WHERE users.id IN (?, ?, ...)
posts = Post.preload(:user).all
posts.each { |post| puts post.user.try(&.name) }

# ✅ One extra query per association (has_many, belongs_to, has_one)
users = User.preload(:posts, :profile).all

# ✅ Filter by an association in one query
# SELECT DISTINCT users.id, ... FROM users INNER JOIN posts ON (posts.user_id = users.id) AND (posts.published = ?)
authors = User.query.joins(:posts) { posts.published == true }.distinct.all
```

{% hint style="info" %}
**`preload`** runs only through `all` / `to_a`, ignores `many_to_many`, and raises `ArgumentError` after a partial `select`. A join filters rows but does not populate the association.
{% endhint %}

---

## 2. Column Projection

```crystal
rows = User.select(:id, :email).all                          # Array(User::Row)
rows.first.email                                             # => "ada@example.com"
rows.first.name                                              # => nil (not selected)

emails = User.where(active: true).pluck(:email, as: String)  # Array(String)
pairs = User.pluck(:id, :name, as: {Int64, String})          # Array({Int64, String})
newest = User.order(id: :desc).pick(:id, as: Int64)          # Int64?
```

---

## 3. Large Datasets

```crystal
# ❌ Loads every matching row at once
User.where(active: true).all.each { |user| user.update!(processed: true) }

# ✅ 1,000 rows per query, one record at a time
User.where(active: true).find_each(batch_size: 1000) do |user|
  user.update!(processed: true)
end

# ✅ 1,000 rows per query, one Array(User) at a time
User.where(active: true).find_in_batches(batch_size: 1000) do |batch|
  batch.each { |user| user.update!(processed: true) }
end

# Paging used by find_each / find_in_batches:
#   no order/select/distinct/group/having -> WHERE ... AND users.id > ? ORDER BY users.id LIMIT ?
#                                            constant cost per batch; safe to update filtered columns
#   otherwise                             -> ORDER BY <yours>, users.id LIMIT ? OFFSET ?
#                                            cost grows per batch; do not update filtered columns
# The query's own limit/offset are ignored; batch_size <= 0 raises ArgumentError.

# ✅ Pages for users on large tables: a cursor instead of a deep OFFSET
User.where { id > last_id }.order(id: :asc).limit(20).all
```

---

## 4. Existence Checks and Aggregates

```crystal
# ❌ Loads rows to answer a number
User.where(active: true).to_a.size
User.where(email: "ada@example.com").to_a.any?

# ✅ SELECT COUNT(*) FROM users WHERE users.active = ?
User.where(active: true).count

# ✅ SELECT users.id FROM users WHERE users.email = ? LIMIT ?
User.where(email: "ada@example.com").exists?

# ✅ SELECT SUM(users.age) / AVG(users.age) / DISTINCT users.age FROM users
User.sum(:age)
User.average(:age)
User.distinct(:age, as: Int32)

# ✅ Comment counts for every post in one grouped query
counts = AppDB.query
  .from(:comments)
  .select(:post_id, count: :id)
  .group(:post_id)
  .all(as: {Int64, Int64})
  .to_h
```

---

## 5. Bulk Ingestion

```crystal
# ❌ One INSERT per row
rows.each { |row| User.create!(**row) }

# ✅ INSERT INTO users (name, email, created_at, updated_at) VALUES (?, ?, ?, ?), (?, ?, ?, ?)
User.insert_all([{name: "Ada", email: "ada@example.com"}, {name: "Grace", email: "grace@example.com"}])

# ✅ INSERT ... ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name, updated_at = EXCLUDED.updated_at
User.upsert_all([{email: "ada@example.com", name: "Ada L."}], on_conflict: :email)

# ✅ has_many: INSERT INTO posts (title, user_id) VALUES (?, ?), (?, ?)
user.insert_posts_all([{title: "One"}, {title: "Two"}])

# ✅ SELECT users.id ..., then DELETE FROM users WHERE users.id IN (...) per chunk
User.where(active: false).delete_all

# ✅ Dirty tracking: UPDATE sends only changed columns, and nothing when unchanged
class User
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::DirtyTracking
end
```

{% hint style="info" %}
Bulk writes skip validations and callbacks. Rows per statement default to `max_bind_params / columns`; pass `batch_size:` to change it. `delete_all` deletes record by record when the model has destroy callbacks, `dependent:` or `many_to_many`.
{% endhint %}

---

## 6. Indexes

```crystal
schema.table :users do
  primary :id, Int64
  column :email, String
  column :status, String, index: true  # where(status: ...)
  index [:email], unique: true         # exists?(email: ...), upsert_all(on_conflict: :email)
end

schema.alter :posts do
  # where(user_id: ...).order(published_at: :desc), and preload/joins through user_id
  create_index :idx_posts_user_published, [:user_id, :published_at]
end
```

---

## 7. CTEs

CTEs live on **`CQL::Query`** (`AppDB.query`), not on model classes.

```crystal
spend = AppDB.query.from(:orders)
  .select(:customer_id)
  .sum(:total, as: :spent)
  .group(:customer_id)

# WITH totals AS (SELECT orders.customer_id, SUM(orders.total) AS spent FROM orders GROUP BY orders.customer_id)
# SELECT totals.customer_id FROM totals WHERE totals.spent > ?
big_spenders = AppDB.query
  .with(:totals, spend)
  .from(:totals).select(:customer_id)
  .where { totals.spent > 100 }
  .all(as: Int64)

# Hierarchies: .with_recursive(:tree, anchor) { |step| ... }
```

---

## 8. Inspecting Queries

```crystal
query = User.where(email: "ada@example.com")

query.to_sql                                    # "SELECT users.id, ... FROM users WHERE users.email = ?"
query.to_sql_with_params                        # {"SELECT ...", ["ada@example.com"]}
query.query.to_sql(for: CQL::Adapter::Postgres) # {"... WHERE users.email = $1", ["ada@example.com"]}

puts query.query.explain
# Index used                                          Full scan
# SQLite:     SEARCH users USING INDEX idx_users_email  SCAN users
# PostgreSQL: Index Scan using idx_users_email          Seq Scan on users
# MySQL:      key column: idx_users_email               type column: ALL

puts query.query.explain(analyze: true)         # runs the statement; raises CQL::DialectError on SQLite

CQL::Telemetry.alert_on_slow(100.milliseconds) do |event|
  Log.warn { "Slow query (#{event.duration.total_milliseconds.round(2)}ms): #{event.sql}" }
end

CQL::Performance.enable_development_mode!       # profiler + N+1 detector
CQL::Performance.monitor.detector.not_nil!.issues # :n_plus_one issues, :medium at most with the default window
```

{% hint style="info" %}
Keep SQL logging and the performance monitor off in production; the production monitor alone adds about 340 ns per query (see [What monitoring costs](../observability/query-profiler.md#what-monitoring-costs)).
{% endhint %}

---

## See Also

- [Avoid N+1 Queries](n-plus-one.md)
- [Profile Queries and Detect N+1](../observability/query-profiler.md)
- [Inspect Queries with to_sql and explain](../querying/explain-and-to-sql.md)
- [Use CTEs and Recursive CTEs](../advanced-sql/ctes.md)
- [Create Indexes](../migrations/indexes.md)
- [How CQL Keeps Queries Fast](../../explanation/performance-design.md)
