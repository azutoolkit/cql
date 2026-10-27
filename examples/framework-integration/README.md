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
| 2. Controller | a mock controller action wrapped in `RequestQueryCacheHelper.start_request` / `end_request`, starting and ending the request itself, the way a controller-style class of another framework would with `include CQL::Cache::Middleware::Azu::Controller` |
| 3. Manual hooks | prints where `before_request` and `after_request` go in an Azu app (nothing runs) |
| 4. Performance | 50 identical queries with `RequestQueryCacheHelper.enabled = false`, then 50 inside one cached request |
| 5. Application pattern | prints a sample Azu app (nothing runs), then the cache statistics for the whole run |

The middleware lives in `src/cache/middleware.cr` and is loaded by `require "cql"`:

| Entry point | Use |
| --- | --- |
| `CQL::Cache::Middleware::Azu::Handler.new` | an `HTTP::Handler`; one cache per request, keyed by `X-Request-ID` or a random id |
| `CQL::Cache::Middleware::Azu.setup!(handlers)` | appends a `Handler` to an `Array(HTTP::Handler)` (once) and returns it: `app.start(CQL::Cache::Middleware::Azu.setup!(app.default_handlers))`; with an `Azu::HandlerPipeline` it calls `pipeline.use(Handler.new)` |
| `include CQL::Cache::Middleware::Azu::Controller` | registers `before_action :start_azu_query_cache` and `after_action :end_azu_query_cache`; Azu endpoints have no such macros |
| `CQL::Cache::Middleware::Azu.before_request(ctx)` / `.after_request(ctx)` | manual hooks |
| `CQL::Cache::Middleware::HTTP.new` | the same handler for any `HTTP::Server` |
| `CQL::Cache::Middleware::Kemal`, `Lucky`, `Amber`, `SpiderGazelle`, `Manual` | hooks for other frameworks and for code without one |

```crystal
require "cql"
require "http/server"

server = HTTP::Server.new([CQL::Cache::Middleware::HTTP.new]) do |context|
  context.response.print User.count # a repeated identical query in this request is served from the cache
end
```

The Azu-side snippets the demo prints are not compiled here: Azu is not a dependency of this repository. They use
`Azu::App` and its handler array.

## See Also

- [Use Per-Request Caching](../../docs/how-to/caching/per-request.md)
- [caching/per_request_query_cache_demo.cr](../caching/README.md): the same cache with the `Manual` and `Kemal` hooks
