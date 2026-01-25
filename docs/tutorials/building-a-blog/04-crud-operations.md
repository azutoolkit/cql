# Part 4: CRUD Operations

In this part, you'll learn how to create, read, update, and delete records in your blog engine. You'll also explore querying patterns, bulk operations, and best practices for working with data.

## What You'll Learn

- Creating records (single and bulk)
- Reading and querying records
- Updating records
- Deleting records
- Using query scopes
- Aggregation and counting

## Prerequisites

- Completed [Part 3: Models and Relationships](03-models-and-relationships.md)

## Create Operations

### Creating a Single Record

There are several ways to create records:

```crystal
# Method 1: new + save
user = User.new(username: "john", email: "john@example.com")
if user.save
  puts "User created with ID: #{user.id}"
else
  puts "Failed to create user"
end

# Method 2: create! (raises on failure)
user = User.create!(
  username: "jane",
  email: "jane@example.com",
  first_name: "Jane"
)

# Method 3: create (returns the record, check persisted?)
user = User.create(username: "bob", email: "bob@example.com")
if user.persisted?
  puts "User created"
end
```

### Creating with Relationships

```crystal
# Create a user first
author = User.create!(username: "alice", email: "alice@example.com")

# Create a category
tech = Category.create!(name: "Technology")

# Create a post with relationships
post = Post.create!(
  title: "My First Post",
  content: "Hello, world! This is my first blog post.",
  user_id: author.id.not_nil!,
  category_id: tech.id,
  published: true
)

# Create a comment on the post
comment = Comment.create!(
  content: "Welcome to blogging!",
  post_id: post.id.not_nil!,
  user_id: author.id
)
```

### Creating Multiple Records

```crystal
# Create sample categories
categories = ["Technology", "Lifestyle", "Travel", "Food"].map do |name|
  Category.create!(name: name)
end

puts "Created #{categories.size} categories"
```

## Read Operations

### Finding by ID

```crystal
# Find returns nil if not found
user = User.find(1)
if user
  puts "Found: #{user.username}"
else
  puts "User not found"
end

# Find! raises if not found
begin
  user = User.find!(999)
rescue ex
  puts "User not found: #{ex.message}"
end
```

### Finding by Attributes

```crystal
# Find first matching record
user = User.find_by(email: "alice@example.com")
puts "Found user: #{user.try(&.username)}"

# Find with multiple conditions
post = Post.find_by(published: true, user_id: 1)
```

### Querying Multiple Records

```crystal
# Get all records
all_users = User.all
puts "Total users: #{all_users.size}"

# Filter with where
active_users = User.where(active: true).all
published_posts = Post.where(published: true).all

# Chain conditions
recent_published = Post
  .where(published: true)
  .order(created_at: :desc)
  .limit(10)
  .all

# Get first/last
first_user = User.first
last_post = Post.last
```

### Complex Queries

```crystal
# Multiple conditions
posts = Post
  .where(published: true)
  .where(user_id: author.id)
  .order(views_count: :desc)
  .all

# Using blocks for complex conditions
popular_posts = Post.where { views_count > 100 }.all
recent_posts = Post.where { created_at > 1.week.ago }.all

# Combining conditions
featured = Post
  .where(published: true)
  .where { views_count > 50 }
  .order(created_at: :desc)
  .limit(5)
  .all
```

### Querying Through Relationships

```crystal
# Get user's posts
user = User.find(1)
user_posts = user.posts.all

# Filter user's posts
published_user_posts = user.posts.where(published: true).all

# Get post's comments
post = Post.find(1)
comments = post.comments.all

# Get posts in a category
category = Category.find_by(slug: "technology")
tech_posts = category.posts.where(published: true).all if category
```

### Pagination

```crystal
# Simple pagination
page = 1
per_page = 10

posts = Post
  .where(published: true)
  .order(created_at: :desc)
  .limit(per_page)
  .offset((page - 1) * per_page)
  .all

# Get total for pagination info
total = Post.where(published: true).count
total_pages = (total / per_page.to_f).ceil.to_i
```

## Update Operations

### Updating a Single Record

```crystal
# Method 1: Change attributes and save
user = User.find(1)
if user
  user.first_name = "Alice"
  user.last_name = "Smith"
  user.save
  puts "User updated"
end

# Method 2: update! with attributes
post = Post.find(1)
post.try(&.update!(published: true, views_count: 100_i64))

# Method 3: Using update on query
Post.where(id: 1).update!(published: true)
```

### Incrementing Values

```crystal
# Increment view count
post = Post.find(1)
if post
  post.views_count += 1
  post.save
end

# Or use a custom method (defined in model)
post.try(&.increment_views!)
```

### Bulk Updates

```crystal
# Publish all draft posts by a user
Post.where(user_id: 1, published: false).update!(published: true)

# Deactivate users who haven't posted
# (This would require a more complex query in practice)
User.where(active: true).each do |user|
  if user.posts.count == 0
    user.active = false
    user.save
  end
end
```

## Delete Operations

### Deleting a Single Record

```crystal
# Method 1: Find and delete
user = User.find(1)
user.try(&.delete!)
puts "User deleted"

# Method 2: Using destroy (triggers callbacks)
post = Post.find(1)
post.try(&.destroy!)
```

### Deleting with Conditions

```crystal
# Delete all comments on a post
Comment.where(post_id: 1).delete!

# Delete all unpublished posts
Post.where(published: false).delete!

# Delete old anonymous comments
Comment.where(user_id: nil).where { created_at < 1.year.ago }.delete!
```

### Cascading Deletes

Remember our foreign key setup? Deleting a user cascades to their posts, which cascade to comments:

```crystal
# This deletes the user AND all their posts AND all comments on those posts
user = User.find(1)
user.try(&.delete!)
```

## Aggregations

### Counting

```crystal
# Count all
total_users = User.count
total_posts = Post.count

# Count with conditions
published_count = Post.where(published: true).count
active_users = User.where(active: true).count

# Count through relationships
user = User.find(1)
post_count = user.posts.count if user
```

### Sum, Average, Min, Max

```crystal
# Total views across all published posts
total_views = Post.where(published: true).sum(:views_count)

# Average views
avg_views = Post.where(published: true).avg(:views_count)

# Most views
max_views = Post.where(published: true).max(:views_count)

# Least views
min_views = Post.where(published: true).min(:views_count)
```

### Grouping and Statistics

```crystal
# Posts per category
Category.all.each do |category|
  count = category.posts.where(published: true).count
  puts "#{category.name}: #{count} posts"
end

# Most active authors
User.all.sort_by { |u| -u.posts.count }.first(5).each do |user|
  puts "#{user.display_name}: #{user.posts.count} posts"
end
```

## Batch Processing

For large datasets, process records in batches:

```crystal
# Process all posts in batches
Post.find_each(batch_size: 100) do |post|
  # Process each post
  puts "Processing: #{post.title}"
end
```

## Practical Examples

### Blog Dashboard Data

```crystal
def dashboard_stats
  {
    total_users: User.count,
    active_users: User.where(active: true).count,
    total_posts: Post.count,
    published_posts: Post.where(published: true).count,
    draft_posts: Post.where(published: false).count,
    total_comments: Comment.count,
    total_views: Post.sum(:views_count)
  }
end

stats = dashboard_stats
puts "Users: #{stats[:total_users]} (#{stats[:active_users]} active)"
puts "Posts: #{stats[:published_posts]} published, #{stats[:draft_posts]} drafts"
puts "Total views: #{stats[:total_views]}"
```

### Recent Activity Feed

```crystal
def recent_activity(limit = 10)
  posts = Post.where(published: true)
              .order(created_at: :desc)
              .limit(limit)
              .all

  posts.map do |post|
    {
      type: "post",
      title: post.title,
      author: post.user.try(&.display_name) || "Unknown",
      date: post.created_at
    }
  end
end
```

### Search Posts

```crystal
def search_posts(query : String)
  Post.where(published: true)
      .where { title.like("%#{query}%") | content.like("%#{query}%") }
      .order(views_count: :desc)
      .all
end

results = search_posts("crystal")
puts "Found #{results.size} posts matching 'crystal'"
```

## Summary

In this part, you learned:

1. **Create**: `new` + `save`, `create`, and `create!`
2. **Read**: `find`, `find_by`, `where`, `order`, `limit`
3. **Update**: attribute assignment + `save`, `update!`, bulk updates
4. **Delete**: `delete!`, `destroy!`, bulk deletes
5. **Aggregate**: `count`, `sum`, `avg`, `min`, `max`
6. **Batch**: `find_each` for large datasets

## Next Steps

In [Part 5: Adding Features](05-adding-features.md), you'll add validations, callbacks, and performance monitoring to complete your blog engine.

---

**Tutorial Navigation:**
- [Part 1: Project Setup](01-project-setup.md)
- [Part 2: Database Schema](02-database-schema.md)
- [Part 3: Models and Relationships](03-models-and-relationships.md)
- Part 4: CRUD Operations (current)
- [Part 5: Adding Features](05-adding-features.md)
