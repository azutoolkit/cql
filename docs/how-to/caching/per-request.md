---
description: "Count the statements each HTTP request runs so that repeated queries within one request show up."
---

# Use Per-Request Caching

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

Each integration starts a request with the `X-Request-ID` header (or a random id) and ends it when the response is done. A header value is kept only when it is 1 to 128 of `A-Z a-z 0-9 . _ -`; any other value (empty, too long, control characters, spaces, non-ASCII) is replaced with a random 16-character hex id.

The integrations go through `CQL.with_request_cache` (`HTTP`, `Amber`, `Manual.with_request`) or `CQL.start_request_cache` and `CQL.end_request_cache` (the before/after hooks), so they track only when both switches are on:

```crystal
CQL.configure { |c| c.cache.on = true }  # c.cache.request_cache is true by default; cache.on is true by default only when CRYSTAL_ENV is development or unset
```

The tracker is a repeated-query (N+1) diagnostic, not a result cache: it stores and serves no rows, so it makes no request faster. A request belongs to the fiber that started it: each request has its own id, statements and counters, so concurrent requests do not share them. Queries run by a fiber the request spawns are not tracked.

{% tabs %}
{% tab title="HTTP::Server" %}
```crystal
# A handler that ends the request in an ensure
server = HTTP::Server.new([CQL::Cache::Middleware::HTTP.new, MyApp.new])
```
{% endtab %}

{% tab title="Kemal" %}
```crystal
# CQL::Cache::Middleware::Kemal.setup! is an empty stub: register the hooks
before_all { |env| CQL::Cache::Middleware::Kemal.before_request(env) }
after_all { |env| CQL::Cache::Middleware::Kemal.after_request(env) }
```
{% endtab %}

{% tab title="Azu" %}
```crystal
# An Azu::App takes its handlers as an array; put the handler after Azu::Handler::RequestId, whose id it reuses
app = Azu::App.default
app.start(app.default_handlers + [CQL::Cache::Middleware::HTTP.new] of HTTP::Handler)
```

`Azu::App` has no `use`, so the deprecated `CQL::Cache::Middleware::Azu.setup!(app)` does not compile with it;
`Azu::HandlerPipeline#use` still accepts the handler (`pipeline.use(CQL::Cache::Middleware::HTTP.new)`).
`CQL::Cache::Middleware::Azu::Handler` is deprecated: a subclass of `CQL::Cache::Middleware::HTTP` that adds nothing;
`CQL::Cache::Middleware::Azu::Controller` is deprecated: it registers `before_action`/`after_action`, which Azu
endpoints do not have. The Azu-aware piece is Azu's own bridge, `require "azu/cql"`: its `Azu::CQL::Middleware`
tags each statement with the request for Azu's dashboard and can run the request in a transaction.
{% endtab %}

{% tab title="Lucky" %}
```crystal
abstract class ApplicationAction < Lucky::Action
  include CQL::Cache::Middleware::Lucky
end
```
{% endtab %}

{% tab title="Amber" %}
```crystal
# Then add QueryCachePipe to a pipeline in config/routes.cr
class QueryCachePipe < Amber::Pipe::Base
  include CQL::Cache::Middleware::Amber
end
```
{% endtab %}

{% tab title="SpiderGazelle" %}
```crystal
# In a controller
include CQL::Cache::Middleware::SpiderGazelle
```
{% endtab %}

{% tab title="Other" %}
```crystal
CQL::Cache::Middleware::Manual.with_request { handle(request) }  # or Manual.start_request / Manual.end_request
```
{% endtab %}
{% endtabs %}

The Lucky, Amber and SpiderGazelle modules rely on those frameworks' macros and are not exercised by CQL's specs.

## Call the Helper Directly

```crystal
CQL::Cache::RequestQueryCacheHelper.start_request   # a random 32-character id; tracks whatever cache.on says
CQL::Cache::RequestQueryCacheHelper.end_request

CQL.configure { |c| c.cache.on = true }          # c.cache.request_cache is true by default
CQL.with_request_cache("req-123") { handle(request) }  # starts nothing unless both are on; ends in an ensure only what it started

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

Inside a request, the counts are that request's. Outside a request, `hits`, `misses`, `sets` and `clears` are totals for the process, over every request so far. The stats always describe the fiber that reads them, and so does `CQL.cache_summary` (`CQL.config.cache.performance_summary`): read from a dashboard or a timer fiber, outside any request, they show the process totals and `enabled` is `"false"` (unless `enabled = true`). A high `hits` count on an endpoint points at an N+1 or a duplicated lookup; see [Avoid N+1 Queries](../performance/n-plus-one.md).

## Control Tracking

```crystal
CQL::Cache::RequestQueryCacheHelper.enabled = true   # track outside requests too, in one process-wide tracker
CQL::Cache::RequestQueryCacheHelper.enabled = false  # stop, even for requests still active
CQL::Cache::RequestQueryCacheHelper.enabled?         # true on a fiber with an active request, or after enabled = true
CQL::Cache::RequestQueryCacheHelper.clear            # drop the current request's tracked statements, keep its id
```

{% hint style="warning" %}
`end_request` must run on the fiber that called `start_request`. One skipped on an error path keeps tracking on for that fiber, which in `HTTP::Server` serves every request of a keep-alive connection, so end requests in an `ensure` (as `Manual.with_request`, `CQL.with_request_cache` and `Middleware::HTTP` do). The state of a fiber that has died is dropped by a later `start_request` once at least 64 request fibers (or twice as many as are left) have state.
{% endhint %}

## See Also

- [Enable Query Caching](query-cache.md)
- [Configure Redis Cache](redis.md)
- [Avoid N+1 Queries](../performance/n-plus-one.md)
- [Monitor Performance](../observability/monitoring.md)
