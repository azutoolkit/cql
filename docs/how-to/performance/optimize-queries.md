# Optimize Queries

Improve query performance with indexing, eager loading, and query optimization techniques.

## Prerequisites

- Working CQL application
- Understanding of your data access patterns

## Add Database Indexes

Indexes dramatically speed up queries on frequently searched columns.

### Single Column Index

```crystal
class AddIndexes < CQL::Migration(1)
  def up
    add_index :users, :email
    add_index :posts, :user_id
    add_index :posts, :published_at
  end

  def down
    remove_index :users, :email
    remove_index :posts, :user_id
    remove_index :posts, :published_at
  end
end
```

### Composite Index

For queries filtering on multiple columns:

```crystal
# For queries like: WHERE user_id = ? AND status = ?
add_index :orders, [:user_id, :status]
```

### Unique Index

Enforce uniqueness and speed up lookups:

```crystal
add_index :users, :email, unique: true
```

## Use Select to Limit Columns

Only fetch columns you need:

```crystal
# Instead of
users = User.all

# Use
users = User.select(:id, :name, :email).all
```

## Use Pluck for Single Values

When you only need specific columns without model objects:

```crystal
# Returns array of emails
emails = User.where(active: true).pluck(:email)

# Returns array of [id, name] tuples
data = User.select(:id, :name).pluck(:id, :name)
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
User.where(needs_update: true).each_batch(1000) do |batch|
  batch.each do |user|
    user.update!(processed: true)
  end
end
```

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
add_index :posts, :created_at

# Query uses index
Post.order(created_at: :desc).limit(10).all
```

## Analyze Slow Queries

Log queries to find bottlenecks:

```crystal
MyDB.on_query do |sql, duration|
  if duration > 100.milliseconds
    Log.warn { "Slow query (#{duration}ms): #{sql}" }
  end
end
```

## Verify Optimization

Check query execution plans:

```crystal
result = MyDB.exec("EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'test@example.com'")
puts result.first
```

Look for:
- Index scans (good) vs sequential scans (bad)
- Low row estimates
- Efficient join methods

## See Also

- [Avoid N+1 Queries](n-plus-one.md)
- [Create Indexes](../migrations/indexes.md)
- [Monitor Performance](monitoring.md)
