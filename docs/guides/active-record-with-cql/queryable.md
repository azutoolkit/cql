# Queryable: Building Expressive Queries in CQL Active Record

The `Queryable` module in CQL provides a powerful, type-safe, and chainable interface for constructing SQL queries using idiomatic Crystal code. It enables you to filter, sort, join, and aggregate records with a fluent API, abstracting away raw SQL while retaining full expressiveness and performance.

This guide covers how to use the query interface provided by CQL Active Record models and repositories, including all major query methods and best practices.

---

## Basic Usage

You can build queries directly on your model or repository. Most query methods return a chainable query object, allowing you to compose complex queries step by step.

### Example: Simple Filtering

```crystal
# Find all users named "Alice"
alice_users = User.where(name: "Alice").all

# Find the first user with a specific email
user = User.where(email: "alice@example.com").first
```

### Example: Using a Repository

```crystal
user_repo = UserRepository.new
# Find all users with a given domain
gmail_users = user_repo.query.where { email.like("%@gmail.com") }.all(User)
```

---

## Chainable Query Methods

CQL provides a rich set of chainable query methods that allow you to build complex queries in a type-safe and expressive way. Each method returns a query object that can be further chained with additional methods.

### `where`

The `where` method is used to filter records based on conditions. It supports both simple key-value pairs and block-based conditions.

```crystal
# Simple key-value conditions
User.where(name: "Alice", active: true)

# Block-based conditions with operators
User.where { age > 18 }
User.where { (name.like("A%")) & (age >= 21) }

# Multiple conditions
User.where(name: "Alice").where(active: true)
```

### `order`

Sort records using the `order` method. You can specify multiple columns and sort directions.

```crystal
# Single column ordering
User.order(:name)                    # ASC by default
User.order(name: :desc)              # Explicit DESC

# Multiple columns
User.order(:created_at, name: :desc)

# Using block syntax
User.order { created_at.desc }
```

### `limit` and `offset`

Control the number of records returned and paginate through results.

```crystal
# Get first 10 records
User.limit(10)

# Skip first 20 records and get next 10
User.offset(20).limit(10)
```

### `select`

Specify which columns to retrieve from the database.

```crystal
# Select specific columns
User.select(:id, :name, :email)

# Using block syntax
User.select { [id, name, email] }

# With aliases
User.select { [id.as("user_id"), name.as("user_name")] }
```

### `group_by`

Group records by one or more columns, often used with aggregate functions.

```crystal
# Group by single column
User.group_by(:role)

# Multiple columns
User.group_by(:role, :status)

# With block syntax
User.group_by { [role, status] }
```

### `join`

Perform SQL joins between tables. CQL supports various join types and provides a type-safe way to specify join conditions.

```crystal
# Simple inner join
User.join(Post)

# Join with conditions
User.join(Post) { users.id == posts.user_id }

# Multiple joins
User.join(Post)
    .join(Comment) { posts.id == comments.post_id }

# Different join types
User.left_join(Post)
User.right_join(Post)
User.full_join(Post)
```

### `having`

Add conditions to grouped records, typically used with `group_by`.

```crystal
User.group_by(:role)
    .having { count(id) > 5 }
```

### `distinct`

Remove duplicate records from the result set.

```crystal
User.distinct
User.distinct(:name, :email)
```

---

## Terminal Operations

Terminal operations execute the query and return the results. These methods are typically used at the end of a query chain to fetch the data from the database.

### `all`

Returns all records matching the query as an array.

```crystal
# Get all users
users = User.all

# Get all active users ordered by name
active_users = User.where(active: true)
                  .order(:name)
                  .all

# Get all users with their posts
users_with_posts = User.join(Post)
                      .select { [users.*, posts.*] }
                      .all
```

### `first` and `first!`

Returns the first record matching the query. `first` returns `nil` if no record is found, while `first!` raises an error.

```crystal
# Get the first user (returns nil if none found)
first_user = User.first

# Get the first user (raises error if none found)
first_user = User.first!

# Get the first active user ordered by creation date
oldest_active = User.where(active: true)
                   .order(:created_at)
                   .first
```

### `find` and `find!`

Find a record by its primary key. `find` returns `nil` if not found, while `find!` raises an error.

```crystal
# Find user by ID (returns nil if not found)
user = User.find(1)

# Find user by ID (raises error if not found)
user = User.find!(1)

# Find with additional conditions
active_user = User.where(active: true).find(1)
```

### `count`

Returns the number of records matching the query.

```crystal
# Count all users
total_users = User.count

# Count active users
active_count = User.where(active: true).count

# Count users by role
role_counts = User.group_by(:role)
                 .select { [role, count(id).as("count")] }
                 .all
```

### `exists?`

Checks if any records match the query.

```crystal
# Check if any users exist
has_users = User.exists?

# Check if any active users exist
has_active = User.where(active: true).exists?

# Check if a specific user exists
user_exists = User.where(email: "alice@example.com").exists?
```

### `pluck`

Returns an array of values for the specified columns.

```crystal
# Get all user names
names = User.pluck(:name)

# Get multiple columns
name_emails = User.pluck(:name, :email)

# With conditions
active_names = User.where(active: true)
                  .pluck(:name)
```

### `sum`, `average`, `minimum`, `maximum`

Aggregate functions that can be used to calculate statistics.

```crystal
# Calculate total age of all users
total_age = User.sum(:age)

# Calculate average age
avg_age = User.average(:age)

# Find minimum and maximum ages
min_age = User.minimum(:age)
max_age = User.maximum(:age)

# With conditions
active_avg_age = User.where(active: true)
                    .average(:age)
```

### `find_each` and `find_in_batches`

Process records in batches to handle large datasets efficiently.

```crystal
# Process users one at a time
User.find_each(batch_size: 1000) do |user|
  # Process each user
  process_user(user)
end

# Process users in batches
User.find_in_batches(batch_size: 1000) do |users|
  # Process batch of users
  process_users(users)
end
```

---

## Composing Complex Queries

CQL's query interface allows you to build complex queries by combining multiple query methods. This section demonstrates common patterns and best practices for composing sophisticated queries.

### Advanced Filtering

Combine multiple conditions using logical operators and complex expressions.

```crystal
# Complex where conditions
User.where { (age >= 18) & (active == true) }
    .where { (name.like("A%")) | (email.like("%@gmail.com")) }

# Nested conditions
User.where { (role == "admin") & ((status == "active") | (status == "pending")) }

# Using IN clauses
User.where { role.in(["admin", "moderator"]) }
    .where { status.in(["active", "pending"]) }
```

### Joins with Conditions

Combine joins with filtering and ordering.

```crystal
# Join with filtering on both tables
User.join(Post) { users.id == posts.user_id }
    .where { (users.active == true) & (posts.published == true) }
    .order { [users.name, posts.created_at.desc] }

# Multiple joins with conditions
User.join(Post) { users.id == posts.user_id }
    .join(Comment) { posts.id == comments.post_id }
    .where { comments.created_at > 1.week.ago }
    .select { [users.*, posts.title, count(comments.id).as("comment_count")] }
    .group_by { [users.id, posts.id] }
```

### Aggregations with Grouping

Combine grouping with aggregations and having clauses.

```crystal
# User statistics by role
User.group_by(:role)
    .select { [role, count(id).as("total"),
              average(age).as("avg_age"),
              maximum(age).as("max_age")] }
    .having { count(id) > 5 }
    .order { count(id).desc }

# Post statistics with user information
User.join(Post) { users.id == posts.user_id }
    .group_by { [users.id, users.name] }
    .select { [users.name,
              count(posts.id).as("post_count"),
              average(posts.view_count).as("avg_views")] }
    .having { count(posts.id) >= 3 }
```

### Subqueries

Use subqueries for complex filtering and data retrieval.

```crystal
# Users with more than 5 posts
User.where { id.in(
  Post.select(:user_id)
      .group_by(:user_id)
      .having { count(id) > 5 }
) }

# Users with recent activity
User.where { id.in(
  Post.select(:user_id)
      .where { created_at > 1.week.ago }
      .union(
        Comment.select(:user_id)
               .where { created_at > 1.week.ago }
      )
) }
```

### Common Table Expressions (CTEs)

Use CTEs for complex queries that need to reference the same subquery multiple times.

```crystal
# Users with their post and comment counts
User.with(:user_stats) {
  User.select { [
    id,
    count(posts.id).as("post_count"),
    count(comments.id).as("comment_count")
  ] }
  .left_join(Post) { users.id == posts.user_id }
  .left_join(Comment) { users.id == comments.user_id }
  .group_by(:id)
}
.select { [users.*, user_stats.*] }
.join(:user_stats) { users.id == user_stats.id }
```

### Query Scopes

Define reusable query scopes for common query patterns.

```crystal
struct User
  include CQL::ActiveRecord::Model(Int32)

  # ... other code ...

  def self.active
    where(active: true)
  end

  def self.admins
    where(role: "admin")
  end

  def self.recently_created
    where { created_at > 1.week.ago }
  end

  def self.with_posts
    join(Post) { users.id == posts.user_id }
  end
end

# Using scopes
User.active
    .admins
    .recently_created
    .with_posts
    .order(:name)
```

---

## Best Practices

Following these best practices will help you write more efficient, maintainable, and performant queries in CQL.

### Query Performance

1. **Select Only Needed Columns**

   ```crystal
   # Instead of
   User.all

   # Use
   User.select(:id, :name, :email).all
   ```

2. **Use Appropriate Indexes**

   - Add indexes for frequently queried columns
   - Index foreign keys and columns used in WHERE clauses
   - Consider composite indexes for commonly combined conditions

3. **Avoid N+1 Queries**

   ```crystal
   # Instead of
   users = User.all
   users.each do |user|
     posts = user.posts.all  # N+1 queries!
   end

   # Use
   User.join(Post)
       .select { [users.*, posts.*] }
       .all
   ```

4. **Use Batch Processing for Large Datasets**

   ```crystal
   # Instead of
   User.all.each do |user|
     process_user(user)
   end

   # Use
   User.find_each(batch_size: 1000) do |user|
     process_user(user)
   end
   ```

### Code Organization

1. **Use Query Scopes for Reusable Logic**

   ```crystal
   struct User
     include CQL::ActiveRecord::Model(Int32)

     def self.active
       where(active: true)
     end

     def self.recent
       where { created_at > 1.week.ago }
     end
   end

   # Usage
   User.active.recent
   ```

2. **Extract Complex Queries to Methods**

   ```crystal
   struct User
     def self.search_by_name_or_email(query)
       where { (name.like("%#{query}%")) |
               (email.like("%#{query}%")) }
     end

     def self.with_post_counts
       left_join(Post) { users.id == posts.user_id }
         .group_by(:id)
         .select { [users.*, count(posts.id).as("post_count")] }
     end
   end
   ```

3. **Use Meaningful Names for Complex Queries**
   ```crystal
   def find_active_users_with_recent_posts
     User.active
         .join(Post) { users.id == posts.user_id }
         .where { posts.created_at > 1.week.ago }
         .distinct
   end
   ```

### Query Safety

1. **Use Parameterized Queries**

   ```crystal
   # Instead of
   User.where { name == "#{user_input}" }

   # Use
   User.where(name: user_input)
   ```

2. **Validate Input Before Querying**

   ```crystal
   def search_users(query)
     return User.none if query.blank?
     User.where { name.like("%#{query}%") }
   end
   ```

3. **Handle Edge Cases**
   ```crystal
   def find_user_by_email(email)
     return nil if email.blank?
     User.where(email: email.downcase.strip).first
   end
   ```

### Testing

1. **Test Query Scopes**

   ```crystal
   describe User do
     it "finds active users" do
       active_user = User.create(active: true)
       inactive_user = User.create(active: false)

       expect(User.active).to contain(active_user)
       expect(User.active).not_to contain(inactive_user)
     end
   end
   ```

2. **Test Complex Queries**

   ```crystal
   describe User do
     it "finds users with recent posts" do
       user = User.create
       old_post = Post.create(user: user, created_at: 2.weeks.ago)
       recent_post = Post.create(user: user, created_at: 3.days.ago)

       result = User.with_recent_posts
       expect(result).to contain(user)
     end
   end
   ```

### Debugging

1. **Use `to_sql` for Query Inspection**

   ```crystal
   query = User.where(active: true).order(:name)
   puts query.to_sql  # Prints the generated SQL
   ```

2. **Log Slow Queries**

   ```crystal
   def self.log_slow_queries
     start_time = Time.monotonic
     result = yield
     duration = Time.monotonic - start_time

     if duration > 1.second
       Log.warn { "Slow query detected: #{duration.total_seconds}s" }
     end

     result
   end
   ```

---

## Next Steps

- [Reference Table](#reference-table)
