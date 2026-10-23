# Build Complex Queries

This guide shows you how to build complex queries with multiple conditions, joins, and aggregations.

## Chain Multiple Methods

```crystal
posts = Post
  .where(published: true)
  .where { views_count > 100 }
  .order(created_at: :desc)
  .limit(10)
  .all
```

## Compound Conditions

### AND

```crystal
User.where { (active == true) & (verified == true) & (age > 18) }.all
```

### OR

```crystal
User.where { (role == "admin") | (role == "moderator") | (role == "owner") }.all
```

### Mixed

```crystal
User.where { (active == true) & ((role == "admin") | (role == "moderator")) }.all
```

## Subqueries

Collect the ids first, then use them in an `IN` condition (`pluck` on a query needs the Crystal type to read the column as):

```crystal
# Get users who have published posts
active_author_ids = Post.where(published: true).pluck(:user_id, as: Int64)
authors = User.where { id.in(active_author_ids) }.all
```

Because values are always bound as parameters, the list is never interpolated into the SQL.

## Aggregations

### Count

```crystal
total = User.count
active = User.where(active: true).count
```

### Sum

```crystal
total_views = Post.where(published: true).sum(:views_count)
```

### Average

```crystal
avg_age = User.where(active: true).avg(:age)
```

### Min/Max

`min`/`max` read numeric columns. For dates, order and take the first row instead:

```crystal
fewest_views = Post.min(:views_count)
most_views = Post.max(:views_count)
oldest_post = Post.order(created_at: :asc).first
```

## Grouping Results

Use the query builder on the schema for `GROUP BY`/`HAVING`, and tell `all` what shape each row has:

```crystal
# Posts per category, only categories with more than 5 posts
rows = MyDB.query
  .from(:posts)
  .select(:category_id, count: :id)
  .group(:category_id)
  .having { count(:id) > 5 }
  .all(as: {Int64, Int64})

rows.each { |category_id, post_count| puts "#{category_id}: #{post_count}" }
```

Model queries also expose `group(:column)` and `having { ... }`, but their rows are mapped to the model, so use the schema query for aggregates.

## Select Specific Columns

```crystal
# Only fetch needed columns, as plain values
names = User.where(active: true).pluck(:name, as: String)

# Or lightweight rows with only the selected columns filled in
rows = User.where(active: true).select(:id, :name).all
rows.first.name  # => String? (other columns are nil)
```

## Order by Multiple Columns

```crystal
Post.order(published: :desc, created_at: :desc).all
```

## Offset for Pagination

```crystal
page = 2
per_page = 10

Post.order(created_at: :desc)
    .limit(per_page)
    .offset((page - 1) * per_page)
    .all
```

## Distinct Results

```crystal
unique_categories = Post.distinct(:category_id, as: Int64)

# or on a query
Post.where(published: true).select(:category_id).distinct.all
```

## Query Related Records

Query the associated model directly, keyed on the foreign key. This gives you the full query builder, scopes and typed `where` blocks:

```crystal
user = User.find!(1)

# Posts with conditions
published_posts = Post.where(user_id: user.id!, published: true).all

# Ordered posts
recent_posts = Post.where(user_id: user.id!).order(created_at: :desc).limit(5).all
```

`user.posts` returns a `Collection`. Its `where`, `order`, `limit` and `offset` return a plain `CQL::Query`, so finish with `.all(Post)`:

```crystal
user.posts.where(published: true).all(Post)
user.posts.order(created_at: :desc).limit(5).all(Post)
```

## Complex Example

```crystal
# Top 10 active users by published post count
users_with_counts = User.where(active: true).all.map do |user|
  post_count = Post.where(user_id: user.id!, published: true).count
  {user: user, post_count: post_count}
end

top_users = users_with_counts
  .sort_by { |h| -h[:post_count] }
  .first(10)

top_users.each do |h|
  puts "#{h[:user].name}: #{h[:post_count]} posts"
end
```

This issues one count query per user. For large tables, use a joined `GROUP BY` query (see above) or `preload` and count in memory.

## Joins

Join through a declared association and filter on the joined table with a typed block:

```crystal
User.joins(:posts) { posts.published == true }.all
User.left_joins(:profile).where { age > 18 }.all
```

## Raw SQL (when needed)

Add a SQL fragment with bound values to any query. `?` binds positionally and `:name` binds by name:

```crystal
User.where("lower(email) = ? AND age > :age", "john@example.com", age: 18).all
```

For a whole statement, run it on a pooled connection and map the rows yourself:

```crystal
rows = MyDB.exec_query do |conn|
  conn.query_all(<<-SQL, as: {String, Int64})
    SELECT u.name, COUNT(p.id) AS post_count
    FROM users u
    LEFT JOIN posts p ON p.user_id = u.id AND p.published = true
    WHERE u.active = true
    GROUP BY u.id
    ORDER BY post_count DESC
    LIMIT 10
  SQL
end
```

## Verify Query Works

```crystal
# Setup test data
user = User.create!(name: "John", email: "john@example.com", active: true)
Post.create!(title: "Post 1", body: "...", user_id: user.id!, published: true, views_count: 150)
Post.create!(title: "Post 2", body: "...", user_id: user.id!, published: true, views_count: 50)

# Test query
popular = Post.where(published: true).where { views_count > 100 }.all
popular.size  # => 1
popular.first.title  # => "Post 1"
```

## Related

- [Filter with Where Clauses](filter-records.md)
- [Create Query Scopes](scopes.md)
- [Paginate Results](pagination.md)
