---
description: >-
  Master advanced querying techniques with CQL Query Builder - complex conditions, subqueries, dynamic queries, and more.
---

# Advanced Querying

This guide covers advanced querying techniques with CQL Query Builder, including complex conditions, subqueries, dynamic query building, and query composition patterns.

## Complex Where Conditions

### Block-based Filtering

CQL provides a powerful block-based interface for building complex conditions:

```crystal
# Complex AND/OR logic using table references
query.from(:users).where do
  users.active.eq(true) &
  (users.age.gt(18) | users.admin.eq(true)) &
  users.status.not_eq("banned")
end.all(User)
```

### Nested Conditions

```crystal
# Deeply nested conditions
query.from(:posts).where do
  posts.published.eq(true) &
  (posts.category.eq("tech") |
   (posts.category.eq("science") & posts.views.gt(1000)))
end.all(Post)
```

### Comparison Operators

```crystal
# All available comparison operators
query.from(:users).where do
  users.status.eq("active") &           # Equal
  users.role.not_eq("guest") &          # Not equal
  users.age.gt(18) &                    # Greater than
  users.score.gte(100) &                # Greater than or equal
  users.age.lt(65) &                    # Less than
  users.balance.lte(1000) &             # Less than or equal
  users.email.like("%@company.com") &   # LIKE pattern
  users.name.not_like("%test%") &       # NOT LIKE pattern
  users.role.in(["admin", "moderator"]) & # IN array
  users.status.not_in(["banned"]) &     # NOT IN array
  users.deleted_at.null &               # IS NULL
  users.email.not_null                  # IS NOT NULL
end.all(User)
```

### Range and Between Conditions

```crystal
# Range conditions
query.from(:users).where do
  users.age.between(18, 65) &
  users.created_at.between(1.month.ago, Time.utc)
end.all(User)

# Not between
query.from(:users).where do
  users.score.not_between(0, 100)
end.all(User)
```

## Array Conditions

CQL supports array values in WHERE clauses for IN conditions:

```crystal
# Single array condition
query.from(:users).where(role: ["admin", "moderator"]).all(User)

# Multiple array conditions
query.from(:users).where(
  age: [25, 30, 35],
  status: ["active", "pending"]
).all(User)

# Array conditions with other conditions
query.from(:users).where(
  age: [25, 30, 35],
  active: true
).all(User)

# Chained array conditions
query.from(:users)
     .where(age: [25, 30, 35])
     .where(status: ["active", "pending"])
     .all(User)

# Array conditions in block syntax
query.from(:users).where do
  users.age.in([25, 30, 35]) &
  users.status.in(["active", "pending"])
end.all(User)
```

## Subqueries

### EXISTS Subqueries

```crystal
# Find users who have posts
subquery = query.from(:posts).where { posts.user_id.eq(users.id) }
query.from(:users).where { users.id.exists?(subquery) }.all(User)

# Find users with no posts
subquery = query.from(:posts).where { posts.user_id.eq(users.id) }
query.from(:users).where { users.id.not_exists?(subquery) }.all(User)
```

### IN Subqueries

```crystal
# Find posts by users with high scores
subquery = query.from(:users)
                .select(:id)
                .where { users.score.gte(100) }
query.from(:posts).where { posts.user_id.in(subquery) }.all(Post)
```

### Scalar Subqueries

```crystal
# Select with subquery in column
subquery = query.from(:comments)
                .select(:count)
                .where { comments.post_id.eq(posts.id) }
query.from(:posts)
     .select(:title, :body, subquery.as(:comment_count))
     .all(Post)
```

## Dynamic Query Building

### Conditional Query Construction

```crystal
def build_user_query(active: Bool? = nil, role: String? = nil, min_age: Int32? = nil)
  base_query = query.from(:users)

  # Add conditions only if parameters are provided
  base_query = base_query.where(active: active) if active
  base_query = base_query.where(role: role) if role
  base_query = base_query.where { users.age.gte(min_age) } if min_age

  base_query
end

# Usage
active_admins = build_user_query(active: true, role: "admin").all(User)
adults = build_user_query(min_age: 18).all(User)
```

### Query Builder Pattern

```crystal
class UserQueryBuilder
  def initialize(@query : CQL::Query)
    @conditions = [] of String
    @params = {} of String => DB::Any
  end

  def active(active : Bool)
    @conditions << "active = :active"
    @params["active"] = active
    self
  end

  def role(role : String)
    @conditions << "role = :role"
    @params["role"] = role
    self
  end

  def age_range(min : Int32, max : Int32)
    @conditions << "age BETWEEN :min_age AND :max_age"
    @params["min_age"] = min
    @params["max_age"] = max
    self
  end

  def build
    where_clause = @conditions.join(" AND ")
    @query.from(:users).where(where_clause, @params)
  end
end

# Usage
builder = UserQueryBuilder.new(query)
users = builder.active(true)
               .role("admin")
               .age_range(18, 65)
               .build
               .all(User)
```

## Query Composition

### Merging Queries

```crystal
# Create base queries
active_users = query.from(:users).where(active: true)
admin_users = query.from(:users).where(role: "admin")

# Merge queries (UNION-like behavior)
combined_query = active_users.merge(admin_users)
users = combined_query.all(User)
```

### Query Inheritance

```crystal
# Base query with common conditions
def base_user_query
  query.from(:users)
       .where(active: true)
       .order(:name)
end

# Specialized queries
def admin_users_query
  base_user_query.where(role: "admin")
end

def recent_users_query
  base_user_query.where { users.created_at.gte(1.month.ago) }
end

# Usage
admins = admin_users_query.all(User)
recent = recent_users_query.all(User)
```

### Query Factories

```crystal
class QueryFactory
  def self.users_by_status(status : String)
    query.from(:users).where(status: status)
  end

  def self.posts_by_category(category : String)
    query.from(:posts).where(category: category)
  end

  def self.recent_content(days : Int32)
    query.from(:posts)
         .where { posts.created_at.gte(days.days.ago) }
         .order(:created_at, :desc)
  end
end

# Usage
active_users = QueryFactory.users_by_status("active").all(User)
tech_posts = QueryFactory.posts_by_category("tech").all(Post)
recent_posts = QueryFactory.recent_content(7).all(Post)
```

## Advanced Filtering Patterns

### Search with Multiple Fields

```crystal
def search_users(term : String)
  query.from(:users).where do
    users.name.like("%#{term}%") |
    users.email.like("%#{term}%") |
    users.bio.like("%#{term}%")
  end
end

# Usage
results = search_users("john").all(User)
```

### Date Range Filtering

```crystal
def filter_by_date_range(start_date : Time?, end_date : Time?)
  base_query = query.from(:posts)

  if start_date && end_date
    base_query = base_query.where { posts.created_at.between(start_date, end_date) }
  elsif start_date
    base_query = base_query.where { posts.created_at.gte(start_date) }
  elsif end_date
    base_query = base_query.where { posts.created_at.lte(end_date) }
  end

  base_query
end
```

### Complex Aggregation Filters

```crystal
# Find users with more than 5 posts
subquery = query.from(:posts)
                .select(:count)
                .where { posts.user_id.eq(users.id) }
query.from(:users).where { users.id.exists?(subquery) }.all(User)
```

## Active Record Advanced Methods

### Batch Processing

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

### Data Extraction

```crystal
# Extract single column values
names = User.pluck(:name, as: String)
ages = User.where(active: true).pluck(:age, as: Int32)

# Extract multiple column values
results = User.pluck(:name, :age, as: {String, Int32})

# Pick single value from first record
name = User.pick(:name)
age = User.where(active: true).pick(:age)

# Get array of primary keys
user_ids = User.ids
active_user_ids = User.where(active: true).ids
```

### Aggregations

```crystal
# Basic aggregations
total_users = User.count
total_age = User.sum(:age)
avg_age = User.average(:age)
min_age = User.minimum(:age)
max_age = User.maximum(:age)

# With conditions
active_count = User.where(active: true).count
active_avg_age = User.where(active: true).average(:age)

# Alias methods
User.min(:age)    # Same as minimum
User.max(:age)    # Same as maximum
User.avg(:age)    # Same as average
```

### Query Modifiers

```crystal
# Replace existing order
query = User.order(:name, :asc)
query = query.reorder(:age, :desc)  # Replaces name order with age

# Reverse order
query = User.order(:name, :asc).reverse_order

# Remove specific scopes
query = User.where(active: true).order(:name)
query = query.unscope(:where)  # Removes where condition
```

## Performance Optimization

### Query Analysis

```crystal
# Get the generated SQL for analysis
sql, params = query.from(:users)
                   .where(active: true)
                   .order(:name)
                   .to_sql

puts "Generated SQL: #{sql}"
puts "Parameters: #{params}"
```

### Query Caching

```crystal
# Enable query caching
User.query.cache(true)

# Build and execute query
users = User.where(active: true).all

# Subsequent identical queries will use cache
cached_users = User.where(active: true).all
```

### Batch Processing

```crystal
# Process large datasets in batches
def process_all_users(batch_size : Int32 = 1000)
  offset = 0

  loop do
    users = User.query
                .order(:id)
                .limit(batch_size)
                .offset(offset)
                .all

    break if users.empty?

    # Process batch
    users.each do |user|
      # Process user
    end

    offset += batch_size
  end
end
```

## Error Handling and Debugging

### Query Validation

```crystal
def safe_query_execution
  begin
    users = User.where(active: true).all
    return users
  rescue ex : CQL::Error
    puts "Query error: #{ex.message}"
    return [] of User
  end
end
```

### Query Logging

```crystal
# Log queries for debugging
def log_query(query : CQL::Query)
  sql, params = query.to_sql
  puts "Executing SQL: #{sql}"
  puts "With parameters: #{params}"
end

# Usage
user_query = User.where(active: true).query
log_query(user_query)
users = user_query.all
```

### Performance Monitoring

```crystal
def timed_query_execution
  start_time = Time.monotonic

  users = User.all

  end_time = Time.monotonic
  duration = end_time - start_time

  puts "Query executed in #{duration.total_milliseconds}ms"
  users
end
```

## Best Practices

### Query Organization

```crystal
# Organize complex queries into methods
class UserRepository
  def self.active_admins_with_posts
    query.from(:users).where do
      users.active.eq(true) &
      users.role.eq("admin") &
      users.id.exists? do |subquery|
        subquery.from(:posts).where { posts.user_id.eq(users.id) }
      end
    end
  end

  def self.recent_posts_by_user(user_id : Int64)
    query.from(:posts)
         .where(user_id: user_id)
         .order(:created_at, :desc)
         .limit(10)
  end
end
```

### Query Reusability

```crystal
# Create reusable query components
module QueryComponents
  def self.active_filter
    ->(query : CQL::Query) {
      query.where(active: true)
    }
  end

  def self.recent_filter(days : Int32)
    ->(query : CQL::Query) {
      query.where { users.created_at.gte(days.days.ago) }
    }
  end
end

# Usage
query = query.from(:users)
QueryComponents.active_filter.call(query)
QueryComponents.recent_filter(30).call(query)
users = query.all(User)
```

### Type Safety

```crystal
# Use typed parameters for better safety
def find_users_by_criteria(
  active : Bool? = nil,
  role : String? = nil,
  age_range : Range(Int32, Int32)? = nil
)
  base_query = query.from(:users)

  base_query = base_query.where(active: active) if active
  base_query = base_query.where(role: role) if role
  base_query = base_query.where { users.age.between(age_range.begin, age_range.end) } if age_range

  base_query
end
```

## Next Steps

- Explore [Joins and Relations](./joins-and-relations.md) for multi-table queries
- Learn about [Aggregations](./aggregations.md) for grouped data operations
- Check out [Query Execution](./query-execution.md) for execution strategies
- Review [Query Optimization](./query-optimization.md) for performance tuning
- Consult the [API Reference](../../api-reference/query-builder-api.md) for complete method documentation

Advanced querying techniques provide the flexibility to handle complex data scenarios while maintaining type safety and performance. These patterns help you build robust, maintainable database operations for sophisticated applications.
