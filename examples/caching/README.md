# Advanced Caching Examples

CQL's cache layer on models, per request, and through `CQL.configure`. Run from the repository root.

```bash
crystal run examples/caching/cache_configuration_example.cr
crystal run examples/caching/advanced_caching_example.cr -- run    # prints nothing without `run`
crystal run examples/caching/per_request_query_cache_demo.cr
crystal run examples/caching/active_record_cache_demo.cr
crystal run examples/caching/activerecord_cache_demo.cr
crystal run examples/caching/redis_cache_demo.cr                   # needs Redis on localhost:6379
```

| File | Shows | Database |
| --- | --- | --- |
| `cache_configuration_example.cr` | `config.cache.*` settings in `CQL.configure` per environment (`on`, `ttl`, `memory`, `memory_size`, `key_prefix`, request and fragment caches), the `memory_size must be positive` validation error, `CQL.cache_on` | none (nothing connects) |
| `advanced_caching_example.cr` | `FragmentCache` over `MemoryCache` with `TimestampInvalidation`, `VersionInvalidation` and `TransactionAwareInvalidation`, tag invalidation, query cache keys from `CacheKeyBuilder`, `stats`, LRU eviction | SQLite, `examples/cache_example.db` (tables are created, never queried) |
| `per_request_query_cache_demo.cr` | the per-request query cache: `Middleware::Manual.start_request`/`end_request` and `with_request`, repeated SQL served from the cache, joins, Kemal hooks on mock requests, a with/without-cache timing | SQLite, `./cache_demo.db` (deleted at the end) |
| `active_record_cache_demo.cr` | model-style caching (find, cache keys and tags, invalidation on update) on `MockUser`, a plain class kept in a `Hash` | none |
| `activerecord_cache_demo.cr` | `CQL::ActiveRecord::Model` structs with a custom `cache_key`, cached as JSON in `MemoryCache` with tags, fragment and version invalidation, `stats` | none (the models are never saved) |
| `redis_cache_demo.cr` | `CacheStore.configure_from_env` (`CQL_CACHE_TYPE`, `CQL_REDIS_URL`, `CQL_CACHE_PREFIX`, `CQL_CACHE_TTL`), `CacheStoreConfig`, `CacheStore.create`, `set_multi`/`get_multi`, tags, `GlobalCache`, memory against Redis timing, `ping` | Redis databases 1 to 5 |
| `with_cache_demo.cr` | `CQL::Cache::Cache.with_cache` on several value types | does not compile, see below |

> [!WARNING]
> `with_cache_demo.cr` fails to compile: `CQL::Cache::Cache.with_cache` (`src/cache/cache.cr:71`) declares
> `as_kind : Class?`, and Crystal answers "can't use Class in unions yet".

`activerecord_cache_demo.cr` ends by printing that `CQL::ActiveRecord::Model` includes
`CQL::Cache::ActiveRecordCaching`; no such module exists in `src/`.

Without a Redis server, `redis_cache_demo.cr` does not fail: each Redis call fails quietly, and the 50-operation
timing step takes minutes. Check `redis-cli ping` first.

## See Also

- [basic/](../basic/README.md): the memory cache and strategies on their own
- [framework-integration/](../framework-integration/README.md): the Azu middleware
- [Enable Query Caching](../../docs/how-to/caching/query-cache.md)
- [Use Per-Request Caching](../../docs/how-to/caching/per-request.md)
- [Configure Redis Cache](../../docs/how-to/caching/redis.md)
