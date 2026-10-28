# Framework Integration Examples

`azu_query_cache_demo.cr` shows the per-request query cache middleware for the
[Azu](https://github.com/azutoolkit/azu) toolkit. It does not depend on Azu: requests are `MockContext` objects, and
the Azu-side code is printed as text.

```bash
crystal run examples/framework-integration/azu_query_cache_demo.cr
```

It creates `./azu_demo.db` (SQLite: `users` and `articles`, three rows each), deletes it at the end, and walks
through five steps:

| Step | What runs |
| --- | --- |
| 1. HTTP handler | three mock requests, each wrapped in `CQL::Cache::Middleware::Azu.before_request(context)` and `after_request`, with three queries (two identical) and the hit and miss counts |
| 2. Controller | a mock controller action wrapped in `RequestQueryCacheHelper.start_request` / `end_request` (Azu endpoints have no `before_action`, so the deprecated `Azu::Controller` mixin does not apply) |
| 3. Manual hooks | prints an `HTTP::Handler` of your own that calls `before_request` and `after_request` (nothing runs) |
| 4. Tracking overhead | 50 identical queries with `RequestQueryCacheHelper.enabled = false`, then 50 inside one tracked request; every query runs both times |
| 5. Application pattern | prints a sample Azu app (nothing runs), then the cache statistics for the whole run |

The middleware lives in `src/cache/middleware.cr` and is loaded by `require "cql"`:

| Entry point | Use |
| --- | --- |
| `CQL::Cache::Middleware::HTTP.new` | an `HTTP::Handler` for any `HTTP::Server` or Azu app: starts a request on the tracker for the fiber serving it, with `X-Request-ID` when valid (or a random id), and ends it in an `ensure`; in Azu, `app.start(app.default_handlers + [CQL::Cache::Middleware::HTTP.new] of HTTP::Handler)` |
| `CQL::Cache::Middleware::Azu::Handler.new` | deprecated: a subclass of `HTTP` that adds nothing |
| `CQL::Cache::Middleware::Azu.setup!(app)` | deprecated: calls `app.use(Handler.new)`; `Azu::App` has no `use` (`Azu::HandlerPipeline#use` does) |
| `include CQL::Cache::Middleware::Azu::Controller` | deprecated: registers `before_action`/`after_action`, which Azu endpoints do not have |
| `CQL::Cache::Middleware::Azu.before_request(ctx)` / `.after_request(ctx)` | manual hooks |
| `CQL::Cache::Middleware::Kemal`, `Lucky`, `Amber`, `SpiderGazelle`, `Manual` | hooks for other frameworks and for code without one |

```crystal
require "cql"
require "http/server"

server = HTTP::Server.new([CQL::Cache::Middleware::HTTP.new]) do |context|
  context.response.print User.count # a repeated identical query in this request runs again and counts as a hit
end
```

The tracker stores and serves no rows: it counts repeated statements (an N+1 diagnostic) and makes no request
faster. Each request fiber has its own request id, statements and counters; queries from fibers the request spawns
are not tracked. The middleware tracks only when `cache.on` and `cache.request_cache` are set
(`CQL.configure { |c| c.cache.on = true }`; `request_cache` is `true` by default), and keeps a client `X-Request-ID`
only when it is 1 to 128 of `A-Z a-z 0-9 . _ -`. Azu's own bridge, `require "azu/cql"`
(`Azu::CQL::Middleware`), is the Azu-aware piece: request tagging, telemetry and per-request transactions.

The Azu-side snippets the demo prints are not compiled here: Azu is not a dependency of this repository. They use
`Azu::App` and its handler array.

## See Also

- [Use Per-Request Caching](../../docs/how-to/caching/per-request.md)
- [caching/per_request_query_cache_demo.cr](../caching/README.md): the same cache with the `Manual` and `Kemal` hooks
