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
  puts post.user.name  # Triggers a query each time
end
```

With 100 posts, this runs 101 queries.

## Use Eager Loading

Load relationships upfront with batch queries using `preload`.

### Basic Preload

```crystal
# 2 queries total: posts + users
posts = Post.preload(:user).all

posts.each do |post|
  puts post.user.name  # No additional query
end
```

### Multiple Relationships

```crystal
# Load multiple associations
posts = Post
  .preload(:user, :comments)
  .all
```

## Use Joins for Filtering

When filtering by associated records:

```crystal
# Fetch posts with comments from active users
posts = Post
  .joins(:user)
  .where("users.active = ?", true)
  .all
```

## Select Only Needed Columns

Reduce memory by selecting specific columns:

```crystal
posts = Post
  .select(:id, :title, :user_id)
  .all
```

## Batch Loading

For custom relationships or complex scenarios:

```crystal
posts = Post.all

# Load all users at once
user_ids = posts.map(&.user_id).uniq
users_by_id = User.where(id: user_ids).index_by(&.id)

posts.each do |post|
  user = users_by_id[post.user_id]
  puts user.name
end
```

## Detecting N+1 Queries

Enable query logging during development:

```crystal
MyDB.on_query do |sql, duration|
  Log.debug { sql }
end
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
@posts = Post.preload(:user, :comments).all

# View - no additional queries
<% @posts.each do |post| %>
  <p>By: <%= post.user.name %></p>
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
  Comment.create!(content: content, post_id: post.id.not_nil!)
  post.comments_count = post.comments.count.to_i32
  post.save!
end

# Now use post.comments_count instead of post.comments.count
```

### Aggregations

```crystal
# Instead of
posts.each { |p| p.comments.count }  # N+1

# Use
Post.joins(:comments)
    .group(:id)
    .select("posts.*, COUNT(comments.id) as comments_count")
    .all
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
