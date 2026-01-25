# Use Per-Request Caching

Cache query results within a single HTTP request to avoid duplicate queries.

## Prerequisites

- CQL installed and configured
- Web application with request lifecycle

## The Problem

Within a single request, the same query may run multiple times:

```crystal
# Header partial
current_user = User.find(session[:user_id])  # Query 1

# Sidebar partial
current_user = User.find(session[:user_id])  # Query 2 (duplicate!)

# Main content
current_user = User.find(session[:user_id])  # Query 3 (duplicate!)
```

## Enable Request Cache

Wrap your request handling with a request cache context:

```crystal
class RequestCacheMiddleware
  include HTTP::Handler

  def call(context)
    CQL::RequestCache.with_cache do
      call_next(context)
    end
  end
end

# Add to your middleware stack
server = HTTP::Server.new([
  RequestCacheMiddleware.new,
  # ... other middleware
  MyApp.new
])
```

## How It Works

With request caching enabled, identical queries are cached:

```crystal
CQL::RequestCache.with_cache do
  user1 = User.find(1)  # Executes query
  user2 = User.find(1)  # Returns cached result
  user3 = User.find(1)  # Returns cached result

  # Only 1 query executed!
end
```

## Automatic Caching

All queries within the request cache context are automatically cached:

```crystal
CQL::RequestCache.with_cache do
  # All these are cached
  User.find(1)
  Post.where(user_id: 1).all
  Comment.where(post_id: 5).count
end
```

## Manual Cache Control

### Skip Cache for a Query

```crystal
CQL::RequestCache.with_cache do
  # Force fresh data
  user = User.uncached.find(1)
end
```

### Clear Request Cache

```crystal
CQL::RequestCache.with_cache do
  user = User.find(1)

  # After an update, clear cache
  user.update!(name: "New Name")
  CQL::RequestCache.clear

  user = User.find(1)  # Fresh query
end
```

## With Framework Integration

### Kemal

```crystal
before_all do |env|
  CQL::RequestCache.start
end

after_all do |env|
  CQL::RequestCache.stop
end
```

### Lucky

```crystal
abstract class BrowserAction < Lucky::Action
  around :with_request_cache

  def with_request_cache
    CQL::RequestCache.with_cache { yield }
  end
end
```

### Amber

```crystal
class ApplicationController < Amber::Controller::Base
  around_action :with_request_cache

  private def with_request_cache
    CQL::RequestCache.with_cache { yield }
  end
end
```

## What Gets Cached

Cached:
- `find` queries
- `where` queries
- `count` queries
- `exists?` checks

Not cached:
- Write operations (`save`, `update`, `delete`)
- Raw SQL queries
- Queries after write operations on the same table

## Debugging

Log cache hits:

```crystal
CQL::RequestCache.on_hit do |query|
  Log.debug { "Cache hit: #{query}" }
end

CQL::RequestCache.on_miss do |query|
  Log.debug { "Cache miss: #{query}" }
end
```

## Verify It Works

```crystal
CQL::RequestCache.with_cache do
  start = Time.monotonic

  100.times { User.find(1) }

  elapsed = Time.monotonic - start
  puts "100 finds in #{elapsed.total_milliseconds}ms"
  # Should be very fast (< 5ms) with caching
  # Would be slow (> 100ms) without caching
end
```

## Best Practices

1. **Enable for all requests** - Use middleware for consistent behavior
2. **Clear after writes** - Ensure fresh data after modifications
3. **Don't rely on it for long-term caching** - Use Redis for that
4. **Monitor in development** - Log hits/misses to find N+1 queries

## See Also

- [Enable Query Caching](query-cache.md)
- [Configure Redis Cache](redis.md)
- [Avoid N+1 Queries](../performance/n-plus-one.md)
