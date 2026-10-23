# Use Per-Request Caching

Track the queries executed during a single HTTP request, and reset that state when the request ends.

## Prerequisites

- CQL installed and configured
- Web application with a request lifecycle

## The Problem

Within a single request, the same query may run several times:

```crystal
# Header partial
current_user = User.find(session[:user_id])  # Query 1

# Sidebar partial
current_user = User.find(session[:user_id])  # Query 2 (duplicate!)
```

`CQL::Cache::RequestQueryCache` keys every SQL statement by its text and bound parameters. Every `all`, `get` and `each` call on a query goes through `RequestQueryCacheHelper.with_cache(sql, params)`, so a repeated statement within one request is counted as a hit.

## What It Does (and Does Not Do)

`with_cache(sql, params) { ... }` records that the statement was seen and then **always runs the block**. It does not store or replay rows, so it will not remove the duplicate query by itself. Use it to find duplicates: the `hits` counter in `stats` is the number of repeated statements. To avoid the duplicate database round trip, memoize the result in your own code or use the value cache from [Enable Query Caching](query-cache.md).

## Enable the Request Cache

Pick the integration for your framework. Each one calls `start_request` when the request begins and `end_request` when it finishes, using the `X-Request-ID` header as the request ID (or a random one).

### Generic `HTTP::Server`

```crystal
server = HTTP::Server.new([
  CQL::Cache::Middleware::HTTP.new,
  # ... other handlers
  MyApp.new,
])
```

### Azu

```crystal
Azu::Server.new([
  CQL::Cache::Middleware::Azu::Handler.new,
  # ... other handlers
])
```

Or call the hooks yourself: `CQL::Cache::Middleware::Azu.before_request(ctx)` and `.after_request(ctx)`.

### Kemal

```crystal
before_all do |env|
  CQL::Cache::Middleware::Kemal.before_request(env)
end

after_all do |env|
  CQL::Cache::Middleware::Kemal.after_request(env)
end
```

### Lucky

```crystal
abstract class ApplicationAction < Lucky::Action
  include CQL::Cache::Middleware::Lucky
end
```

### Amber

```crystal
class QueryCachePipe < Amber::Pipe::Base
  include CQL::Cache::Middleware::Amber
end

# config/routes.cr
pipeline :web, [QueryCachePipe]
```

`CQL::Cache::Middleware::SpiderGazelle` also exists and is included in a controller the same way.

### Any other framework

```crystal
CQL::Cache::Middleware::Manual.with_request do
  # handle the request
end
```

`Manual.start_request` and `Manual.end_request` are available if you cannot wrap the request in a block.

These adapters are thin wrappers around the helper in the next section. The Lucky, Amber, SpiderGazelle and Azu controller adapters rely on macros and callbacks of those frameworks and are not exercised by CQL's own specs.

## Calling the Helper Directly

```crystal
CQL::Cache::RequestQueryCacheHelper.start_request("req-123")  # clears state, sets request ID
# ... run queries ...
CQL::Cache::RequestQueryCacheHelper.end_request               # clears state
```

`start_request` without an argument generates a random ID.

If you use `CQL.configure`, `CQL.with_request_cache { ... }` does the same thing, but only when `c.cache.on = true` and `c.cache.request_cache` is true (the default).

```crystal
CQL.configure do |c|
  c.cache.on = true
end

CQL.with_request_cache("req-123") do
  # handle the request
end
```

## Manual Cache Control

### Clear the Request Cache

```crystal
CQL::Cache::RequestQueryCacheHelper.clear
```

Clears the tracked statements and keeps the request ID.

### Disable and Re-enable

```crystal
CQL::Cache::RequestQueryCacheHelper.enabled = false
CQL::Cache::RequestQueryCacheHelper.enabled?  # => false
```

While disabled, `with_cache` just runs the block.

### Track a Specific Statement

```crystal
CQL::Cache::RequestQueryCacheHelper.with_cache("SELECT 1", [] of DB::Any) do
  # your code
end
```

## Debugging

```crystal
stats = CQL::Cache::RequestQueryCacheHelper.stats
puts stats["hits"]              # statements seen more than once
puts stats["misses"]            # distinct statements
puts stats["hit_rate_percent"]
puts stats["size"]              # distinct statements tracked now
puts stats["request_id"]        # "none" outside a request
```

Other keys: `enabled`, `max_size`, `sets`, `clears`. A high `hits` count on an endpoint points at an N+1 or at duplicated lookups.

## Memory Bound

`RequestQueryCache.new(max_size : Int32 = 1000)` caps the tracked statements. When the cap is reached the entry with the fewest accesses (then the oldest) is evicted. The shared instance used by the helper is `RequestQueryCache.instance`, created with the default of 1000.

## Best Practices

1. **Enable for all requests** - Use middleware so every request starts clean.
2. **Always pair start with end** - The provided handlers use `ensure`; do the same in custom code.
3. **Use the stats to find duplicates** - Then fix them at the source.
4. **Don't rely on it for long-term caching** - See [Configure Redis Cache](redis.md).

## Troubleshooting

**`hits` and `misses` stay at zero:**
- Check `RequestQueryCacheHelper.enabled?`.
- With `CQL.with_request_cache`, check that `c.cache.on` is true.

**Counters keep growing across requests:**
- `start_request` and `end_request` clear the tracked statements but not the `hits`/`misses` counters. They are totals for the process.

**Kemal `setup!` does nothing:**
- `CQL::Cache::Middleware::Kemal.setup!` is an empty stub. Register the `before_all`/`after_all` hooks shown above.

## See Also

- [Enable Query Caching](query-cache.md)
- [Configure Redis Cache](redis.md)
- [Avoid N+1 Queries](../performance/n-plus-one.md)
