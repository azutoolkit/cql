# Use Per-Request Caching

Count the statements each HTTP request runs so that repeated queries within one request show up.

## See What It Tracks

```crystal
CQL::Cache::RequestQueryCacheHelper.start_request("req-123")  # clears tracked statements and starts tracking

current_user = User.find(session_user_id)  # header partial
current_user = User.find(session_user_id)  # sidebar partial: runs again, counted as a hit

CQL::Cache::RequestQueryCacheHelper.stats["hits"]  # => 1
CQL::Cache::RequestQueryCacheHelper.end_request    # clears tracked statements; tracking stops with the last request
```

Every select a query runs (`all`, `get`, `each`, `find` and the like) passes through `RequestQueryCacheHelper.with_cache(sql, params)`. It keys the statement by its SQL and a hash of its bound values, keeps no values, and **always runs the block**: no rows are stored or replayed. Use the counts to find duplicates, then memoize the result or cache it with [Enable Query Caching](query-cache.md). Outside a request, tracking is off and `with_cache` just runs the block.

## Hook It Into Your Framework

Each integration starts a request with the `X-Request-ID` header (or a random id) and ends it when the response is done.

```crystal
# HTTP::Server: a handler that ends the request in an ensure
server = HTTP::Server.new([CQL::Cache::Middleware::HTTP.new, MyApp.new])

# Azu: add CQL::Cache::Middleware::Azu::Handler.new to the handler chain,
# or call CQL::Cache::Middleware::Azu.before_request(context) and .after_request(context)

# Kemal (CQL::Cache::Middleware::Kemal.setup! is an empty stub: register the hooks)
before_all { |env| CQL::Cache::Middleware::Kemal.before_request(env) }
after_all { |env| CQL::Cache::Middleware::Kemal.after_request(env) }

# Lucky
abstract class ApplicationAction < Lucky::Action
  include CQL::Cache::Middleware::Lucky
end

# Amber: then add QueryCachePipe to a pipeline in config/routes.cr
class QueryCachePipe < Amber::Pipe::Base
  include CQL::Cache::Middleware::Amber
end
# SpiderGazelle and Azu controllers: include CQL::Cache::Middleware::SpiderGazelle / ::Azu::Controller

# Anything else
CQL::Cache::Middleware::Manual.with_request { handle(request) }  # or Manual.start_request / Manual.end_request
```

The Lucky, Amber, SpiderGazelle and Azu controller modules rely on those frameworks' macros and are not exercised by CQL's specs.

## Call the Helper Directly

```crystal
CQL::Cache::RequestQueryCacheHelper.start_request   # a random 32-character id
CQL::Cache::RequestQueryCacheHelper.end_request

CQL.configure { |c| c.cache.on = true }          # c.cache.request_cache is true by default
CQL.with_request_cache("req-123") { handle(request) }  # does nothing unless both are on; ends in an ensure

CQL::Cache::RequestQueryCacheHelper.with_cache("SELECT 1", [] of DB::Any) { legacy_lookup }  # track your own call
```

## Read the Counts

```crystal
stats = CQL::Cache::RequestQueryCacheHelper.stats
stats["hits"]              # statements seen again: the duplicates
stats["misses"]            # distinct statements
stats["hit_rate_percent"]  # hits / (hits + misses) * 100
stats["size"]              # distinct statements tracked now, at most max_size (1000; the oldest goes first)
stats["request_id"]        # "none" outside a request
stats["enabled"]           # "true" or "false"; also "max_size", "sets" and "clears"
```

`hits` and `misses` are totals for the process: starting or ending a request clears the tracked statements, not the counters. A high `hits` count on an endpoint points at an N+1 or a duplicated lookup; see [Avoid N+1 Queries](../performance/n-plus-one.md).

## Control Tracking

```crystal
CQL::Cache::RequestQueryCacheHelper.enabled = true   # track outside requests too
CQL::Cache::RequestQueryCacheHelper.enabled = false  # stop, even for requests still active
CQL::Cache::RequestQueryCacheHelper.enabled?         # true while a request is active or after enabled = true
CQL::Cache::RequestQueryCacheHelper.clear            # drop tracked statements, keep the request id
```

{% hint style="warning" %}
The tracker is one per process: overlapping requests share its statements and counters, and tracking stays on while any request is active. An `end_request` skipped on an error path keeps it on for good, so end requests in an `ensure` (as `Manual.with_request` and `CQL.with_request_cache` do).
{% endhint %}

## See Also

- [Enable Query Caching](query-cache.md)
- [Configure Redis Cache](redis.md)
- [Avoid N+1 Queries](../performance/n-plus-one.md)
- [Monitor Performance](../performance/monitoring.md)
