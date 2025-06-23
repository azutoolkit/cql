# Complex Queries in CQL

CQL provides a powerful, type-safe query builder that allows you to compose sophisticated SQL queries using idiomatic Crystal code. This guide demonstrates how to build complex queries using `Model.query` and the `CQL::Query` interface.

---

## Join Types and Strategies

### Implicit vs Explicit Joins

CQL supports both implicit and explicit join syntax for different use cases:

```crystal
# Implicit JOIN - CQL automatically detects relationships based on foreign keys
users_with_posts = User.query.joins(:posts).all(User)
# Generates: SELECT * FROM users INNER JOIN posts ON users.id = posts.user_id

# Explicit JOIN - Full control over join conditions
users_with_posts = User.query.join(Post) { users.id == posts.user_id }
                             .all(User)
```

### Inner Joins (Default)

Inner joins return only records that have matching records in both tables:

```crystal
# Automatic inner join based on foreign key relationship
active_users_with_posts = User.query.joins(:posts)
                                   .where { users.active == true }
                                   .all(User)

# Explicit inner join with custom conditions
users_with_recent_posts = User.query.join(Post) { users.id == posts.user_id }
                                   .where { posts.created_at > 1.month.ago }
                                   .all(User)

# Multiple inner joins
User.query.joins(posts: :comments)
         .where { comments.approved == true }
         .all(User)
```

### Left Joins

Left joins return all records from the left table and matching records from the right table:

```crystal
# All users including those without posts
all_users_with_optional_posts = User.query.left_joins(:posts).all(User)

# Explicit left join with conditions
User.query.left_join(Post) { users.id == posts.user_id }
         .where { (posts.id.is_null) | (posts.published == true) }
         .all(User)

# Find users who have no posts
users_without_posts = User.query.left_joins(:posts)
                                .where { posts.id.is_null }
                                .all(User)
```

### Right Joins

Right joins return all records from the right table and matching records from the left table:

```crystal
# All posts including orphaned ones (if any)
all_posts_with_optional_users = User.query.right_joins(:posts).all(User)

# Explicit right join
Post.query.right_join(User) { posts.user_id == users.id }
         .where { users.active == true }
         .all(Post)
```

### Self Joins

Join a table to itself for hierarchical or comparative queries:

```crystal
# Find users and their managers (assuming users table has manager_id)
User.query.from(users: :u)
         .join({users: :m}) { u.manager_id == m.id }
         .select { [u.name.as("employee"), m.name.as("manager")] }
         .all(User)

# Find users in the same city
User.query.from(users: :u1)
         .join({users: :u2}) { (u1.city == u2.city) & (u1.id != u2.id) }
         .select { [u1.name, u2.name, u1.city] }
         .all(User)
```

### Cross Joins

Generate Cartesian product of two tables (use with caution):

```crystal
# Cross join using explicit FROM syntax
User.query.from(users: :u, posts: :p)
         .where { u.active == true }
         .select { [u.name, p.title] }
         .all(User)
```

---

## Advanced Filtering

Combine multiple conditions, logical operators, and expressions:

```crystal
# Multiple AND/OR conditions
users = User.query.where { (age >= 18) & (active == true) }
                 .where { (name.like("A%")) | (email.like("%@gmail.com")) }
                 .all(User)

# Nested conditions with parentheses
admins = User.query.where { (role == "admin") & ((status == "active") | (status == "pending")) }
                   .all(User)

# IN and NOT IN operations
moderators = User.query.where { role.in(["admin", "moderator"]) }
                       .all(User)

excluded = User.query.where { id.not_in([1, 2, 3]) }
                     .all(User)

# NULL checks
users_with_profiles = User.query.where { profile_id.is_not_null }
                                .all(User)

# Range and comparison operations
adults = User.query.where { age.between(18, 65) }
                  .all(User)

recent_users = User.query.where { created_at > 1.week.ago }
                        .all(User)
```

---

## Ordering and Sorting

### Basic Ordering

```crystal
# Single column ascending (default)
users = User.query.order(:name).all(User)

# Single column descending
users = User.query.order(:created_at, :desc).all(User)

# Multiple columns
users = User.query.order(:role)
                 .order(:name)
                 .all(User)
```

### Advanced Ordering

```crystal
# Order by calculated expressions
users = User.query.order { age * 2 }
                 .all(User)

# Order by joined table columns
users = User.query.joins(:posts)
                 .order { posts.created_at }
                 .desc
                 .all(User)

# Mixed ordering directions
users = User.query.order(:role)           # ASC
                 .order(:created_at, :desc) # DESC
                 .order(:name)              # ASC
                 .all(User)

# Reverse current ordering
users = User.query.order(:name)
                 .reverse_order  # Changes to DESC
                 .all(User)
```

---

## Pagination and Limiting

### Basic Pagination

```crystal
# LIMIT and OFFSET
page_size = 20
page_number = 2
users = User.query.limit(page_size)
                 .offset((page_number - 1) * page_size)
                 .all(User)

# First N records
top_users = User.query.order(:points, :desc)
                     .limit(10)
                     .all(User)
```

### Cursor-Based Pagination

```crystal
# More efficient for large datasets
last_id = 1000
users = User.query.where { id > last_id }
                 .order(:id)
                 .limit(20)
                 .all(User)
```

---

## Grouping, Aggregation, and Having

Use grouping and aggregate functions for reporting and analytics:

```crystal
# Group by and aggregate
role_stats = User.query.select { [role, CQL.count(id).as("total")] }
                      .group_by(:role)
                      .all(User)

# Group by multiple columns
stats = Post.query.select { [user_id, status, CQL.count(id).as("post_count")] }
                  .group_by(:user_id, :status)
                  .all(Post)

# Having conditions on aggregates
active_users = User.query.select { [user_id, CQL.count(posts.id).as("post_count")] }
                        .joins(:posts)
                        .group_by(:user_id)
                        .having { CQL.count(posts.id) > 5 }
                        .all(User)

# Multiple aggregates
summary = Order.query.select { [
  CQL.sum(:total).as("total_sum"),
  CQL.avg(:total).as("avg_total"),
  CQL.min(:total).as("min_total"),
  CQL.max(:total).as("max_total"),
  CQL.count(:id).as("order_count")
] }.where { status == "paid" }
  .all(Order)
```

---

## DISTINCT Queries

Remove duplicate results from your queries:

```crystal
# Select distinct values
unique_cities = User.query.select(:city)
                         .distinct
                         .all(User)

# Distinct with multiple columns
unique_combinations = User.query.select(:role, :department)
                                .distinct
                                .all(User)

# Distinct with joins
active_post_authors = User.query.joins(:posts)
                               .where { posts.published == true }
                               .select(:id, :name)
                               .distinct
                               .all(User)
```

---

## Subqueries

Use subqueries for advanced filtering and data retrieval:

```crystal
# EXISTS subqueries
users_with_posts = User.query.where {
  CQL.exists(
    Post.query.select(:id)
        .where { posts.user_id == users.id }
        .where { posts.published == true }
  )
}.all(User)

# IN subqueries
prolific_users = User.query.where { id.in(
  Post.query.select(:user_id)
      .group_by(:user_id)
      .having { CQL.count(id) > 5 }
) }.all(User)

# Correlated subqueries with OR conditions
users_with_recent_activity = User.query.where {
  id.in(Post.query.select(:user_id).where { created_at > 1.week.ago }) |
  id.in(Comment.query.select(:user_id).where { created_at > 1.week.ago })
}.all(User)

# Scalar subqueries
users_with_post_count = User.query.select { [
  users.*,
  Post.query.select { CQL.count(:id) }
      .where { posts.user_id == users.id }
      .as("post_count")
] }.all(User)
```

---

## Raw SQL Integration

### Inspecting Generated SQL

```crystal
# View the generated SQL and parameters
query = User.query.joins(:posts)
              .where { users.active == true }
              .where { posts.published == true }
              .order(:users.name)

sql, params = query.to_sql
puts "SQL: #{sql}"
puts "Params: #{params.inspect}"
# SQL: SELECT * FROM users INNER JOIN posts ON users.id = posts.user_id WHERE (users.active = ?) AND (posts.published = ?) ORDER BY users.name ASC
# Params: [true, true]
```

### Executing Raw SQL

```crystal
# Execute raw SQL through the schema
results = UserDB.exec("SELECT COUNT(*) as total FROM users WHERE active = ?", [true])

# Complex raw queries when query builder limitations are reached
sql = <<-SQL
  SELECT u.*,
         COUNT(p.id) as post_count,
         AVG(p.view_count) as avg_views
  FROM users u
  LEFT JOIN posts p ON u.id = p.user_id
  WHERE u.active = true
  GROUP BY u.id, u.name, u.email
  HAVING COUNT(p.id) > 5
  ORDER BY post_count DESC, u.name
SQL

results = UserDB.exec(sql)
```

---

## N+1 Query Prevention

One of the most common performance issues in ORMs is the N+1 query problem, where loading a collection of records results in 1 query for the main records plus N additional queries for each associated record. CQL provides several mechanisms to prevent this issue.

### Understanding the N+1 Problem

```crystal
# ❌ N+1 Query Problem - Inefficient
users = User.query.all                    # 1 query: SELECT * FROM users
users.each do |user|
  puts user.posts.size                    # N queries: SELECT * FROM posts WHERE user_id = ?
end
# Total: 1 + N queries (where N = number of users)
```

### CQL's JOIN-Based Approach

CQL automatically uses efficient JOIN-based queries instead of separate queries for each association:

#### **Has Many Associations**

```crystal
# ✅ Efficient: Single query with WHERE clause
user = User.find(1)
posts = user.posts.all
# Generates: SELECT * FROM posts WHERE posts.user_id = 1
```

#### **Many-to-Many Associations**

```crystal
# ✅ Efficient: Single query with JOIN
movie = Movie.find(1)
actors = movie.actors.all
# Generates: SELECT actors.* FROM actors
#           INNER JOIN movies_actors ON actors.id = movies_actors.actor_id
#           WHERE movies_actors.movie_id = 1
```

### Lazy Loading with Caching

CQL implements intelligent lazy loading that prevents duplicate queries:

```crystal
user = User.find(1)

# First access - executes query and caches results
posts = user.posts.all                  # Query executed
puts posts.size                         # Uses cached data

# Subsequent access - uses cached data
user.posts.each { |post| puts post.title }  # No additional query
```

### Efficient Association Operations

CQL provides methods to perform common operations without loading full records:

#### **Count Without Loading**

```crystal
# ✅ Efficient: COUNT query without loading records
user = User.find(1)
post_count = user.posts_count
# Generates: SELECT COUNT(*) FROM posts WHERE posts.user_id = 1

# Many-to-many count
movie = Movie.find(1)
actor_count = movie.actors_count
# Generates: SELECT COUNT(*) FROM movies_actors WHERE movies_actors.movie_id = 1
```

#### **Existence Checks Without Loading**

```crystal
# ✅ Efficient: EXISTS query
user = User.find(1)
has_posts = user.posts_any?
# Generates: SELECT 1 FROM posts WHERE posts.user_id = 1 LIMIT 1

# Check if specific record exists in association
actor = Actor.find(1)
movie = Movie.find(1)
is_associated = movie.actors_include?(actor)
# Generates: SELECT 1 FROM movies_actors
#           WHERE movies_actors.movie_id = 1 AND movies_actors.actor_id = 1 LIMIT 1
```

#### **ID-Only Operations**

```crystal
# ✅ Efficient: Get IDs without loading full records
user = User.find(1)
post_ids = user.posts_ids
# Generates: SELECT posts.id FROM posts WHERE posts.user_id = 1

# Set associations by IDs (many-to-many)
movie = Movie.find(1)
movie.actors_ids = [1, 2, 3]  # Replaces current associations efficiently
```

### Query Optimization Strategies

#### **Batch Operations**

```crystal
# ✅ Efficient: Batch loading patterns
user_ids = [1, 2, 3, 4, 5]

# Load all posts for multiple users in one query
posts_by_user = Post.query.where(user_id: user_ids)
                          .group_by(&.user_id)

# Now access posts without additional queries
user_ids.each do |user_id|
  user_posts = posts_by_user[user_id]? || [] of Post
  puts "User #{user_id} has #{user_posts.size} posts"
end
```

#### **Strategic Use of Joins**

```crystal
# ✅ Efficient: Use joins for filtering and aggregation
users_with_post_counts = User.query
  .joins(:posts)
  .select("users.*, COUNT(posts.id) as post_count")
  .group_by("users.id")
  .all

# No N+1 problem - all data loaded in single query
users_with_post_counts.each do |user|
  puts "#{user.name} has #{user.post_count} posts"
end
```

### Performance Best Practices

```crystal
# 1. Use specific column selection instead of SELECT *
users = User.query.select(:id, :name, :email)
                 .where { active == true }
                 .all(User)

# 2. Use EXISTS instead of IN for large subqueries
users = User.query.where {
  CQL.exists(Post.query.where { posts.user_id == users.id })
}.all(User)

# 3. Use LIMIT to prevent accidentally loading large datasets
recent_users = User.query.order(:created_at, :desc)
                        .limit(100)
                        .all(User)

# 4. Use indexes effectively with proper WHERE clause ordering
users = User.query.where { email == "user@example.com" }  # Assuming email is indexed
                 .where { active == true }
                 .all(User)

# 5. ✅ Prefer efficient association methods over loading full collections
# Bad: Loads all posts just to count them
users = User.query.all
users.each { |user| puts user.posts.size }  # N+1 queries + memory overhead

# Good: Use count methods
users = User.query.all
users.each { |user| puts user.posts_count }  # N COUNT queries (still not ideal)

# Better: Use joins for aggregation
users_with_counts = User.query
  .left_joins(:posts)
  .select("users.*, COUNT(posts.id) as post_count")
  .group_by("users.id")
  .all
users_with_counts.each { |user| puts user.post_count }  # Single query
```

### Advanced N+1 Prevention Patterns

#### **Manual Preloading**

```crystal
# For complex scenarios, manually preload associations
def load_users_with_posts(user_ids)
  # Load users
  users = User.query.where(id: user_ids).all

  # Preload posts in batch
  posts_by_user = Post.query.where(user_id: user_ids)
                            .group_by(&.user_id)

  # Create a lookup structure
  users.each do |user|
    # Associate posts with users in memory
    user_posts = posts_by_user[user.id]? || [] of Post
    # Store in instance variable or similar mechanism
  end

  users
end
```

#### **Caching Association Counts**

```crystal
# Use database-level caching for frequently accessed counts
class User
  # Add posts_count column to users table
  property posts_count : Int32 = 0

  # Update count when posts are added/removed
  def update_posts_count!
    self.posts_count = posts.count
    save!
  end
end

# Now you can access post counts without queries
users = User.query.all
users.each { |user| puts user.posts_count }  # No additional queries
```

### Monitoring and Debugging

#### **Query Analysis**

```crystal
# Monitor query patterns to identify N+1 issues
def with_query_logging(&block)
  query_count = 0
  start_time = Time.utc

  # This would require database-level query logging
  # Implementation depends on your database adapter

  result = yield

  end_time = Time.utc
  puts "Executed #{query_count} queries in #{end_time - start_time} seconds"
  result
end

# Usage
with_query_logging do
  users = User.query.limit(10).all
  users.each { |user| puts user.posts_count }  # Monitor query count here
end
```

#### **Performance Testing**

```crystal
# Test different approaches to verify performance
def benchmark_association_access
  require "benchmark"

  user_ids = User.query.limit(100).ids

  Benchmark.ips do |x|
    x.report("N+1 pattern") do
      users = User.query.where(id: user_ids).all
      users.each { |user| user.posts.size }
    end

    x.report("Count method") do
      users = User.query.where(id: user_ids).all
      users.each { |user| user.posts_count }
    end

    x.report("JOIN aggregation") do
      User.query.where(id: user_ids)
               .joins(:posts)
               .select("users.*, COUNT(posts.id) as post_count")
               .group_by("users.id")
               .all
    end

    x.compare!
  end
end
```

---

## Query Optimization Tips

### Query Analysis

```crystal
# Analyze query performance by examining generated SQL
def analyze_query(query)
  sql, params = query.to_sql
  puts "=== Query Analysis ==="
  puts "SQL: #{sql}"
  puts "Parameters: #{params.inspect}"
  puts "Character length: #{sql.size}"
  puts "Join count: #{sql.scan(/JOIN/i).size}"
  puts "Where conditions: #{sql.scan(/WHERE|AND|OR/i).size}"
  puts "====================="
end

# Usage
query = User.query.joins(posts: :comments)
              .where { users.active == true }
              .where { posts.published == true }
              .where { comments.approved == true }

analyze_query(query)
```

---

## Advanced Query Patterns

### Conditional Queries

```crystal
def build_user_search(name_filter = nil, email_filter = nil, active_only = false)
  query = User.query

  if name_filter
    query = query.where { name.like("%#{name_filter}%") }
  end

  if email_filter
    query = query.where { email.like("%#{email_filter}%") }
  end

  if active_only
    query = query.where { active == true }
  end

  query.order(:name)
end

# Usage
users = build_user_search(name_filter: "John", active_only: true).all(User)
```

### Complex Aggregations

```crystal
# Monthly user registration statistics
monthly_stats = User.query.select { [
  CQL.date_trunc("month", created_at).as("month"),
  CQL.count(:id).as("registrations"),
  CQL.count(CQL.case {
    when(active == true) { id }
  }).as("active_users")
] }
.where { created_at > 1.year.ago }
.group_by { CQL.date_trunc("month", created_at) }
.order { CQL.date_trunc("month", created_at) }
.all(User)
```

### Window Functions (if supported by your database)

```crystal
# User ranking by posts within each role
ranked_users = User.query.select { [
  users.*,
  CQL.count(posts.id).as("post_count"),
  CQL.row_number.over(
    partition_by: :role,
    order_by: CQL.count(posts.id).desc
  ).as("rank_in_role")
] }
.left_join(Post) { users.id == posts.user_id }
.group_by(:users.id, :users.role)
.all(User)
```

---

## Best Practices Summary

### Query Construction

- Use table aliases for clarity in multi-join queries
- Use block syntax for complex conditions to improve readability
- Leverage automatic relationship detection for simpler joins
- Use explicit joins when you need custom conditions

### Performance

- Always use `.select` to limit columns and improve performance
- Use `.limit` and `.offset` for pagination
- Prefer EXISTS over IN for subqueries with large result sets
- Use proper indexing strategy for WHERE clause columns
- Leverage association count and existence methods to avoid N+1 queries
- Use JOIN-based aggregation instead of iterating over associations
- Monitor query patterns and optimize based on actual usage patterns

### Maintainability

- Use meaningful variable names and method extraction for complex queries
- Use `.to_sql` to inspect and verify generated SQL
- Test query performance with realistic data volumes
- Document complex business logic in query methods

### Security

- Always use parameterized queries (CQL handles this automatically)
- Validate user input before using in dynamic query construction
- Use proper escaping for LIKE patterns

---

## Related Guides

For more information on related query topics:

- [CRUD Operations](crud-operations.md) - Basic create, read, update, delete operations
- [Queryable](queryable.md) - Core querying interface and methods
- [Relations](relations/README.md) - Understanding model relationships and associations
- [Scopes](scopes.md) - Reusable query methods and named scopes
- [Transactions](transactions.md) - Managing database transactions
- [Validations](validations.md) - Data validation and integrity
