# Performance Optimization

This guide covers techniques for optimizing CQL performance in your applications.

## Quick Start

### Development (Auto-Enabled)

```crystal
# Performance monitoring is automatically enabled in development
CQL.configure do |config|
  config.db = "postgresql://localhost/myapp"
end

# You get:
# - Query profiling
# - N+1 detection
# - Slow query analysis
# - Performance reports every 5 minutes
```

### Production

```crystal
CQL.configure do |config|
  config.db = ENV["DATABASE_URL"]
  config.env = "production"
  config.monitor_performance = true  # Opt-in for production
  config.performance_auto_report = false  # No auto-reports
end
```

## Query Optimization

### 1. Use Indexes

```crystal
table.column :email, String, unique: true, index: true
table.column :created_at, Time, index: true
table.add_index [:user_id, :status], name: "idx_user_status"
```

### 2. Avoid N+1 Queries

```crystal
# Bad: N+1 query
users = User.all
users.each do |user|
  puts user.posts.count  # Executes query for each user
end

# Good: Eager loading
users = User.includes(:posts).all
users.each do |user|
  puts user.posts.size  # No additional queries
end
```

### 3. Use Query Scopes

```crystal
class User < CQL::Model(User)
  scope :active, -> { where(active: true) }
  scope :recent, -> { order(created_at: :desc).limit(10) }

  # Combine scopes efficiently
  scope :active_recent, -> { active.recent }
end
```

### 4. Batch Operations

```crystal
# Bad: Individual inserts
users.each do |user_data|
  User.create(user_data)
end

# Good: Batch insert
User.insert_many(users)
```

## Connection Pool Optimization

### Development

```crystal
CQL.configure do |config|
  config.db = "postgresql://localhost/myapp"
  config.pool_size = 5  # Small pool for development
end
```

### Production

```crystal
CQL.configure do |config|
  config.db = ENV["DATABASE_URL"]
  config.pool_size = 25  # Larger pool for production

  # Advanced pool settings
  config.pool.initial_size = 5
  config.pool.max_idle_size = 10
  config.pool.checkout_timeout = 5.seconds
end
```

## Caching Strategies

### 1. Query Result Caching

```crystal
CQL.configure do |config|
  config.db = "postgresql://localhost/myapp"

  # Enable caching
  config.cache.on = true
  config.cache.ttl = 30.minutes
  config.cache.memory_size = 2000
end

# Use caching in queries
users = User.where(active: true).cache(5.minutes).all
```

### 2. Fragment Caching

```crystal
cache_key = "user_stats_#{user.id}"
stats = CQL.fragment_cache.fetch(cache_key, expires_in: 1.hour) do
  {
    post_count: user.posts.count,
    comment_count: user.comments.count,
    last_active: user.last_activity_at
  }
end
```

### 3. Request-Scoped Caching

```crystal
CQL.with_request_cache("request_123") do
  # All identical queries within this block are cached
  User.find(1)  # Hits database
  User.find(1)  # Returns cached result
  User.find(2)  # Hits database
end
```

## Performance Monitoring

### Reading Performance Reports

Every 5 minutes in development, you'll see:

```
CQL Query Performance Report
===========================
Total queries: 156
Unique patterns: 23
Slow queries: 5

Top 10 Slowest Query Patterns:
1. SELECT * FROM orders WHERE user_id = ? AND status = ?...
   Executions: 45, Avg: 125.5ms, Max: 450.2ms

N+1 Query Detected [High]:
Parent Query: SELECT * FROM posts
Repeated Query: SELECT * FROM users WHERE id = ?
Repetitions: 25
```

### Custom Report Intervals

```crystal
CQL.configure do |config|
  config.db = "postgresql://localhost/myapp"
  config.performance_report_interval = 1.minute  # More frequent reports
end
```

### Manual Performance Analysis

```crystal
# Get current statistics
stats = CQL::Performance.monitor.statistics

# Generate report on demand
report = CQL::Performance.monitor.generate_comprehensive_report("text")
puts report

# Check for N+1 queries
issues = CQL::Performance.monitor.n_plus_one_issues
issues.each do |issue|
  puts issue.summary
end
```

## Query Plan Analysis

### PostgreSQL

```crystal
# Analyze query plan
result = CQL::Performance.monitor.analyze_query(
  "SELECT * FROM users WHERE email = ?",
  ["user@example.com"]
)

if result.has_issues?
  puts "Query issues: #{result.warnings.join(", ")}"
  puts "Estimated cost: #{result.estimated_cost}"
end
```

### Disable Plan Analysis

```crystal
CQL.configure do |config|
  config.db = "postgresql://localhost/myapp"
  config.monitor_performance = true
  # Plan analysis is enabled by default, no need to configure
end

# To disable in production:
CQL::Performance.monitor.configure do |perf_config|
  perf_config.plan_analysis_enabled = false
end
```

## Database-Specific Optimizations

### PostgreSQL

```crystal
# Use PostgreSQL-specific features
class User < CQL::Model(User)
  # Use GIN index for full-text search
  table.add_index [:search_vector], using: :gin

  # Use partial index
  table.add_index [:email], where: "active = true"
end
```

### MySQL

```crystal
# Configure for MySQL performance
CQL.configure do |config|
  config.db = "mysql://localhost/myapp"
  config.mysql.encoding = "utf8mb4"
  config.mysql.engine = "InnoDB"
end
```

### SQLite

```crystal
# Optimize for SQLite
CQL.configure do |config|
  config.db = "sqlite3://./db/production.db"
  config.sqlite.busy_timeout = 5000
  config.sqlite.journal_mode = "WAL"
end
```

## Best Practices

1. **Use Development Auto-Monitoring**: Let CQL show you performance issues automatically
2. **Fix N+1 Queries**: Use eager loading with `includes`
3. **Add Indexes**: On foreign keys and frequently queried columns
4. **Cache Strategically**: Cache expensive queries and calculations
5. **Monitor Production**: Enable performance monitoring selectively
6. **Batch Operations**: Use `insert_many` and `update_many`
7. **Use Scopes**: Define reusable query patterns

## Common Performance Issues

### Slow Queries

```crystal
# Identify slow queries in reports
# Look for queries marked with warnings or slow indicators

# Add indexes for frequently filtered columns
table.add_index [:status, :created_at]
```

### Memory Usage

```crystal
# Use streaming for large datasets
User.where(active: true).each_batch(100) do |users|
  users.each do |user|
    # Process user
  end
end
```

### Connection Pool Exhaustion

```crystal
# Increase pool size
config.pool_size = 50

# Or use connection management
CQL.transaction do
  # All queries share same connection
end
```

## SQL Logging

Beautiful SQL logging is automatically enabled in development environments to help you debug and optimize your queries.

### Zero Configuration (Development)

```crystal
# SQL logging is automatically enabled in development!
CQL.configure do |config|
  config.db = "postgresql://localhost/myapp"
end

# You'll see beautiful SQL output immediately:
# ✅ SQL 2.3ms (1 row)
# SELECT * FROM users WHERE id = ?
# 📊 Parameters: [123]
```

### Configuration Options

```crystal
CQL.configure do |config|
  config.db = "postgresql://localhost/myapp"

  # SQL logging options
  config.sql_logging = true          # Enable/disable
  config.sql_logging_colorize = true # Colorize output
  config.sql_logging_async = false   # Sync logging (recommended for dev)
end
```

### Output Examples

#### Standard Query

```
SQL 2.3ms (5 rows)
SELECT users.*, posts.title
  FROM users
  INNER JOIN posts ON users.id = posts.user_id
  WHERE users.active = ?
  ORDER BY users.created_at DESC
  LIMIT 10
Parameters: [true]
```

#### Slow Query

```
SQL 125.0ms (100 rows) [SLOW]
SELECT DISTINCT categories.*, COUNT(posts.id) as post_count
  FROM categories
  LEFT JOIN posts ON categories.id = posts.category_id
  GROUP BY categories.id
  HAVING post_count > ?
  ORDER BY post_count DESC
Parameters: [10]
```

#### Error Query

```
SQL 0.5ms (ERROR)
INSERT INTO users (name, email) VALUES (?, ?)
Parameters: ["John Doe", "john@example.com"]
Error: duplicate key value violates unique constraint "users_email_key"
```

### Performance Indicators

The formatter uses visual indicators for query performance:

- **Fast** (< 50ms) - Green checkmark
- **Slow** (50-1000ms) - Yellow warning
- **Very Slow** (> 1000ms) - Slow indicator
- **Error** - Red X

### Production Usage

For production, SQL logging should typically be disabled:

```crystal
CQL.configure do |config|
  config.db = ENV["DATABASE_URL"]
  config.env = "production"
  config.sql_logging = false  # Disabled for performance
end
```

If you need SQL logging in production:

```crystal
CQL.configure do |config|
  config.db = ENV["DATABASE_URL"]
  config.env = "production"
  config.sql_logging = true
  config.sql_logging_async = true     # Use async to reduce impact
  config.sql_logging_colorize = false # No colors in log files
end
```

### Disable Auto-Logging

```crystal
# Option 1: Environment variable
ENV["CQL_NO_SQL_LOG"] = "1"

# Option 2: Explicit configuration
CQL.configure do |config|
  config.db = "postgresql://localhost/myapp"
  config.sql_logging = false
end
```

## Debugging Performance

### Enable All Features

```crystal
CQL.configure do |config|
  config.db = "postgresql://localhost/myapp"
  # Everything auto-enabled in development
end

# Force enable in other environments
CQL::Performance.monitor.configure do |perf|
  perf.query_profiling_enabled = true
  perf.n_plus_one_detection_enabled = true
  perf.plan_analysis_enabled = true
  perf.context_tracking_enabled = true
end
```

### Disable Auto-Features

```crystal
# Via environment variables
ENV["CQL_NO_PERF_MONITOR"] = "1"
ENV["CQL_NO_SQL_LOG"] = "1"

# Or in configuration
config.monitor_performance = false
config.sql_logging = false
```
