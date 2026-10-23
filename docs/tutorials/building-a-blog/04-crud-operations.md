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
# Method 1: new + save (runs validations and callbacks)
user = User.new(username: "john", email: "john@example.com")
if user.save
  puts "User created with ID: #{user.id}"
else
  puts "Failed to create user" # a callback halted the save
end

# Method 2: save! (raises CQL::RecordNotSaved or CQL::RecordInvalid instead of returning false)
user = User.new(username: "bob", email: "bob@example.com")
user.save!
puts "User created" if user.persisted?

# Method 3: create! (inserts the given columns and returns the stored record)
user = User.create!(
  username: "jane",
  email: "jane@example.com",
  first_name: "Jane"
)
```

`create!` writes exactly the columns you pass and lets the database fill in defaults; it does not go through your `initialize`, so anything `initialize` computes (like the category slug) must be passed explicitly or created with `new` + `save`.

### Creating with Relationships

```crystal
# Create a user first
author = User.create!(username: "alice", email: "alice@example.com")

# Create a category (new + save so initialize generates the slug)
tech = Category.new(name: "Technology")
tech.save!

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
  Category.new(name).tap(&.save!)
end

puts "Created #{categories.size} categories"
```

## Read Operations

### Finding by ID

```crystal
# find returns nil if not found
user = User.find(1)
if user
  puts "Found: #{user.username}"
else
  puts "User not found"
end

# find! raises DB::NoResultsError if not found
begin
  user = User.find!(999)
rescue ex : DB::NoResultsError
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

# Using blocks for complex conditions (bare column names, typed against the schema)
popular_posts = Post.where { views_count > 100 }.all
recent_posts = Post.where { created_at > 1.week.ago }.all
extremes = Post.where { (views_count < 5) | (views_count > 1000) }.all

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
user = User.find!(1)
user_posts = user.posts.all

# Filter user's posts at the database
published_user_posts = Post.where(user_id: user.id!, published: true).all

# Get post's comments
post = Post.find!(1)
comments = post.comments.all

# Get posts in a category
category = Category.find_by(slug: "technology")
tech_posts = Post.where(category_id: category.id!, published: true).all if category
```

To filter on the other side of an association, join it and write the condition against the joined table:

```crystal
by_alice = Post.query.joins(:user) { user.username == "alice" }.to_a
```

Inside these blocks, bare names such as `user` or `views_count` are the model's typed columns and associations. A local variable with the same name takes precedence, so don't have a local called `user` in scope when you write `user.username`.

### Pagination

```crystal
# Built-in helper (oldest first, no filter)
first_page = Post.page(1, 10)

# Filtered and ordered pagination
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

# Method 3: Update by primary key without loading the record
Post.update!(1_i64, published: true)
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
# Publish all draft posts by a user with a single UPDATE statement
BlogSchema.update
  .table(:posts)
  .set(published: true)
  .where(user_id: 1, published: false)
  .commit

# Deactivate users who haven't posted (loads each user: fine for small tables)
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

# delete! runs the before_destroy / after_destroy callbacks and
# returns true when a row was removed
post = Post.find(1)
post.try(&.delete!)

# Delete by primary key without loading the record
Post.delete!(2_i64)
```

### Deleting with Conditions

```crystal
# Delete all comments on a post (one DELETE statement)
Comment.delete_by!(post_id: 1)

# Delete all unpublished posts
Post.delete_by!(published: false)

# Delete old comments with the lower-level delete builder
BlogSchema.delete
  .from(:comments)
  .where { comments.created_at < 1.year.ago }
  .commit
```

### Cascading Deletes

Remember our foreign key setup? Deleting a user cascades to their posts, which cascade to comments:

```crystal
# This deletes the user AND all their posts AND all comments on those posts
user = User.find(1)
user.try(&.delete!)
```

The cascade comes from the `ON DELETE CASCADE` foreign keys, so the database performs it. (The `dependent:` option of `has_many` is not what removes the rows here.) PostgreSQL and MySQL always enforce foreign keys; SQLite only does when the connection asks for it, which is why Part 1 put `?foreign_keys=1` on the database URL.

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
  count = Post.where(category_id: category.id!, published: true).count
  puts "#{category.name}: #{count} posts"
end

# Most active authors: one GROUP BY query instead of one count per user
counts = BlogSchema.query
  .from(:posts)
  .select(:user_id, count: :id)
  .group(:user_id)
  .all(as: {Int64, Int64})

counts.sort_by { |_, total| -total }.first(5).each do |user_id, total|
  puts "#{User.find!(user_id).display_name}: #{total} posts"
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

1. **Create**: `new` + `save`/`save!`, and `create!`
2. **Read**: `find`, `find_by`, `where`, `order`, `limit`
3. **Update**: attribute assignment + `save`, `update!`, bulk updates
4. **Delete**: `delete!`, `delete_by!`, bulk deletes
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
