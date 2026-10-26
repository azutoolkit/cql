# Optimize Queries

Improve query performance with indexing, eager loading, and query optimization techniques.

## Prerequisites

- Working CQL application
- Understanding of your data access patterns

## Add Database Indexes

Indexes dramatically speed up queries on frequently searched columns.

Declare indexes in the table block with `index [...]` or `index: true`, and `table.create!` creates them after the table. For an existing table, use `create_index` inside `schema.alter`, as below (see [Create Indexes](../migrations/indexes.md)).

### Single Column Index

```crystal
class AddIndexes < CQL::Migration(1)
  def up
    schema.alter :users do
      create_index :idx_users_email, [:email]
    end
    schema.alter :posts do
      create_index :idx_posts_user_id, [:user_id]
      create_index :idx_posts_published_at, [:published_at]
    end
  end

  def down
    schema.alter :users do
      drop_index :idx_users_email
    end
    schema.alter :posts do
      drop_index :idx_posts_user_id
      drop_index :idx_posts_published_at
    end
  end
end
```

### Composite Index

For queries filtering on multiple columns:

```crystal
# For queries like: WHERE user_id = ? AND status = ?
schema.alter :orders do
  create_index :idx_orders_user_status, [:user_id, :status]
end
```

### Unique Index

Enforce uniqueness and speed up lookups:

```crystal
schema.alter :users do
  create_index :idx_users_email, [:email], unique: true
end
```

## Use Select to Limit Columns

Only fetch columns you need:

```crystal
# Instead of
users = User.all

# Use (returns lightweight rows with only these columns filled in)
rows = User.select(:id, :name, :email).all
rows.first.name  # => String?
```

## Use Pluck for Single Values

When you only need specific columns without model objects:

```crystal
# Returns array of emails
emails = User.where(active: true).pluck(:email, as: String)

# Returns array of {id, name} tuples
data = User.where(active: true).pluck(:id, :name, as: {Int64, String})

# One value from the first row
newest_id = User.order(id: :desc).pick(:id, as: Int64)
```

## Limit Result Sets

Always paginate or limit large queries:

```crystal
# Pagination
users = User.limit(20).offset(40).all

# Or use cursor pagination for large datasets
users = User.where { id > last_id }.limit(20).all
```

## Use Count Instead of Size

For counting records without loading them:

```crystal
# Efficient - runs COUNT query
count = User.where(active: true).count

# Inefficient - loads all records
count = User.where(active: true).all.size
```

## Batch Processing

Process large datasets in batches:

```crystal
# One record at a time, loaded 1000 per query
User.where(active: true).find_each(1000) do |user|
  user.update!(processed: true)
end

# Or a whole batch at a time
User.where(active: true).find_in_batches(1000) do |batch|
  batch.each { |user| user.update!(processed: true) }
end
```

Without an `order`, batches page by primary key (`WHERE id > ? ORDER BY id LIMIT ?`): each batch is an index seek, and it is safe to update the columns used in your `where` (for example flagging rows out of the filter) or to delete rows you have already visited. Across a join, an unordered query still yields each record once; an ordered or shaped query pages by OFFSET and yields a record once per joined row.

With an `order` (or a `select`, `distinct`, `group` or `having`), batches page by `LIMIT ... OFFSET ...` in that order, with the primary key appended to break ties. There, do not change the columns used in your `where` or delete rows while iterating, or later batches will skip rows, and each batch rescans the rows before it, so a full pass costs O(N²/batch size) on large tables.

Either way, a query's own `limit` and `offset` are ignored: batching walks every matching row.

## Use Exists Instead of Count

When checking for presence:

```crystal
# Efficient - stops at first match
if User.where(email: email).exists?
  # ...
end

# Inefficient - counts all matches
if User.where(email: email).count > 0
  # ...
end
```

## Optimize Ordering

Ensure ordered columns are indexed:

```crystal
# Add index for common ordering
schema.alter :posts do
  create_index :idx_posts_created_at, [:created_at]
end

# Query uses index
Post.order(created_at: :desc).limit(10).all
```

## Use the Bulk and Cached Paths

Prefer the paths that send fewer statements or reuse work:

```crystal
# Many rows in one statement per chunk (no validations or callbacks)
User.insert_all([{name: "Ada", email: "ada@example.com"}, {name: "Grace", email: "grace@example.com"}])
User.upsert_all([{email: "ada@example.com", name: "Ada L."}], on_conflict: :email)
user.insert_posts_all([{title: "One", body: "..."}, {title: "Two", body: "..."}])

# Associations for many parents: one query per chunk instead of one per parent
Post.preload(:user).all
User.preload(:posts, :profile).all

# Send only changed columns (opt-in per model)
class User
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::DirtyTracking
  # ...
end
```

`Model.find` reuses one rendered statement per model, unless the model defines its own `self.query`; keep per-call scopes there only when you need them. Leave SQL logging and the performance monitor off in production unless you are investigating something: each costs several microseconds per query. See [How CQL Keeps Queries Fast](../../explanation/performance-design.md) for why these paths are faster.

## Analyze Slow Queries

Log queries to find bottlenecks:

```crystal
CQL::Telemetry.alert_on_slow(100.milliseconds) do |event|
  Log.warn { "Slow query (#{event.duration.total_milliseconds.round(2)}ms): #{event.sql}" }
end
```

See [Monitor Performance](monitoring.md) and [Telemetry](telemetry.md) for more.

## Verify Optimization

Check query execution plans:

```crystal
query = User.where(email: "test@example.com").query

puts query.explain                 # the database's plan, one line per row
puts query.explain(analyze: true)  # runs the statement and reports real timings
```

Look for:
- Index scans (good) vs sequential scans (bad)
- Low row estimates
- Efficient join methods

## See Also

- [How CQL Keeps Queries Fast](../../explanation/performance-design.md)
- [Benchmark CQL](benchmark.md)
- [Avoid N+1 Queries](n-plus-one.md)
- [Create Indexes](../migrations/indexes.md)
- [Telemetry](telemetry.md)
- [Monitor Performance](monitoring.md)
