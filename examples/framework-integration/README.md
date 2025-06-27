# Framework Integration Examples

This directory demonstrates how to integrate CQL's advanced features with popular Crystal web frameworks. Learn how to seamlessly add CQL's caching, performance monitoring, and ORM capabilities to your web applications.

## 📝 Examples Overview

### 🚀 **azu_query_cache_demo.cr**

**Purpose:** Comprehensive integration example with the Azu framework
**Repository:** [https://github.com/azutoolkit/azu](https://github.com/azutoolkit/azu)
**Features:**

- HTTP Handler integration for automatic request-scoped caching
- Controller integration with before/after hooks
- Manual hook integration for custom setups
- Performance benchmarking and optimization
- Real-world application patterns
- Multiple integration approaches to fit different application structures

**Run:** `crystal azu_query_cache_demo.cr`

## 🌐 Supported Framework Integrations

### Azu Framework Integration

CQL provides first-class support for the Azu toolkit with multiple integration options:

#### Option A: HTTP Handler Integration

```crystal
require "cql/cache/middleware"

server = HTTP::Server.new([
  CQL::Cache::Middleware::Azu::Handler.new,
  YourAzuApp.new
])
```

#### Option B: Convenience Setup

```crystal
app = YourAzuApp.new
CQL::Cache::Middleware::Azu.setup!(app)
```

#### Option C: Controller Integration

```crystal
class ApplicationController < Azu::Controller
  include CQL::Cache::Middleware::Azu::Controller
end
```

### Kemal Framework Integration

CQL also supports Kemal with middleware patterns:

```crystal
require "cql/cache/middleware"

# Add to your Kemal app
before_all do |env|
  CQL::Cache::Middleware::Kemal.before_request(env)
end

after_all do |env|
  CQL::Cache::Middleware::Kemal.after_request(env)
end
```

## 🎯 Integration Benefits

### Automatic Performance Optimization

- **Query Deduplication** - Eliminate duplicate queries within requests
- **Zero Configuration** - Works out of the box with minimal setup
- **Thread Safety** - Safe for concurrent request handling
- **Request Isolation** - Cache automatically clears between requests

### Performance Improvements

- **2-10x Faster** - Typical speedup for applications with query duplication
- **Memory Efficient** - Request-scoped caching prevents memory leaks
- **Detailed Statistics** - Monitor cache effectiveness and performance

### Developer Experience

- **Multiple Integration Options** - Choose the pattern that fits your app
- **Minimal Code Changes** - Add caching without restructuring code
- **Framework Agnostic** - Consistent API across different frameworks
- **Production Ready** - Battle-tested in real applications

## 🚀 Getting Started

### Prerequisites

- Crystal 1.16.3+
- SQLite3 (for examples)
- Basic familiarity with your chosen web framework

### Quick Setup for Azu

```crystal
# 1. Add CQL to your dependencies
dependencies:
  cql:
    github: crystal-lang/cql

# 2. Require and configure
require "cql"
require "cql/cache/middleware"

CQL.configure do |c|
  c.db = ENV["DATABASE_URL"]
  c.cache.on = true
  c.cache.request_cache = true
end

# 3. Add to your Azu app
class BlogApp < Azu::Application
  use CQL::Cache::Middleware::Azu::Handler.new

  # Your routes and handlers
end
```

## 📊 Real-World Integration Patterns

### Blog Application Example

```crystal
class BlogApp < Azu::Application
  # Enable per-request query caching
  use CQL::Cache::Middleware::Azu::Handler.new

  get "/articles" do |ctx|
    # First query - hits database
    articles = Article.published.includes(:author)

    # If this same query runs again in the same request
    # (e.g., in a partial or helper), it hits the cache
    popular_articles = Article.published.includes(:author)

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
```

### API Service Integration

```crystal
class APIService < Azu::Application
  include CQL::Cache::Middleware::Azu::Controller

  before_action :start_query_cache
  after_action :end_query_cache

  get "/api/users/:id" do |ctx|
    user_id = ctx.params["id"].to_i

    # These queries will be automatically cached per request
    user = User.find(user_id)
    posts = user.posts.published
    comments = user.comments.recent

    # Second call to same queries hits cache
    user_data = {
      user: User.find(user_id),           # Cache hit
      posts: user.posts.published,       # Cache hit
      comments: user.comments.recent      # Cache hit
    }

    render_json user_data
  end
end
```

## 🔧 Advanced Configuration

### Environment-Specific Settings

```crystal
# Development
CQL.configure do |c|
  c.db = "sqlite3://./db/development.db"
  c.cache.on = true
  c.cache.request_cache = true
  c.cache.request_size = 100      # Smaller cache for development
end

# Production
CQL.configure do |c|
  c.db = ENV["DATABASE_URL"]
  c.cache.on = true
  c.cache.request_cache = true
  c.cache.request_size = 1000     # Larger cache for production
  c.cache.redis_url = ENV["REDIS_URL"]  # Persistent cache
end
```

### Custom Middleware Configuration

```crystal
# Custom request cache middleware
class CustomCacheMiddleware
  def call(context)
    request_id = context.request.headers["X-Request-ID"]? || UUID.random.to_s

    CQL::Cache::RequestQueryCacheHelper.start_request(request_id)

    begin
      response = call_next(context)

      # Log cache statistics for monitoring
      stats = CQL::Cache::RequestQueryCacheHelper.stats
      Log.info { "Request cache stats: #{stats}" }

      response
    ensure
      CQL::Cache::RequestQueryCacheHelper.end_request
    end
  end
end
```

## 📈 Performance Monitoring Integration

### Request-Level Performance Tracking

```crystal
class PerformanceMiddleware
  def call(context)
    # Start performance monitoring for this request
    CQL::Performance.monitor.set_context(
      endpoint: context.request.path,
      method: context.request.method,
      user_id: current_user_id(context)
    )

    start_time = Time.monotonic
    response = call_next(context)
    duration = Time.monotonic - start_time

    # Log performance metrics
    metrics = CQL::Performance.monitor.metrics_summary
    Log.info {
      "Request performance: #{duration.total_milliseconds}ms, " \
      "queries: #{metrics.total_queries}, " \
      "slow: #{metrics.slow_queries}"
    }

    response
  end
end
```

### Development Debug Integration

```crystal
# Add to your development environment
if ENV["CRYSTAL_ENV"] == "development"
  after_all do |env|
    # Generate beautiful performance report in development
    CQL::Performance.monitor.generate_comprehensive_report("logger")
  end
end
```

## 🧪 Testing Integration

### Request Cache Testing

```crystal
describe "Request Cache Integration" do
  it "should deduplicate queries within a request" do
    # Simulate request start
    CQL::Cache::Middleware::Azu.before_request(mock_context)

    # Execute duplicate queries
    result1 = User.where(active: true).all
    result2 = User.where(active: true).all

    # Verify cache effectiveness
    stats = CQL::Cache::RequestQueryCache.instance.stats
    expect(stats["hits"]).to be > 0

    # Cleanup
    CQL::Cache::Middleware::Azu.after_request(mock_context)
  end
end
```

### Performance Testing

```crystal
describe "Framework Performance" do
  it "should show significant speedup with caching" do
    # Measure without cache
    CQL::Cache::RequestQueryCacheHelper.enabled = false
    without_cache_time = benchmark_request("/api/dashboard")

    # Measure with cache
    CQL::Cache::RequestQueryCacheHelper.enabled = true
    with_cache_time = benchmark_request("/api/dashboard")

    # Verify improvement
    speedup = without_cache_time / with_cache_time
    expect(speedup).to be > 2.0  # At least 2x speedup
  end
end
```

## 🔗 Framework-Specific Resources

### Azu Framework

- **Repository:** [https://github.com/azutoolkit/azu](https://github.com/azutoolkit/azu)
- **Documentation:** [https://azutopia.gitbook.io/azu/](https://azutopia.gitbook.io/azu/)
- **CQL Integration:** Built-in support with multiple patterns

### Kemal Framework

- **Repository:** [https://github.com/kemalcr/kemal](https://github.com/kemalcr/kemal)
- **CQL Integration:** Middleware-based integration available

### Lucky Framework

- Integration examples coming soon
- Custom adapter patterns available

## 🔗 Related Examples

- **[../caching/](../caching/)** - Learn the caching features being integrated
- **[../performance/](../performance/)** - Monitor your web application performance
- **[../blog/](../blog/)** - See a complete web application example

---

**Ready to supercharge your web framework with CQL?** Start with the Azu integration and adapt the patterns to your chosen framework! 🌐
