---
icon: zap
---

# Performance Optimization Guide

Essential techniques for optimizing CQL applications for speed and scalability.

## Query Optimization

### Solving N+1 Queries

**The Problem:**
```crystal
# This generates N+1 queries (1 + N where N = number of users)
users = User.all  # Query 1: SELECT * FROM users

users.each do |user|
  puts user.posts.count  # Query N: SELECT COUNT(*) FROM posts WHERE user_id = ?
end
```

**Solution 1: Eager Loading**
```crystal
# This generates only 2 queries regardless of user count
users = User.join(:posts).all  # Query 1: Users, Query 2: All related posts

users.each do |user|
  puts user.posts.size  # No additional queries - data already loaded
end
```

**Solution 2: Counter Cache**
```crystal
# Add counter cache column
class AddPostsCountToUsers < CQL::Migration
  def up
    alter_table :users do
      add_column :posts_count, Int32, default: 0
    end
  end
end

struct User
  property posts_count : Int32 = 0
  has_many :posts, Post, counter_cache: true
end

# Now this is instant - no queries needed
users.each do |user|
  puts user.posts_count  # Reads from cached column
end
```

### Efficient Query Patterns

**Use Specific Selects**
```crystal
# Load only needed columns
users = User.select(:id, :name, :email).all

# For associations, be specific too
posts_with_authors = Post
  .joins(:user)
  .select("posts.*, users.name as author_name")
  .all
```

**Optimize WHERE Conditions**
```crystal
# Use indexed columns first
fast_users = User.where(active: true)
                 .where(created_at: 1.month.ago..Time.utc)
                 .where(role: "admin")
                 .all
```

**Efficient Pagination**
```crystal
# OFFSET pagination (gets slower with higher page numbers)
page = params["page"]?.try(&.to_i) || 1
per_page = 20
users = User.limit(per_page).offset((page - 1) * per_page).all

# Cursor-based pagination (consistent performance)
last_id = params["last_id"]?.try(&.to_i64) || 0
users = User.where { id > last_id }
           .order(:id)
           .limit(20)
           .all
```

**Batch Processing**
```crystal
# Process in batches instead of all at once
User.find_in_batches(batch_size: 1000) do |batch|
  batch.each { |user| process_user(user) }
end

# Use bulk operations
User.where(active: true).update_all(last_login: Time.utc)
```

**Database-Level Aggregations**
```crystal
# Single query with conditional aggregation
stats = User.select(
  "COUNT(*) as total_count",
  "COUNT(CASE WHEN active = true THEN 1 END) as active_count",
  "COUNT(CASE WHEN role = 'admin' THEN 1 END) as admin_count"
).first
```

## Database Indexing

### Strategic Index Design

```crystal
UserSchema = CQL::Schema.define(:user_app, adapter, uri) do
  table :users do
    primary :id, Int64, auto_increment: true
    column :email, String, size: 255
    column :username, String, size: 100
    column :active, Bool, default: true
    column :role, String, size: 50
    column :created_at, Time
    column :updated_at, Time

    # Single column indexes
    index [:email], unique: true
    index [:username], unique: true
    index [:active]

    # Composite indexes (order matters!)
    index [:active, :role]
    index [:active, :created_at]
  end

  table :posts do
    primary :id, Int64, auto_increment: true
    column :user_id, Int64
    column :title, String
    column :status, String
    column :published_at, Time
    timestamps

    # Foreign key indexes (essential for joins)
    index [:user_id]

    # Query-specific indexes
    index [:status, :published_at]
    index [:user_id, :status]
  end
end
```

### Index Analysis

```crystal
# Monitor index usage (PostgreSQL)
def analyze_index_usage
  unused_indexes = DB.query_all(<<-SQL, as: NamedTuple)
    SELECT schemaname, tablename, indexname, idx_tup_read, idx_tup_fetch
    FROM pg_stat_user_indexes
    WHERE idx_tup_read = 0 AND idx_tup_fetch = 0
    ORDER BY schemaname, tablename, indexname
  SQL

  puts "Unused indexes:"
  unused_indexes.each do |idx|
    puts "  #{idx[:tablename]}.#{idx[:indexname]}"
  end
end

# Check query performance
def explain_query(query)
  explained = DB.query_one("EXPLAIN ANALYZE #{query}", as: String)
  puts explained
end
```

## Connection Pool Optimization

```crystal
# Configure connection pools for different environments
module DatabaseConfig
  def self.production_config
    {
      pool_size: ENV["DB_POOL_SIZE"]?.try(&.to_i) || 25,
      checkout_timeout: 15.seconds,
      retry_attempts: 3,
      idle_timeout: 10.minutes,
      max_lifetime: 1.hour
    }
  end

  def self.development_config
    {
      pool_size: 5,
      checkout_timeout: 10.seconds,
      retry_attempts: 1
    }
  end
end

# Apply configuration
ProductionDB = CQL::Schema.define(
  :production,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"],
  **DatabaseConfig.production_config
)
```

### Connection Pool Monitoring

```crystal
class ConnectionPoolMonitor
  def self.check_pool_health(db_context)
    stats = db_context.pool_stats

    puts "Pool Size: #{stats.pool_size}"
    puts "Available: #{stats.available_connections}"
    puts "In Use: #{stats.checked_out_connections}"
    puts "Queue Size: #{stats.waiting_queue_size}"

    # Alert if pool utilization is high
    utilization = stats.checked_out_connections.to_f / stats.pool_size
    puts "WARNING: High pool utilization (#{(utilization * 100).round(1)}%)" if utilization > 0.8
  end
end
```

## Caching Strategies

### Query Result Caching

```crystal
# Memory cache for frequently accessed data
class QueryCache
  @@cache = {} of String => Array(NamedTuple)

  def self.fetch(key : String, ttl = 5.minutes, &block)
    if cached = @@cache[key]?
      return cached
    end

    result = yield
    @@cache[key] = result

    # Simple TTL cleanup
    spawn do
      sleep ttl
      @@cache.delete(key)
    end

    result
  end
end

# Usage
def get_popular_posts
  QueryCache.fetch("popular_posts", 10.minutes) do
    Post.where(status: "published")
        .order(view_count: :desc)
        .limit(10)
        .all
  end
end
```

### Fragment Caching

```crystal
# Cache expensive computed values
class FragmentCache
  @@cache = {} of String => String

  def self.fetch(key : String, &block : -> String)
    return @@cache[key] if @@cache.has_key?(key)
    @@cache[key] = yield
  end
end

# Cache rendered content
def render_user_stats(user_id)
  FragmentCache.fetch("user_stats_#{user_id}") do
    user = User.find!(user_id)
    {
      posts_count: user.posts.count,
      comments_count: user.comments.count,
      followers_count: user.followers.count
    }.to_json
  end
end
```

## Memory Optimization

### Efficient Data Loading

```crystal
# Stream large datasets instead of loading all into memory
def process_all_users
  User.find_each(batch_size: 500) do |user|
    process_user(user)

    # Force garbage collection periodically
    GC.collect if Random.rand(100) == 0
  end
end

# Use iterator patterns for large collections
def export_user_data
  User.where(active: true).find_each do |user|
    yield user.to_export_format
  end
end
```

### Memory-Efficient Queries

```crystal
# Instead of loading full objects
users = User.all  # Loads all columns and creates full objects

# Load only what you need
user_data = User.select(:id, :name, :email).all  # Minimal memory usage

# Use raw queries for heavy data processing
def calculate_user_metrics
  DB.query_each("SELECT id, created_at, last_login FROM users WHERE active = true") do |rs|
    id = rs.read(Int64)
    created_at = rs.read(Time)
    last_login = rs.read(Time?)

    # Process without creating AR objects
    process_user_metrics(id, created_at, last_login)
  end
end
```

## Database-Specific Optimizations

### PostgreSQL

```crystal
# Enable useful extensions
def setup_postgresql_performance
  DB.exec("CREATE EXTENSION IF NOT EXISTS pg_stat_statements")
  DB.exec("CREATE EXTENSION IF NOT EXISTS pg_trgm")
end

# Full-text search
posts = Post.where("to_tsvector('english', title || ' ' || content) @@ plainto_tsquery('crystal programming')").all

# JSONB queries
users_with_preferences = User.where("preferences->>'theme' = 'dark'").all
```

### MySQL

```crystal
# Full-text search
posts = Post.where("MATCH(title, content) AGAINST('crystal programming' IN NATURAL LANGUAGE MODE)").all

# Use covering indexes
# CREATE INDEX idx_posts_covering ON posts (status) INCLUDE (title, created_at)
```

### SQLite

```crystal
# Optimize SQLite for performance
def optimize_sqlite(db_path)
  DB.exec("PRAGMA journal_mode = WAL")
  DB.exec("PRAGMA synchronous = NORMAL")
  DB.exec("PRAGMA cache_size = -64000")  # 64MB cache
  DB.exec("PRAGMA temp_store = MEMORY")
end
```

## Performance Monitoring

### Query Performance Tracking

```crystal
class QueryTracker
  @@slow_queries = [] of NamedTuple(sql: String, duration: Time::Span, params: Array(DB::Any))

  def self.track_query(sql : String, params, &block)
    start_time = Time.monotonic
    result = yield
    duration = Time.monotonic - start_time

    if duration > 100.milliseconds
      @@slow_queries << {sql: sql, duration: duration, params: params}
      puts "SLOW QUERY (#{duration.total_milliseconds.round(2)}ms): #{sql}"
    end

    result
  end

  def self.slow_queries
    @@slow_queries
  end
end

# Integrate with CQL (pseudo-code)
module CQL::QueryMonitoring
  def execute_query(sql, params)
    QueryTracker.track_query(sql, params) do
      super(sql, params)
    end
  end
end
```

### Application Performance Metrics

```crystal
class PerformanceMonitor
  def self.measure_memory(&block)
    gc_stats_before = GC.stats
    result = yield
    gc_stats_after = GC.stats

    memory_used = gc_stats_after.heap_size - gc_stats_before.heap_size
    puts "Memory used: #{memory_used} bytes"

    result
  end

  def self.benchmark(label : String, &block)
    start_time = Time.monotonic
    result = yield
    duration = Time.monotonic - start_time

    puts "#{label}: #{duration.total_milliseconds.round(2)}ms"
    result
  end
end

# Usage
PerformanceMonitor.benchmark("User creation") do
  1000.times { User.create!(name: "Test", email: "test#{Random.rand}@example.com") }
end
```

## Performance Testing

### Load Testing Queries

```crystal
# Simple load test for database operations
def load_test_user_creation(concurrent_workers = 10, operations_per_worker = 100)
  channel = Channel(Time::Span).new

  concurrent_workers.times do
    spawn do
      start_time = Time.monotonic

      operations_per_worker.times do |i|
        User.create!(
          name: "Load Test User #{i}",
          email: "loadtest#{Random.rand}@example.com"
        )
      end

      duration = Time.monotonic - start_time
      channel.send(duration)
    end
  end

  total_time = Time::Span.zero
  concurrent_workers.times do
    worker_time = channel.receive
    total_time += worker_time
  end

  avg_time = total_time / concurrent_workers
  operations_per_second = (concurrent_workers * operations_per_worker) / avg_time.total_seconds

  puts "Average time per worker: #{avg_time.total_seconds.round(2)}s"
  puts "Operations per second: #{operations_per_second.round(2)}"
end
```

### Query Performance Benchmarks

```crystal
def benchmark_queries
  # Warm up
  User.count

  # Test different query patterns
  queries = {
    "Simple select" => -> { User.limit(100).all },
    "With where clause" => -> { User.where(active: true).limit(100).all },
    "With join" => -> { User.join(:posts).limit(100).all },
    "Aggregation" => -> { User.group(:role).count },
  }

  queries.each do |name, query|
    times = [] of Time::Span

    10.times do
      start_time = Time.monotonic
      query.call
      times << (Time.monotonic - start_time)
    end

    avg_time = times.sum / times.size
    puts "#{name}: #{avg_time.total_milliseconds.round(2)}ms avg"
  end
end
```

## Best Practices Summary

### Query Optimization
- Use specific SELECT statements
- Implement proper indexing strategy
- Avoid N+1 queries with eager loading
- Use cursor-based pagination for large datasets
- Process large datasets in batches

### Database Configuration
- Optimize connection pool size for your workload
- Monitor connection pool utilization
- Use appropriate database-specific features
- Regular index analysis and cleanup

### Memory Management
- Stream data instead of loading everything
- Use efficient data structures
- Implement appropriate caching strategies
- Monitor memory usage patterns

### Monitoring
- Track slow queries
- Monitor connection pool health
- Measure memory usage
- Benchmark critical operations

This guide provides practical techniques for optimizing CQL applications. Focus on measuring performance before and after optimizations to ensure they provide real benefits.

---

> **Performance is a journey, not a destination** - Use these techniques strategically based on your application's specific needs and bottlenecks. Always measure before and after optimizations to ensure they provide real benefits.

**Next Steps:**

- **[Testing Guide →](testing-strategies.md)** - Test your optimizations
- **[Security Guide →](security-guide.md)** - Secure performance patterns
- **[Monitoring Guide →](monitoring-guide.md)** - Track performance in production
