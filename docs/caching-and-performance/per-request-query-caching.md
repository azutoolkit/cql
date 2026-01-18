# Per-Request Query Caching

CQL includes a powerful per-request query caching system that automatically caches SQL query results during a single request. This eliminates duplicate database queries within the same request while ensuring cache isolation between requests.

## Key Features

- **Automatic SQL deduplication**: The same SQL query with identical parameters will hit the cache instead of the database if executed again during the same request
- **Per-request lifecycle**: Cache is automatically cleared at the start of each new request
- **Thread-safe**: Safe to use in multi-threaded applications
- **Zero configuration**: Just add middleware to your web framework
- **Memory efficient**: Configurable cache size with automatic eviction
- **Framework agnostic**: Works with all popular Crystal web frameworks

## How It Works

The caching system works at the SQL level by:

1. Generating a unique cache key from the SQL query and parameters
2. Checking the cache before executing any database query
3. Storing results in memory after the first execution
4. Returning cached results for subsequent identical queries
5. Clearing the cache at the end of each request

## Quick Start

### 1. Enable in Web Framework

#### Kemal

```crystal
require "cql/cache/middleware"

# Enable per-request query caching
before_all do |env|
  CQL::Cache::Middleware::Kemal.before_request(env)
end

after_all do |env|
  CQL::Cache::Middleware::Kemal.after_request(env)
end
```

#### Lucky

```crystal
require "cql/cache/middleware"

# In src/actions/application_action.cr
abstract class ApplicationAction < Lucky::Action
  include CQL::Cache::Middleware::Lucky
end
```

#### Amber

```crystal
require "cql/cache/middleware"

# Create a pipe in src/pipes/query_cache_pipe.cr
class QueryCachePipe < Amber::Pipe::Base
  include CQL::Cache::Middleware::Amber
end

# In config/routes.cr
pipeline :web, [QueryCachePipe]
```

#### Azu

```crystal
require "cql/cache/middleware"

# Option 1: Using HTTP Handler
server = HTTP::Server.new([
  CQL::Cache::Middleware::Azu::Handler.new,
  YourAzuApp.new
])

# Option 2: In Controllers
class ApplicationController < Azu::Controller
  include CQL::Cache::Middleware::Azu::Controller
end

# Option 3: Manual hooks
app = Azu::Application.new
app.before { |ctx| CQL::Cache::Middleware::Azu.before_request(ctx) }
app.after { |ctx| CQL::Cache::Middleware::Azu.after_request(ctx) }

# Option 4: Convenience setup
CQL::Cache::Middleware::Azu.setup!(app)
```

#### Generic HTTP::Server

```crystal
require "cql/cache/middleware"

server = HTTP::Server.new([
  CQL::Cache::Middleware::HTTP.new,
  # ... other handlers
])
```

### 2. Manual Integration

For custom frameworks or manual control:

```crystal
require "cql/cache/middleware"

# At the start of each request
CQL::Cache::Middleware::Manual.start_request("optional-request-id")

# Your application logic with CQL queries here
user = User.find(1)
posts = user.posts.where(published: true).all
# If this query runs again in the same request, it hits the cache

# At the end of each request
CQL::Cache::Middleware::Manual.end_request
```

## Example Usage

```crystal
# Start a new request context
CQL::Cache::Middleware::Manual.start_request

# First execution - hits database
users = User.where(active: true).all
puts "First query executed"

# Second execution - hits cache (same SQL)
users_cached = User.where(active: true).all
puts "Second query cached"

# Different query - hits database again
inactive_users = User.where(active: false).all
puts "Different query executed"

# Check cache statistics
stats = CQL::Cache::RequestQueryCacheHelper.stats
puts "Cache hits: #{stats["hits"]}"
puts "Cache misses: #{stats["misses"]}"
puts "Hit rate: #{stats["hit_rate_percent"]}%"

# End request - clears cache
CQL::Cache::Middleware::Manual.end_request
```

## Advanced Usage

### Block-Based Request Scoping

```crystal
CQL::Cache::Middleware::Manual.with_request("request-123") do
  # All queries in this block are cached
  user = User.find(1)
  user = User.find(1) # Cache hit

  posts = user.posts.all
  posts = user.posts.all # Cache hit
end
# Cache automatically cleared when block exits
```

### Enable/Disable Caching

```crystal
# Disable caching globally
CQL::Cache::RequestQueryCacheHelper.enabled = false

# Re-enable caching
CQL::Cache::RequestQueryCacheHelper.enabled = true

# Check if caching is enabled
if CQL::Cache::RequestQueryCacheHelper.enabled?
  puts "Caching is active"
end
```

### Cache Statistics and Monitoring

```crystal
stats = CQL::Cache::RequestQueryCacheHelper.stats

puts "Cache enabled: #{stats["enabled"]}"
puts "Current request ID: #{stats["request_id"]}"
puts "Cache size: #{stats["size"]}"
puts "Max cache size: #{stats["max_size"]}"
puts "Cache hits: #{stats["hits"]}"
puts "Cache misses: #{stats["misses"]}"
puts "Hit rate: #{stats["hit_rate_percent"]}%"
```

## What Gets Cached

The caching system works with all CQL query methods:

- `User.all` - SELECT queries
- `User.find(1)` - Single record lookups
- `User.where(active: true).count` - Aggregate queries
- `User.where(name: "John").first` - Limited queries
- Complex joins and subqueries
- Custom SQL via `Query#get`, `Query#all`, etc.

### Cache Key Generation

Cache keys are generated using:

- The complete SQL query string
- All query parameters
- MD5 hash for consistent, short keys

This ensures that only truly identical queries hit the cache.

## Performance Benefits

Typical performance improvements:

- **2-10x faster** for repeated queries
- **Reduced database load** during high traffic
- **Lower query latency** for complex reports
- **Better scalability** with caching layers

## Best Practices

### 1. Use with Read-Heavy Operations

Per-request caching works best for:

- Dashboard queries that aggregate data
- Navigation menus loaded multiple times
- User permissions checked repeatedly
- Lookup tables accessed frequently

### 2. Monitor Cache Statistics

```crystal
# Add to your monitoring/logging
after_all do |env|
  stats = CQL::Cache::RequestQueryCacheHelper.stats
  if stats["hits"].as(Int64) > 0
    Log.info { "Query cache: #{stats["hits"]} hits, #{stats["misses"]} misses (#{stats["hit_rate_percent"]}% hit rate)" }
  end
  CQL::Cache::Middleware::Kemal.after_request(env)
end
```

### 3. Configure Cache Size

```crystal
# Configure maximum cache entries per request (default: 1000)
cache = CQL::Cache::RequestQueryCache.new(max_size: 500)
```

## Limitations

- **Per-request only**: Cache doesn't persist across requests
- **Memory storage**: Cache is stored in application memory
- **Read queries only**: Only SELECT queries benefit from caching
- **Identical SQL required**: Slight variations in SQL won't hit cache

## Thread Safety

The caching system is fully thread-safe and can be used in:

- Multi-threaded web servers
- Concurrent request handling
- Background job processing
- Fiber-based concurrency

## Troubleshooting

### Cache Not Working

1. **Check if enabled**: `CQL::Cache::RequestQueryCacheHelper.enabled?`
2. **Verify middleware setup**: Ensure before/after hooks are called
3. **Check SQL consistency**: Use cache stats to see hit/miss ratios
4. **Monitor memory usage**: Large result sets might impact performance

### Debugging Cache Behavior

```crystal
# Enable detailed logging
Log.setup do |c|
  c.bind "cql.cache", :debug, Log::IOBackend.new
end

# Check what's in cache
stats = CQL::Cache::RequestQueryCacheHelper.stats
puts "Cache size: #{stats["size"]} entries"
```

## Azu Framework Integration

The [Azu framework](https://github.com/azutoolkit/azu) is a Crystal application development toolkit with expressive, elegant syntax. CQL's per-request query caching integrates seamlessly with Azu through multiple approaches:

### Handler-Based Integration

```crystal
require "azu"
require "cql/cache/middleware"

class BlogApp < Azu::Application
  # Enable per-request query caching
  use CQL::Cache::Middleware::Azu::Handler.new

  get "/articles" do |ctx|
    # First query - hits database
    articles = Article.published.preload(:author)

    # If this same query runs again in the same request
    # (e.g., in a partial or helper), it hits the cache
    popular_articles = Article.published.preload(:author)

    render_template "articles/index.html", {
      articles: articles,
      popular: popular_articles
    }
  end

  get "/dashboard" do |ctx|
    # Multiple related queries that might be repeated
    user_count = User.count                    # Database hit
    article_count = Article.count              # Database hit
    published_count = Article.published.count # Database hit

    # If any of these queries run again, they hit the cache
    stats = {
      users: User.count,                       # Cache hit
      articles: Article.count,                 # Cache hit
      published: Article.published.count       # Cache hit
    }

    render_json stats
  end
end

BlogApp.run(port: 3000)
```

### Controller-Based Integration

```crystal
# Base controller with caching enabled
class ApplicationController < Azu::Controller
  include CQL::Cache::Middleware::Azu::Controller
end

class UsersController < ApplicationController
  def index
    # These queries will be automatically cached per request
    @users = User.where(active: true).all
    @user_count = User.count # Will hit cache if same query

    render "users/index"
  end

  def dashboard
    # Complex queries that benefit from caching
    @active_users = User.where(active: true).preload(:posts)
    @recent_posts = Post.recent.preload(:author)

    # If these queries are repeated (e.g., in partials), they hit cache
    render "dashboard"
  end
end
```

### Manual Hook Integration

```crystal
app = Azu::Application.new

# Add cache lifecycle hooks
app.before do |context|
  CQL::Cache::Middleware::Azu.before_request(context)
end

app.after do |context|
  CQL::Cache::Middleware::Azu.after_request(context)
end

# Your routes...
app.get "/" do |ctx|
  # All queries in this request will be cached automatically
  users = User.all
  posts = Post.published

  render_template "index.html", {users: users, posts: posts}
end
```

## Integration Examples

See the complete working examples for different frameworks:

- `examples/per_request_query_cache_demo.cr` - General usage patterns
- `examples/azu_query_cache_demo.cr` - Azu-specific integration examples

These examples demonstrate:

- Basic usage patterns
- Web framework integration
- Performance comparisons
- Statistics monitoring
- Error handling
- Real-world application patterns

The per-request query caching system provides significant performance benefits with minimal setup, making it an excellent addition to any CQL-based application, especially those built with the Azu framework.
