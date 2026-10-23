# Avoid N+1 Queries

Prevent the N+1 query problem that causes excessive database queries.

## Understanding N+1

The N+1 problem occurs when fetching a collection (1 query) and then accessing a relationship for each item (N queries).

### The Problem

```crystal
# 1 query to fetch posts
posts = Post.all

# N queries - one for each post's author!
posts.each do |post|
  puts post.user.try(&.name)  # belongs_to triggers a query on first access per post
end
```

With 100 posts, this runs 101 queries. The same happens in the other direction when you call `user.posts` for every user.

## Use Eager Loading

`preload` loads a `has_many` association for all parent records with one extra query (`WHERE foreign_key IN (...)`).

### Basic Preload

```crystal
# 2 queries total: users + posts
users = User.preload(:posts).all

users.each do |user|
  puts user.posts.size  # No additional query
end
```

### Multiple Relationships

```crystal
# Load multiple has_many associations
posts = Post
  .preload(:comments, :taggings)
  .all
```

`preload` only handles `has_many` associations today. Preloading a `belongs_to` (`Post.preload(:user)`), a `has_one` or a `many_to_many` association is silently ignored, so use batch loading (below) or a join for those.

## Use Joins for Filtering

When filtering by associated records, join through the association and put the condition on the joined table in the block:

```crystal
# Fetch posts written by active users
posts = Post
  .joins(:user) { user.active == true }
  .all
```

The join only filters; it does not populate `post.user`. Use `left_joins` to keep rows without a match.

## Select Only Needed Columns

Reduce memory by selecting specific columns:

```crystal
rows = Post
  .select(:id, :title, :user_id)
  .all   # lightweight rows with only these columns filled in
```

## Batch Loading

For custom relationships or complex scenarios:

This is the way to avoid N+1 queries for `belongs_to`:

```crystal
posts = Post.all

# Load all users at once
user_ids = posts.compact_map(&.user_id).uniq
users_by_id = User.where(id: user_ids).all.index_by(&.id)

posts.each do |post|
  user = users_by_id[post.user_id]?
  puts user.try(&.name)
end
```

## Detecting N+1 Queries

Enable query logging during development:

```crystal
CQL::Telemetry.log_queries   # one debug log line per statement, under the "cql.telemetry" log source
```

Or let CQL look for repeated queries for you:

```crystal
CQL::Performance.enable_development_mode!

# ... run your code ...

CQL::Performance.critical_issues         # N+1 patterns appear as issues of type :n_plus_one
CQL::Performance.high_priority_issues
```

Look for repeated similar queries:
```
SELECT * FROM users WHERE id = 1
SELECT * FROM users WHERE id = 2
SELECT * FROM users WHERE id = 3
...
```

## Common N+1 Scenarios

### In Views/Templates

```crystal
# Controller
@posts = Post.preload(:comments).all
@users_by_id = User.where(id: @posts.compact_map(&.user_id).uniq).all.index_by(&.id)

# View - comments are preloaded, so no query per post
<% @posts.each do |post| %>
  <p>By: <%= @users_by_id[post.user_id]?.try(&.name) %></p>
  <p>Comments: <%= post.comments.size %></p>
<% end %>
```

### Manual Counter Columns

For frequently accessed counts, add a counter column and maintain it manually:

```crystal
# Add column in migration
schema.alter :posts do
  add_column :comments_count, Int32, default: 0
end

# Update counter when adding comments
def create_comment(post : Post, content : String)
  Comment.create!(content: content, post_id: post.id!)
  post.comments_count = post.comments.count.to_i32
  post.save!
end

# Now use post.comments_count instead of post.comments.count
```

### Aggregations

```crystal
# Instead of
posts.each { |p| p.comments.count }  # N+1

# Use one grouped query on the comments table
counts = MyDB.query
  .from(:comments)
  .select(:post_id, count: :id)
  .group(:post_id)
  .all(as: {Int64, Int64})
  .to_h

posts.each { |p| puts counts[p.id!]? || 0 }
```

## Verify Fix

Before:
```
Post Load (2ms) SELECT * FROM posts
User Load (1ms) SELECT * FROM users WHERE id = 1
User Load (1ms) SELECT * FROM users WHERE id = 2
User Load (1ms) SELECT * FROM users WHERE id = 3
... (100 more queries)
```

After:
```
Post Load (2ms) SELECT * FROM posts
User Load (3ms) SELECT * FROM users WHERE id IN (1, 2, 3, ...)
```

## See Also

- [Optimize Queries](optimize-queries.md)
- [Monitor Performance](monitoring.md)
- [Set Up Has Many](../relationships/has-many.md)
