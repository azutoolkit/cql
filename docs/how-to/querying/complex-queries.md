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

```crystal
# Get users who have posts
active_author_ids = Post.where(published: true).pluck(:user_id)
authors = User.where { id.in(active_author_ids) }.all
```

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

```crystal
oldest_post = Post.min(:created_at)
most_views = Post.max(:views_count)
```

## Grouping Results

```crystal
# Posts per category
Category.all.map do |cat|
  {
    name: cat.name,
    posts: cat.posts.count
  }
end
```

## Select Specific Columns

```crystal
# Only fetch needed columns
names = User.where(active: true).pluck(:name)
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
unique_categories = Post.select(:category_id).distinct.all
```

## Query Related Records

```crystal
user = User.find!(1)

# Posts with conditions
published_posts = user.posts.where(published: true).all

# Ordered posts
recent_posts = user.posts.order(created_at: :desc).limit(5).all
```

## Complex Example

```crystal
# Get top 10 active users with most published posts
users_with_counts = User.where(active: true).all.map do |user|
  post_count = user.posts.where(published: true).count
  {user: user, post_count: post_count}
end

top_users = users_with_counts
  .sort_by { |h| -h[:post_count] }
  .first(10)

top_users.each do |h|
  puts "#{h[:user].name}: #{h[:post_count]} posts"
end
```

## Raw SQL (when needed)

For very complex queries:

```crystal
result = MyDB.exec(<<-SQL
  SELECT u.name, COUNT(p.id) as post_count
  FROM users u
  LEFT JOIN posts p ON p.user_id = u.id AND p.published = true
  WHERE u.active = true
  GROUP BY u.id
  ORDER BY post_count DESC
  LIMIT 10
SQL
)
```

## Verify Query Works

```crystal
# Setup test data
user = User.create!(name: "John", email: "john@example.com", active: true)
Post.create!(title: "Post 1", body: "...", user_id: user.id.not_nil!, published: true, views_count: 150)
Post.create!(title: "Post 2", body: "...", user_id: user.id.not_nil!, published: true, views_count: 50)

# Test query
popular = Post.where(published: true).where { views_count > 100 }.all
popular.size  # => 1
popular.first.title  # => "Post 1"
```

## Related

- [Filter with Where Clauses](filter-records.md)
- [Create Query Scopes](scopes.md)
- [Paginate Results](pagination.md)
