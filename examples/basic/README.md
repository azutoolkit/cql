# Basic CQL Examples

Three small programs about CQL's cache layer. None of them touches a database.

```bash
crystal run examples/basic/simple_cache_demo.cr
crystal run examples/basic/simple_caching_demo.cr
redis-server --daemonize yes && crystal run examples/basic/simple_redis_demo.cr
```

| File | Shows | Needs |
| --- | --- | --- |
| `simple_cache_demo.cr` | `CQL::Cache::MemoryCache` set/get with a TTL (it waits 3 seconds), `tag_cache` and `invalidate_tags`, `FragmentCache#cache_fragment` timing a miss and a hit, `VersionInvalidation`, `TransactionAwareInvalidation`, `CacheKeyBuilder`, `stats`, and LRU eviction. Output is formatted with [`Beautify`](../utilities/README.md) | nothing |
| `simple_caching_demo.cr` | the same steps with plain `puts` output, plus custom cache keys | nothing |
| `simple_redis_demo.cr` | `CQL::Cache::Cache.configure_from_env` with `CQL_CACHE_TYPE=redis` (it sets the variables itself), `GlobalCache` get/set/`cache`/`exists?`/`delete`/`stats`, a second store from `CacheStore.create("redis", ...)`, `set_multi` and `get_multi` | Redis on `localhost:6379` (databases 1 and 2) |

> [!WARNING]
> Without a Redis server, `simple_redis_demo.cr` still exits 0: the cache calls fail quietly and print empty values.
> Check that `redis-cli ping` answers `PONG` first.

The Redis example deletes only keys under its own prefix when it cleans up.

## See Also

- [caching/](../caching/README.md): the same cache on models, per request, and configured through `CQL.configure`
- [Enable Query Caching](../../docs/how-to/caching/query-cache.md)
- [Configure Redis Cache](../../docs/how-to/caching/redis.md)
