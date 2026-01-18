# CQL Caching Guide

CQL provides powerful, multi-layered caching that dramatically improves application performance. This guide shows you how to set up and use all caching features effectively.

## Quick Start

```crystal
# Enable basic caching
CQL.configure do |c|
  c.db = "postgresql://localhost/myapp"
  c.cache.on = true                    # Enable caching
  c.cache.ttl = 30.minutes            # Cache for 30 minutes
  c.cache.memory_size = 2000          # Keep 2000 entries in memory
end

# Your queries are now automatically cached!
users = User.all  # First call hits database
users = User.all  # Second call uses cache
```

## Cache Types

CQL provides multiple caching layers that work together:

1. **Query Cache** - Automatic query result caching
2. **Request Cache** - Per-request query deduplication
3. **Fragment Cache** - Cache parts of complex operations
4. **Memory Cache** - In-memory storage (default)
5. **Redis Cache** - Distributed caching with Redis

## Basic Configuration

### Memory Caching (Default)

```crystal
CQL.configure do |c|
  c.cache.on = true
  c.cache.ttl = 1.hour                # How long to cache
  c.cache.memory_size = 5000          # Max entries in memory
end
```

### Redis Caching

```crystal
CQL.configure do |c|
  c.cache.on = true
  c.cache.store = "redis"
  c.cache.redis_url = "redis://localhost:6379/0"
  c.cache.redis_pool_size = 25
  c.cache.ttl = 1.hour
end
```

### Environment-Based Setup

```crystal
CQL.configure do |c|
  c.cache.on = true
  c.cache.ttl = c.env == "production" ? 1.hour : 5.minutes
  c.cache.memory_size = c.env == "production" ? 10000 : 1000

  # Use Redis in production
  if c.env == "production" && ENV["REDIS_URL"]?
    c.cache.store = "redis"
    c.cache.redis_url = ENV["REDIS_URL"]
  end
end
```

## Request-Scoped Caching

Perfect for web applications - eliminates duplicate queries within a single request.

### Setup

```crystal
CQL.configure do |c|
  c.cache.on = true
  c.cache.request_cache = true        # Enable request caching
  c.cache.request_size = 1000         # Max queries per request
end
```

### Web Framework Integration

#### Kemal

```crystal
require "cql/cache/middleware"

before_all do |env|
  CQL.start_request_cache
end

after_all do |env|
  CQL.end_request_cache
end
```

#### Lucky

```crystal
# In ApplicationAction
abstract class ApplicationAction < Lucky::Action
  include CQL::Cache::Middleware::Lucky
end
```

#### Azu

The [Azu framework](https://github.com/azutoolkit/azu) is a Crystal application development toolkit with expressive, elegant syntax. CQL integrates seamlessly with Azu through multiple approaches:

```crystal
require "cql/cache/middleware"

# Option 1: HTTP Handler (Recommended)
app = Azu::Application.new
app.use CQL::Cache::Middleware::Azu::Handler.new

# Option 2: Controller Integration
class ApplicationController < Azu::Controller
  include CQL::Cache::Middleware::Azu::Controller
end

# Option 3: Manual Hooks
app.before { |ctx| CQL::Cache::Middleware::Azu.before_request(ctx) }
app.after { |ctx| CQL::Cache::Middleware::Azu.after_request(ctx) }

# Option 4: Convenience Setup
CQL::Cache::Middleware::Azu.setup!(app)
```

#### Any Framework

```crystal
# Manual control
CQL.with_request_cache do
  # All queries in this block share a cache
  user = User.find(1)
  posts = user.posts      # Won't duplicate the user lookup
  comments = posts.flat_map(&.comments)
end
```

## Fragment Caching

Cache expensive operations or complex query results.

### Setup

```crystal
CQL.configure do |c|
  c.cache.on = true
  c.cache.fragments = true
  c.cache.invalidation = "transaction_aware"  # or "timestamp", "version"
end
```

### Usage

```crystal
# Cache expensive calculations
fragment_cache = CQL.fragment_cache

result = fragment_cache.cache_fragment(
  fragment_name: "user_stats",
  params: {"user_id" => user.id},
  tags: ["user:#{user.id}", "stats"],
  ttl: 1.hour
) do
  # Expensive operation
  {
    total_posts: user.posts.count,
    total_likes: user.posts.sum(&.likes_count),
    average_rating: user.posts.average(&.rating)
  }.to_json
end

# Invalidate by tags
fragment_cache.invalidate_tags(["user:#{user.id}"])
```

## Advanced Cache Configuration

### Complete Setup

```crystal
CQL.configure do |c|
  # Core caching
  c.cache.on = true
  c.cache.ttl = 45.minutes
  c.cache.memory_size = 5000

  # Store configuration (memory/redis)
  c.cache.store = ENV["REDIS_URL"] ? "redis" : "memory"
  c.cache.redis_url = ENV["REDIS_URL"] if ENV["REDIS_URL"]?
  c.cache.redis_pool_size = 25

  # Request-scoped caching
  c.cache.request_cache = true
  c.cache.request_size = 1000

  # Fragment caching
  c.cache.fragments = true
  c.cache.invalidation = "transaction_aware"

  # Performance
  c.cache.key_prefix = "myapp"         # Namespace your cache keys
  c.cache.auto_cleanup = true          # Auto-remove expired entries
end
```

### Invalidation Strategies

```crystal
# Timestamp-based (default) - invalidate by age
c.cache.invalidation = "timestamp"

# Version-based - increment version to invalidate
c.cache.invalidation = "version"

# Transaction-aware - invalidate after DB transactions
c.cache.invalidation = "transaction_aware"
```

## Cache Management

### Runtime Control

```crystal
# Enable/disable caching
CQL.cache_on(true)
CQL.cache_on(false)
puts CQL.cache_on?              # Check status

# Clear cache data
CQL.reset_cache!                # Clear statistics
cache = CQL.memory_cache
cache.clear                     # Clear all cached data
```

### Performance Monitoring

```crystal
# Get detailed statistics
stats = CQL.cache_stats
puts "Hit rate: #{stats["hit_rate_percent"]}%"
puts "Cache size: #{stats["cache_size"]} entries"
puts "Memory usage: #{stats["memory_usage_bytes"]} bytes"

# Get human-readable summary
puts CQL.cache_summary
# => === CQL Query Cache Performance Summary ===
# => Status: Enabled
# => Cache Store: memory
# => Total Requests: 1250
# => Cache Hits: 875 (70.0%)
# => Cache Misses: 375 (30.0%)
# => Cache Size: 450 entries
```

### Cache Instances

```crystal
# Create custom cache instances
memory_cache = CQL.memory_cache
fragment_cache = CQL.fragment_cache

# Direct cache operations
memory_cache.set("custom_key", "value", 1.hour)
value = memory_cache.get("custom_key")
memory_cache.delete("custom_key")
```

## Practical Examples

### E-commerce Application

```crystal
CQL.configure do |c|
  c.db = ENV["DATABASE_URL"]
  c.cache.on = true
  c.cache.ttl = 15.minutes         # Products change frequently
  c.cache.request_cache = true     # Web app with many requests
  c.cache.fragments = true         # Cache category trees, etc.

  # Redis for production
  if c.env == "production"
    c.cache.store = "redis"
    c.cache.redis_url = ENV["REDIS_URL"]
    c.cache.memory_size = 50000    # Large product catalog
  end
end

# Cache expensive product queries
class Product < CQL::Model
  def self.featured_products
    CQL::Cache.with_cache("featured_products", {} of String => String, 1.hour) do
      where(featured: true)
        .joins(:category)
        .where(categories: {active: true})
        .order_by(:priority)
        .limit(10)
    end
  end
end

# Fragment cache for complex category tree
def render_category_tree
  fragment_cache = CQL.fragment_cache
  fragment_cache.cache_fragment(
    fragment_name: "category_tree",
    tags: ["categories"],
    ttl: 30.minutes
  ) do
    Category.root_categories.preload(:children).to_json
  end
end
```

### Blog Application

```crystal
CQL.configure do |c|
  c.cache.on = true
  c.cache.ttl = 2.hours            # Content doesn't change often
  c.cache.request_cache = true
  c.cache.fragments = true
  c.cache.invalidation = "version" # Precise control over invalidation
end

# Cache post content with tags
class Post < CQL::Model
  after_save :invalidate_cache

  def cached_content
    fragment_cache = CQL.fragment_cache
    fragment_cache.cache_fragment(
      fragment_name: "post_content",
      params: {"post_id" => id.to_s},
      tags: ["post:#{id}", "author:#{author_id}"],
      ttl: 4.hours
    ) do
      render_markdown(content)
    end
  end

  private def invalidate_cache
    CQL.fragment_cache.invalidate_tags(["post:#{id}"])
  end
end
```

### API Application

```crystal
CQL.configure do |c|
  c.cache.on = true
  c.cache.store = "redis"          # Shared across API instances
  c.cache.redis_url = ENV["REDIS_URL"]
  c.cache.ttl = 10.minutes
  c.cache.request_cache = false    # API doesn't have request lifecycle
  c.cache.key_prefix = "api"
end

# Cache API responses
class UsersController
  def index
    CQL::Cache.with_cache("users_index", {"page" => params[:page]}, 5.minutes) do
      users = User.active.page(params[:page])
      {
        users: users.map(&.to_json),
        total: users.total_count,
        page: params[:page]
      }.to_json
    end
  end
end
```

### Azu Framework Application

```crystal
require "azu"
require "cql"
require "cql/cache/middleware"

# Configure CQL with caching for Azu
CQL.configure do |c|
  c.db = ENV["DATABASE_URL"]
  c.cache.on = true
  c.cache.ttl = 30.minutes          # Web app with moderate caching
  c.cache.request_cache = true      # Enable per-request caching
  c.cache.fragments = true          # Enable fragment caching
  c.cache.key_prefix = "azu_app"

  # Use Redis in production for multi-instance deployments
  if ENV["CRYSTAL_ENV"] == "production"
    c.cache.store = "redis"
    c.cache.redis_url = ENV["REDIS_URL"]
    c.cache.memory_size = 10000
  end
end

# Create Azu application with caching middleware
app = Azu::Application.new
app.use CQL::Cache::Middleware::Azu::Handler.new

# Base controller with caching utilities
abstract class ApplicationController < Azu::Controller
  include CQL::Cache::Middleware::Azu::Controller

  # Helper method for fragment caching
  def cache_fragment(name : String, **options, &block)
    fragment_cache = CQL.fragment_cache
    fragment_cache.cache_fragment(
      fragment_name: name,
      params: options.to_h.transform_values(&.to_s),
      ttl: 15.minutes,
      &block
    )
  end
end

# Example controller with advanced caching
class ProductsController < ApplicationController
  # Cache expensive product listings
  def index
    cache_key = "products_index_#{params[:category]?}_#{params[:page]?}"

    products_json = cache_fragment(cache_key) do
      products = Product.active
      products = products.where(category: params[:category]) if params[:category]?
      products = products.page(params[:page]?.try(&.to_i) || 1)

      # This query will be cached per-request
      {
        products: products.map(&.to_json),
        total: products.total_count,
        page: params[:page]?.try(&.to_i) || 1
      }.to_json
    end

    render json: products_json
  end

  # Cache individual product with related data
  def show
    product_id = params[:id]

    product_json = cache_fragment("product_#{product_id}") do
      product = Product.find(product_id)
      reviews = product.reviews.preload(:user).limit(10)

      {
        product: product.to_json,
        reviews: reviews.map(&.to_json),
        related_products: product.related_products.limit(5).map(&.to_json)
      }.to_json
    end

    render json: product_json
  end
end

# Example of invalidating cache after updates
class AdminProductsController < ApplicationController
  def update
    product = Product.find(params[:id])

    if product.update(product_params)
      # Invalidate related caches
      fragment_cache = CQL.fragment_cache
      fragment_cache.invalidate_tags([
        "product:#{product.id}",
        "category:#{product.category}",
        "products_index"
      ])

      render json: {status: "success", product: product.to_json}
    else
      render json: {status: "error", errors: product.errors}
    end
  end
end

# Configure routes
app.routes do
  get "/products", ProductsController, :index
  get "/products/:id", ProductsController, :show
  put "/admin/products/:id", AdminProductsController, :update
end

# Add performance monitoring for cache
app.after do |ctx|
  if ENV["CRYSTAL_ENV"] == "development"
    stats = CQL.cache_stats
    ctx.response.headers["X-Cache-Stats"] = "hits:#{stats["hits"]},misses:#{stats["misses"]}"
  end
end

# Start the server
app.listen(3000)
```

## Performance Tips

### Cache Key Design

```crystal
# Good: Specific, includes relevant parameters
cache_key = "user_posts:#{user_id}:page:#{page}:sort:#{sort_order}"

# Bad: Too generic, will cause conflicts
cache_key = "posts"
```

### TTL Strategy

```crystal
# Frequently changing data: short TTL
c.cache.ttl = 5.minutes          # User activity, notifications

# Stable data: longer TTL
c.cache.ttl = 4.hours           # User profiles, settings

# Static data: very long TTL
c.cache.ttl = 24.hours          # Categories, tags, configuration
```

### Memory Management

```crystal
# Production: Large cache size
c.cache.memory_size = 50000

# Development: Smaller cache size
c.cache.memory_size = 1000

# Enable automatic cleanup
c.cache.auto_cleanup = true
```

## Troubleshooting

### Cache Not Working

```crystal
# Check if caching is enabled
puts CQL.cache_on?              # Should be true
puts CQL.config.cache.on?       # Should be true

# Check cache statistics
stats = CQL.cache_stats
puts "Total requests: #{stats["total_requests"]}"
puts "Hits: #{stats["hits"]}"
puts "Misses: #{stats["misses"]}"
```

### Memory Issues

```crystal
# Monitor memory usage
stats = CQL.cache_stats
puts "Memory usage: #{stats["memory_usage_bytes"]} bytes"
puts "Cache size: #{stats["cache_size"]} entries"

# Reduce cache size if needed
CQL.configure do |c|
  c.cache.memory_size = 1000     # Reduce max entries
  c.cache.ttl = 15.minutes       # Reduce TTL
end
```

### Redis Connection Issues

```crystal
# Test Redis connection
if redis_cache = CQL.cache_store.as?(CQL::Cache::RedisCache)
  puts redis_cache.ping          # Should return true
  puts redis_cache.connection_info
end

# Fallback to memory cache if Redis fails
CQL.configure do |c|
  c.cache.store = ENV["REDIS_URL"] ? "redis" : "memory"
end
```

## Best Practices

1. **Start with memory cache** - simple and effective for most applications
2. **Enable request caching** for web applications - eliminates duplicate queries
3. **Use fragment caching** for expensive operations - complex calculations, external API calls
4. **Monitor cache performance** - watch hit rates and memory usage
5. **Set appropriate TTLs** - balance data freshness with performance
6. **Use Redis for production** - when you have multiple app instances
7. **Tag your fragments** - enables precise cache invalidation
8. **Cache at the right level** - query cache for raw data, fragment cache for processed results

## Environment Examples

### Development

```crystal
CQL.configure do |c|
  c.cache.on = true
  c.cache.ttl = 5.minutes          # Short TTL for testing
  c.cache.memory_size = 1000       # Small cache
  c.cache.request_cache = true
end
```

### Production

```crystal
CQL.configure do |c|
  c.cache.on = true
  c.cache.store = "redis"
  c.cache.redis_url = ENV["REDIS_URL"]
  c.cache.redis_pool_size = 25
  c.cache.ttl = 1.hour
  c.cache.memory_size = 50000      # Large cache
  c.cache.request_cache = true
  c.cache.fragments = true
  c.cache.invalidation = "transaction_aware"
end
```

Caching in CQL is designed to be powerful yet simple to use. Start with basic query caching and gradually add more advanced features as your application grows!
