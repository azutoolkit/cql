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

# Using query builder directly
users = User.query.where { age > 18 }.order(:name).all(User)
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

# Single condition with hash syntax
User.where(active: true)

# Block-based conditions with operators
User.where { age > 18 }
User.where { (name.like("A%")) & (age >= 21) }

# Multiple where clauses (AND behavior)
User.where(name: "Alice").where(active: true)

# Complex logical conditions
User.where { (role == "admin") | (role == "moderator") }
User.where { (age >= 18) & (age <= 65) }

# Using IN clauses
User.where { role.in(["admin", "moderator"]) }
User.where { id.not_in([1, 2, 3]) }

# NULL checks
User.where { email.is_not_null }
User.where { deleted_at.is_null }
```

### `where_like`

Pattern matching using SQL LIKE operator.

```crystal
# Find users with names starting with "John"
User.where_like(:name, "John%")

# Find users with emails from gmail
User.where_like(:email, "%@gmail.com")

# Case-insensitive search (database dependent)
User.where_like(:name, "%john%")

# Complex pattern matching
User.where_like(:phone, "+1-___-___-____")  # Specific format
```

### `order`

Sort records using the `order` method. You can specify multiple columns and sort directions.

```crystal
# Single column ordering
User.order(:name)                    # ASC by default
User.order(:created_at)              # ASC by default

# Explicit direction with hash syntax
User.order(name: :desc)
User.order(created_at: :desc, name: :asc)

# Multiple columns with mixed directions
User.order(:role, name: :desc)

# Using block syntax for complex ordering
User.order { created_at.desc }
User.order { [role.asc, created_at.desc] }

# Order by calculated expressions
User.order { age * 2 }
User.order { (created_at - updated_at).abs }
```

### `reorder`

Replace existing order clauses with new ones.

```crystal
# Replace previous ordering
query = User.order(:name)
query = query.reorder(:created_at)  # Only orders by created_at now

# Multiple columns
User.order(:name).reorder(:role, :created_at)

# With directions
User.order(:name).reorder(created_at: :desc, name: :asc)
```

### `reverse_order`

Reverse the current ordering direction.

```crystal
# Reverse single order
User.order(:name).reverse_order          # Changes ASC to DESC

# Reverse multiple orders
User.order(:role, :name).reverse_order   # Reverses both directions

# Useful for toggling sort order
sort_dir = params["sort_dir"]? == "desc" ? :desc : :asc
users = User.order(:name)
users = users.reverse_order if sort_dir == :desc
```

### `limit` and `offset`

Control the number of records returned and paginate through results.

```crystal
# Get first 10 records
User.limit(10)

# Skip first 20 records and get next 10
User.offset(20).limit(10)

# Pagination helper
page = 3
per_page = 20
User.limit(per_page).offset((page - 1) * per_page)

# Get only the first record
User.limit(1).first

# Top N records
User.order(points: :desc).limit(10)  # Top 10 by points
```

### `select`

Specify which columns to retrieve from the database.

```crystal
# Select specific columns
User.select(:id, :name, :email)

# Using array syntax
User.select([:id, :name, :email])

# With hash syntax for table specification
User.join(Post).select(users: [:name, :email], posts: [:title])

# Using block syntax for complex selections
User.select { [id, name, email] }

# With aliases
User.select { [id.as("user_id"), name.as("user_name")] }

# Aggregate selections
User.select { [role, count(id).as("user_count")] }
```

### `group` and `group_by`

Group records by one or more columns, often used with aggregate functions.

```crystal
# Group by single column
User.group(:role)
User.group_by(:role)  # Alias for group

# Multiple columns
User.group(:role, :status)
User.group_by(:role, :department)

# With aggregates
User.group(:role).select { [role, count(id).as("total")] }

# Complex grouping with having
User.group(:role)
    .select { [role, count(id).as("total"), avg(age).as("avg_age")] }
    .having { count(id) > 5 }
```

### `having`

Add conditions to grouped records, typically used with `group_by`.

```crystal
# Basic having with aggregates
User.group(:role).having { count(id) > 5 }

# Multiple having conditions
User.group(:department)
    .having { count(id) > 10 }
    .having { avg(salary) > 50000 }

# Complex having conditions
User.group(:role)
    .having { (count(id) > 5) & (avg(age) > 25) }

# Having with different aggregates
Post.group(:user_id)
    .having { (count(id) >= 3) & (sum(view_count) > 1000) }
```

### `join`, `left`, `right`

Perform SQL joins between tables. CQL supports various join types and provides a type-safe way to specify join conditions.

```crystal
# Simple inner join (automatic foreign key detection)
User.join(:posts)

# Explicit join with conditions
User.join(:posts) { users.id == posts.user_id }

# Multiple joins
User.join(:posts)
    .join(:comments) { posts.id == comments.post_id }

# Left joins (includes records without associations)
User.left(:posts)  # All users, even those without posts

# Right joins
User.right(:posts)  # All posts, even orphaned ones

# Join with table aliases
User.join(posts: :p) { users.id == p.user_id }

# Complex join conditions
User.join(:posts) { (users.id == posts.user_id) & (posts.published == true) }

# Self joins
User.from(users: :u1)
    .join({users: :u2}) { u1.manager_id == u2.id }

# Multiple tables with aliases
User.join(posts: :p, comments: :c) {
  (users.id == p.user_id) & (p.id == c.post_id)
}
```

### `distinct`

Remove duplicate records from the result set.

```crystal
# Select distinct records
User.distinct

# Distinct with specific columns
User.select(:role).distinct

# Distinct with joins to avoid duplicates
User.join(:posts).select(:id, :name).distinct

# Useful for unique values
unique_roles = User.select(:role).distinct.pluck(:role)
```

### `unscope`

Remove specific scopes from the query.

```crystal
# Remove where conditions
User.where(active: true).unscope(:where)

# Remove ordering
User.order(:name).unscope(:order)

# Remove multiple scopes
User.where(active: true)
    .order(:name)
    .limit(10)
    .unscope(:where, :order, :limit)

# Useful for modifying existing scopes
base_query = User.where(active: true).order(:name)
all_users = base_query.unscope(:where)  # Remove active filter
```

---

## Finding Records

### `find` and `find!`

Find a record by its primary key.

```crystal
# Find user by ID (returns nil if not found)
user = User.find(1)

# Find user by ID (raises error if not found)
user = User.find!(1)

# Safe find that returns nil
user = User.find?(1)  # Same as find, but more explicit

# Find with additional conditions
active_user = User.where(active: true).find(1)

# Find multiple IDs
users = [1, 2, 3].map { |id| User.find(id) }.compact
```

### `find_by` and `find_by!`

Find a record by attributes.

```crystal
# Find by single attribute
user = User.find_by(email: "alice@example.com")

# Find by multiple attributes
user = User.find_by(email: "alice@example.com", active: true)

# Find by hash syntax
user = User.find_by(role: "admin", department: "engineering")

# Find by with error if not found
user = User.find_by!(email: "alice@example.com")

# Find by on query chains
recent_admin = User.where { created_at > 1.week.ago }
                  .find_by(role: "admin")
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

# Get all users with their posts (with joins)
users_with_posts = User.join(:posts)
                      .select(users: [:id, :name], posts: [:title])
                      .all

# With type specification
users = User.where(active: true).all(User)
```

### `first`, `first!`, `last`, `last!`

Returns the first or last record matching the query.

```crystal
# Get the first user (returns nil if none found)
first_user = User.first

# Get the first user (raises error if none found)
first_user = User.first!

# Get the last user (based on ordering)
last_user = User.order(:created_at).last

# Get the last user (raises error if none found)
last_user = User.order(:created_at).last!

# First with conditions
oldest_active = User.where(active: true)
                   .order(:created_at)
                   .first

# Most recent post
latest_post = Post.order(created_at: :desc).first
```

### `count`

Returns the number of records matching the query.

```crystal
# Count all users
total_users = User.count

# Count with conditions
active_count = User.where(active: true).count

# Count specific column
non_null_emails = User.count(:email)

# Count with joins
users_with_posts = User.join(:posts).count

# Count with grouping
role_counts = User.group(:role)
                 .select { [role, count(id).as("count")] }
                 .all
```

### `size`

Alias for count - returns the number of records.

```crystal
# Same as count
User.size
User.where(active: true).size

# Useful for checking collection size
users = User.where(role: "admin")
puts "Found #{users.size} administrators"
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

# Exists with conditions
User.exists?(role: "admin")
User.exists?(active: true, role: "moderator")

# More efficient than count > 0
if User.where(active: true).exists?
  # More efficient than User.where(active: true).count > 0
end
```

### `any?` and `many?`

Check existence and quantity.

```crystal
# Check if any records exist (alias for exists?)
User.any?

# Check if more than one record exists
User.many?

# With conditions
User.where(active: true).any?
User.where(role: "admin").many?

# Useful for conditional logic
if User.where(role: "admin").many?
  puts "Multiple administrators found"
elsif User.where(role: "admin").any?
  puts "Single administrator found"
else
  puts "No administrators found"
end
```

### `empty?`

Checks if no records match the query.

```crystal
# Check if no users exist
User.empty?

# Check if no active users exist
User.where(active: true).empty?

# Opposite of exists?
!User.exists? == User.empty?  # true
```

### `pluck`

Returns an array of values for the specified columns.

```crystal
# Get all user names
names = User.pluck(:name)
# => ["Alice", "Bob", "Charlie"]

# Get multiple columns
name_emails = User.pluck(:name, :email)
# => [["Alice", "alice@example.com"], ["Bob", "bob@example.com"]]

# With conditions
active_names = User.where(active: true).pluck(:name)

# Get IDs efficiently
user_ids = User.where(role: "admin").pluck(:id)

# With type specification
ages = User.pluck(:age, as: Int32)

# Pluck from joins
titles = User.join(:posts)
            .where(users: {active: true})
            .pluck(:"posts.title")
```

### `pick`

Extract a single column value from the first matching record.

```crystal
# Get the name of the first user
first_name = User.pick(:name)

# Get email of first admin
admin_email = User.where(role: "admin").pick(:email)

# Pick with ordering
latest_user_name = User.order(created_at: :desc).pick(:name)

# Pick with type specification
latest_user_age = User.order(created_at: :desc).pick(:age, as: Int32)

# Returns nil if no records found
name = User.where(active: false).pick(:name)  # => nil
```

### `ids`

Get array of primary key values.

```crystal
# Get all user IDs
user_ids = User.ids
# => [1, 2, 3, 4, 5]

# Get IDs with conditions
active_ids = User.where(active: true).ids

# Get IDs with ordering
recent_ids = User.order(created_at: :desc).limit(10).ids

# With type specification
user_ids = User.ids(as: Int64)

# Useful for bulk operations
admin_ids = User.where(role: "admin").ids
admin_ids.each do |id|
  # Process each admin ID
end
```

### Aggregate Functions

Calculate statistics using built-in aggregate functions.

```crystal
# Sum of all ages
total_age = User.sum(:age)

# Average age
avg_age = User.average(:age)
avg_age = User.avg(:age)  # Alias

# Find minimum and maximum ages
min_age = User.minimum(:age)
max_age = User.maximum(:age)
min_age = User.min(:age)  # Alias
max_age = User.max(:age)  # Alias

# With conditions
active_avg_age = User.where(active: true).average(:age)

# Multiple aggregates in one query
stats = User.select {
  [
    count(id).as("total_users"),
    avg(age).as("average_age"),
    min(age).as("youngest"),
    max(age).as("oldest"),
    sum(points).as("total_points")
  ]
}.first

# Grouped aggregates
role_stats = User.group(:role)
                .select {
                  [
                    role,
                    count(id).as("count"),
                    avg(age).as("avg_age")
                  ]
                }.all
```

---

## Batch Processing

Process large datasets efficiently using batch methods.

### `find_each`

Process records one at a time in batches.

```crystal
# Process all users in batches of 1000
User.find_each(batch_size: 1000) do |user|
  # Process each user
  puts "Processing user: #{user.name}"
  user.update_statistics
end

# With conditions
User.where(active: true).find_each do |user|
  user.send_newsletter
end

# Custom batch size
User.find_each(batch_size: 500) do |user|
  # Smaller batches for memory efficiency
  process_user_data(user)
end

# With ordering (processes in order)
User.order(:created_at).find_each do |user|
  migrate_user_data(user)
end
```

### `find_in_batches`

Process records in batches.

```crystal
# Process users in batches
User.find_in_batches(batch_size: 1000) do |users|
  # Process batch of users
  puts "Processing batch of #{users.size} users"

  # Bulk operations are more efficient
  UserService.bulk_update(users)
end

# With conditions
User.where(created_at > 1.year.ago)
    .find_in_batches(batch_size: 500) do |users|

  # Export user data
  CSV.export(users)
end

# Memory-efficient large data processing
User.find_in_batches do |users|
  users.each do |user|
    # Process individual user within batch
    generate_report(user)
  end

  # Clear any caches after each batch
  cleanup_memory
end
```

---

## Query Inspection and Debugging

### `to_sql`

Get the generated SQL for debugging.

```crystal
# View generated SQL
query = User.where(active: true).order(:name)
puts query.to_sql
# => "SELECT * FROM users WHERE active = ? ORDER BY name ASC"

# Complex query inspection
complex_query = User.join(:posts)
                   .where(users: {active: true})
                   .where(posts: {published: true})
                   .group(:users.id)
                   .having { count(posts.id) > 5 }

sql, params = complex_query.to_sql_with_params
puts "SQL: #{sql}"
puts "Params: #{params.inspect}"
```

### `none`

Create a query that returns no results (useful for conditional building).

```crystal
# Start with empty result set
query = User.none

# Conditionally add conditions
if params["filter"] == "active"
  query = User.where(active: true)
end

if params["role"]
  query = query.where(role: params["role"])
end

# If no conditions were added, returns empty result set
results = query.all

# Useful for security - default to no access
def accessible_posts(user)
  return Post.none unless user

  case user.role
  when "admin"
    Post.all
  when "author"
    Post.where(author_id: user.id)
  else
    Post.none
  end
end
```

---

## Eager Loading with Preload

Eager loading allows you to load associated records in batch queries, avoiding the N+1 query problem. CQL provides the `preload` method for efficient association loading.

### Basic Preloading

```crystal
# Preload a single association
users = User.preload(:posts).all
users.each do |user|
  # posts are already loaded - no additional query
  puts "#{user.name} has #{user.posts.size} posts"
end

# Preload multiple associations
users = User.preload(:posts, :comments).all
users.each do |user|
  puts "#{user.name}: #{user.posts.size} posts, #{user.comments.size} comments"
end
```

### Chaining with Where

Preload works seamlessly with other query methods:

```crystal
# Filter users then preload their posts
active_users = User.where(active: true)
                   .preload(:posts)
                   .order(:name)
                   .all

# Only 2 queries total:
# 1. SELECT * FROM users WHERE active = true ORDER BY name
# 2. SELECT * FROM posts WHERE user_id IN (...)
```

### How Preload Works

Unlike JOIN-based eager loading, `preload` uses separate queries:

1. First query fetches the primary records
2. Subsequent queries fetch associated records using `IN` clauses
3. Records are matched in memory and associations are populated

This approach:

- Avoids cartesian product issues with multiple has_many associations
- Keeps queries simple and indexable
- Works well with pagination

### Preload vs Join

| Aspect                   | `preload`                    | `join`                          |
|--------------------------|------------------------------|---------------------------------|
| Query count              | N+1 reduced to 2 queries     | 1 query                         |
| Cartesian product        | No                           | Yes (with multiple has_many)    |
| Filtering on association | No                           | Yes                             |
| Pagination               | Works correctly              | May return duplicates           |
| Best for                 | Loading data to display      | Filtering by association        |

```crystal
# Use preload when you need the associated data
users = User.preload(:posts).all

# Use join when filtering by association
users_with_recent_posts = User.join(:posts)
                              .where("posts.created_at > ?", 1.week.ago)
                              .distinct
                              .all
```

### Performance Considerations

```crystal
# Preload only what you need
users = User.preload(:posts).all  # Good - loads posts in one query

# Avoid preloading unused associations
users = User.preload(:posts, :comments, :profile).all  # Wasteful if you only use posts

# Combine with select for optimal performance
users = User.select(:id, :name)
            .preload(:posts)
            .where(active: true)
            .all
```

---

## Advanced Query Composition

CQL's query interface allows you to build complex queries by combining multiple query methods. This section demonstrates common patterns and best practices for composing sophisticated queries.

### Advanced Filtering

Combine multiple conditions using logical operators and complex expressions.

```crystal
# Complex where conditions with proper grouping
User.where { (age >= 18) & (active == true) }
    .where { (name.like("A%")) | (email.like("%@gmail.com")) }

# Nested logical conditions
User.where {
  (role == "admin") & (
    (status == "active") | (status == "pending")
  )
}

# Range and comparison operations
User.where { age.between(25, 65) }
    .where { created_at > 1.year.ago }
    .where { login_count >= 5 }

# Complex IN conditions
User.where { role.in(["admin", "moderator", "editor"]) }
    .where { department.not_in(["archived", "deleted"]) }

# Combining different condition types
search_query = "john"
User.where { (name.like("%#{search_query}%")) | (email.like("%#{search_query}%")) }
    .where(active: true)
    .where { created_at > 1.month.ago }
```

### Joins with Complex Conditions

Combine joins with filtering and ordering.

```crystal
# Join with filtering on both tables
User.join(:posts) { users.id == posts.user_id }
    .where { (users.active == true) & (posts.published == true) }
    .order { [users.name, posts.created_at.desc] }

# Multiple joins with conditions
User.join(:posts) { users.id == posts.user_id }
    .join(:comments) { posts.id == comments.post_id }
    .where { comments.created_at > 1.week.ago }
    .select {
      [
        users.id,
        users.name,
        posts.title,
        count(comments.id).as("comment_count")
      ]
    }
    .group { [users.id, posts.id] }

# Left joins to include records without associations
User.left(:posts)
    .select {
      [
        users.*,
        count(posts.id).as("post_count")
      ]
    }
    .group { users.id }
    .having { count(posts.id) >= 0 }  # Include users with 0 posts
```

### Aggregations with Grouping

Combine grouping with aggregations and having clauses.

```crystal
# User statistics by role
User.group(:role)
    .select {
      [
        role,
        count(id).as("total"),
        avg(age).as("avg_age"),
        min(age).as("min_age"),
        max(age).as("max_age")
      ]
    }
    .having { count(id) > 5 }
    .order { count(id).desc }

# Complex grouped statistics
User.join(:posts) { users.id == posts.user_id }
    .group { [users.id, users.name, users.role] }
    .select {
      [
        users.name,
        users.role,
        count(posts.id).as("post_count"),
        avg(posts.view_count).as("avg_views"),
        sum(posts.like_count).as("total_likes")
      ]
    }
    .having { count(posts.id) >= 3 }
    .order { sum(posts.like_count).desc }

# Time-based grouping (database specific)
Post.group { date_trunc("month", created_at) }
    .select {
      [
        date_trunc("month", created_at).as("month"),
        count(id).as("posts_count"),
        count(distinct(:user_id)).as("unique_authors")
      ]
    }
    .order { date_trunc("month", created_at) }
```

### Subqueries and Complex Filtering

Use subqueries for advanced filtering and data retrieval.

```crystal
# Users with more than 5 posts using subquery
prolific_users = User.where {
  id.in(
    Post.select(:user_id)
        .group(:user_id)
        .having { count(id) > 5 }
  )
}

# Users with recent activity using EXISTS
active_users = User.where {
  exists(
    Post.select(:id)
        .where { posts.user_id == users.id }
        .where { posts.created_at > 1.week.ago }
  )
}

# Users without any posts using NOT EXISTS
users_without_posts = User.where {
  not_exists(
    Post.select(:id)
        .where { posts.user_id == users.id }
  )
}

# Complex subquery with multiple conditions
top_contributors = User.where {
  id.in(
    Post.select(:user_id)
        .where { (published == true) & (created_at > 3.months.ago) }
        .group(:user_id)
        .having { (count(id) >= 5) & (sum(view_count) > 1000) }
  )
}
```

### Query Scopes and Reusable Methods

Define reusable query scopes for common query patterns.

```crystal
class User
  include CQL::ActiveRecord::Model(Int32)

  # Simple scopes
  def self.active
    where(active: true)
  end

  def self.admins
    where(role: "admin")
  end

  def self.recently_created(days = 7)
    where { created_at > days.days.ago }
  end

  # Complex scopes with joins
  def self.with_posts
    join(:posts) { users.id == posts.user_id }
  end

  def self.with_recent_posts(days = 7)
    join(:posts) { users.id == posts.user_id }
      .where { posts.created_at > days.days.ago }
  end

  # Parameterized scopes
  def self.by_role(role)
    where(role: role)
  end

  def self.search(query)
    return none if query.blank?

    where {
      (name.like("%#{query}%")) |
      (email.like("%#{query}%"))
    }
  end

  # Aggregate scopes
  def self.with_post_counts
    left(:posts)
      .group { users.id }
      .select {
        [
          users.*,
          count(posts.id).as("post_count")
        ]
      }
  end
end

# Using scopes
active_admins = User.active.admins
recent_contributors = User.recently_created(30)
                         .with_recent_posts(7)
                         .distinct

# Chaining scopes
User.active
    .by_role("editor")
    .search("john")
    .with_posts
    .order(:name)
```

### Conditional Query Building

Build queries dynamically based on conditions.

```crystal
def search_users(params)
  query = User.query

  # Apply filters conditionally
  if params["name"]?
    query = query.where { name.like("%#{params["name"]}%") }
  end

  if params["email"]?
    query = query.where { email.like("%#{params["email"]}%") }
  end

  if params["role"]?
    query = query.where(role: params["role"])
  end

  if params["active"]?
    query = query.where(active: params["active"] == "true")
  end

  if params["min_age"]?
    query = query.where { age >= params["min_age"].to_i }
  end

  if params["max_age"]?
    query = query.where { age <= params["max_age"].to_i }
  end

  # Apply sorting
  sort_by = params["sort"]? || "name"
  sort_dir = params["dir"]? == "desc" ? :desc : :asc
  query = query.order(sort_by => sort_dir)

  # Apply pagination
  if params["page"]? && params["per_page"]?
    page = params["page"].to_i
    per_page = params["per_page"].to_i
    query = query.limit(per_page).offset((page - 1) * per_page)
  end

  query.all(User)
end

# Usage
users = search_users({
  "name" => "john",
  "role" => "admin",
  "active" => "true",
  "sort" => "created_at",
  "dir" => "desc",
  "page" => "1",
  "per_page" => "20"
})
```

---

## Performance Optimization

### Efficient Querying

```crystal
# 1. Select only needed columns
User.select(:id, :name, :email)
    .where(active: true)
    .all(User)

# 2. Use exists? instead of count > 0
if User.where(role: "admin").exists?
  # More efficient than count > 0
end

# 3. Use batch processing for large datasets
User.find_each(batch_size: 1000) do |user|
  process_user(user)
end

# 4. Use pluck for single column values
user_names = User.where(active: true).pluck(:name)
# More efficient than User.where(active: true).all.map(&.name)

# 5. Use includes/joins to avoid N+1 queries
# Instead of:
users = User.all
users.each { |user| puts user.posts.count }  # N+1 queries

# Use:
User.left(:posts)
    .group { users.id }
    .select { [users.*, count(posts.id).as("post_count")] }
    .all

# 6. Use proper indexing strategy
User.where(email: "user@example.com")  # Ensure email is indexed
    .where(active: true)                # Index on active if frequently queried
```

### Query Analysis and Debugging

```crystal
# Analyze query performance
def analyze_query(query_builder)
  sql, params = query_builder.to_sql_with_params

  puts "=== Query Analysis ==="
  puts "SQL: #{sql}"
  puts "Parameters: #{params.inspect}"
  puts "Length: #{sql.size} characters"
  puts "Joins: #{sql.scan(/JOIN/i).size}"
  puts "Conditions: #{sql.scan(/WHERE|AND|OR/i).size}"
  puts "====================="
end

# Usage
query = User.join(:posts)
           .where(users: {active: true})
           .where(posts: {published: true})
           .group { users.id }

analyze_query(query)

# Measure execution time
def time_query(&block)
  start_time = Time.monotonic
  result = yield
  duration = Time.monotonic - start_time

  puts "Query executed in #{duration.total_milliseconds}ms"
  result
end

# Usage
users = time_query do
  User.join(:posts)
      .where(users: {active: true})
      .limit(100)
      .all(User)
end
```

---

## Best Practices Summary

### Query Construction

- Use meaningful method names and extract complex queries into scopes
- Chain methods logically - filters first, then joins, then ordering
- Use block syntax for complex conditions to improve readability
- Leverage automatic relationship detection for simpler joins

### Performance

- Always use `.select` to limit columns when you don't need all data
- Use `.exists?` instead of `.count > 0` for existence checks
- Use batch processing (`.find_each`, `.find_in_batches`) for large datasets
- Use `.pluck` for extracting single column values efficiently

### Maintainability

- Define reusable scopes for common query patterns
- Use conditional query building for dynamic filters
- Extract complex queries into well-named methods
- Document complex business logic in query methods

### Security

- Always use parameterized queries (CQL handles this automatically)
- Validate user input before using in dynamic query construction
- Use `.none` as a safe default for access control
- Be careful with user-provided LIKE patterns

### Testing

- Test query scopes in isolation
- Verify that complex queries return expected results
- Test edge cases (empty results, large datasets)
- Use `.to_sql` to verify generated SQL in tests

---

## Related Guides

For more information on related query topics:

- [Complex Queries](complex-queries.md) - Advanced query patterns and techniques
- [CRUD Operations](crud-operations.md) - Basic create, read, update, delete operations
- [Relations](relations/README.md) - Understanding model relationships and associations
- [Scopes](scopes.md) - Reusable query methods and named scopes
- [Transactions](transactions.md) - Managing database transactions
- [Validations](validations.md) - Data validation and integrity
