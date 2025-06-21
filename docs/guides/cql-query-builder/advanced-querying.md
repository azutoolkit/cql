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
# Complex AND/OR logic
query.from(:users).where do
  active.eq(:, true) &
        .group do |g|
          g.gt(:age, 18)
            .or
            .eq(:admin, true)
        end
        .and
        .not_eq(:status, "banned")
end.all(User)
```

### Nested Conditions

```crystal
# Deeply nested conditions
query.from(:posts).where do |filter|
  filter.eq(:published, true)
        .and
        .group do |g|
          g.eq(:category, "tech")
            .or
            .group do |sub|
              sub.eq(:category, "science")
                  .and
                  .gt(:views, 1000)
            end
        end
end.all(Post)
```

### Comparison Operators

```crystal
# All available comparison operators
query.from(:users).where do |filter|
  filter.eq(:status, "active")           # Equal
        .and
        .not_eq(:role, "guest")          # Not equal
        .and
        .gt(:age, 18)                    # Greater than
        .and
        .gte(:score, 100)                # Greater than or equal
        .and
        .lt(:age, 65)                    # Less than
        .and
        .lte(:balance, 1000)             # Less than or equal
        .and
        .like(:email, "%@company.com")   # LIKE pattern
        .and
        .not_like(:name, "%test%")       # NOT LIKE pattern
        .and
        .in(:role, ["admin", "moderator"]) # IN array
        .and
        .not_in(:status, ["banned"])     # NOT IN array
        .and
        .is_null(:deleted_at)            # IS NULL
        .and
        .is_not_null(:email)             # IS NOT NULL
end.all(User)
```

### Range and Between Conditions

```crystal
# Range conditions
query.from(:users).where do |filter|
  filter.between(:age, 18, 65)
        .and
        .between(:created_at, 1.month.ago, Time.utc)
end.all(User)

# Not between
query.from(:users).where do |filter|
  filter.not_between(:score, 0, 100)
end.all(User)
```

## Subqueries

### EXISTS Subqueries

```crystal
# Find users who have posts
query.from(:users).where do |filter|
  filter.exists do |subquery|
    subquery.from(:posts)
            .where(posts: {user_id: users: :id})
  end
end.all(User)

# Find users with no posts
query.from(:users).where do |filter|
  filter.not_exists do |subquery|
    subquery.from(:posts)
            .where(posts: {user_id: users: :id})
  end
end.all(User)
```

### IN Subqueries

```crystal
# Find posts by users with high scores
query.from(:posts).where do |filter|
  filter.in(:user_id) do |subquery|
    subquery.from(:users)
            .select(:id)
            .where(users: {score: 100..})
  end
end.all(Post)
```

### Scalar Subqueries

```crystal
# Select with subquery in column
query.select(
  :title,
  :body,
  subquery: {
    query.from(:comments)
         .select(:count)
         .where(comments: {post_id: posts: :id})
         .get(Int64)
  }
).from(:posts).all(Post)
```

## Dynamic Query Building

### Conditional Query Construction

```crystal
def build_user_query(active: Bool? = nil, role: String? = nil, min_age: Int32? = nil)
  base_query = query.from(:users)

  # Add conditions only if parameters are provided
  base_query = base_query.where(active: active) if active
  base_query = base_query.where(role: role) if role
  base_query = base_query.where do |filter|
    filter.gte(:age, min_age)
  end if min_age

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
  base_user_query.where(created_at: 1.month.ago..Time.utc)
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
         .where(created_at: days.days.ago..Time.utc)
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
  query.from(:users).where do |filter|
    filter.group do |g|
      g.like(:name, "%#{term}%")
        .or
        .like(:email, "%#{term}%")
        .or
        .like(:bio, "%#{term}%")
    end
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
    base_query = base_query.where(created_at: start_date..end_date)
  elsif start_date
    base_query = base_query.where do |filter|
      filter.gte(:created_at, start_date)
    end
  elsif end_date
    base_query = base_query.where do |filter|
      filter.lte(:created_at, end_date)
    end
  end

  base_query
end
```

### Complex Aggregation Filters

```crystal
# Find users with more than 5 posts
query.from(:users).where do |filter|
  filter.gt do |subquery|
    subquery.from(:posts)
            .select(:count)
            .where(posts: {user_id: users: :id})
            .get(Int64)
  end, 5
end.all(User)
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
query.cache(true)

# Build and execute query
users = query.from(:users)
             .where(active: true)
             .all(User)

# Subsequent identical queries will use cache
cached_users = query.from(:users)
                    .where(active: true)
                    .all(User)
```

### Batch Processing

```crystal
# Process large datasets in batches
def process_all_users(batch_size : Int32 = 1000)
  offset = 0

  loop do
    users = query.from(:users)
                 .order(:id)
                 .limit(batch_size)
                 .offset(offset)
                 .all(User)

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
    # Validate query before execution
    if query.valid?
      users = query.all(User)
      return users
    else
      puts "Invalid query configuration"
      return [] of User
    end
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
user_query = query.from(:users).where(active: true)
log_query(user_query)
users = user_query.all(User)
```

### Performance Monitoring

```crystal
def timed_query_execution
  start_time = Time.monotonic

  users = query.from(:users).all(User)

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
    query.from(:users).where do |filter|
      filter.eq(:active, true)
            .and
            .eq(:role, "admin")
            .and
            .exists do |subquery|
              subquery.from(:posts)
                      .where(posts: {user_id: users: :id})
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
    ->(filter : Expression::FilterBuilder) {
      filter.eq(:active, true)
    }
  end

  def self.recent_filter(days : Int32)
    ->(filter : Expression::FilterBuilder) {
      filter.gte(:created_at, days.days.ago)
    }
  end
end

# Usage
query.from(:users).where do |filter|
  QueryComponents.active_filter.call(filter)
  QueryComponents.recent_filter(30).call(filter)
end.all(User)
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
  base_query = base_query.where(age: age_range) if age_range

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
