# Audit P2/P3 (summary of agent report)
S2.1 exists (pool/session locks, statement cache per session, fiber_mutex, COW registries). MT stress 64 fibers/8 threads: 0 wrong, pool clean.
S2.2a partial: NegotiateProtocolVersion + 3.2->3.0 fallback exist; engine never retries connect (engine_source.cr:27, pool.cr:165).
S2.2b exists: early stop/raise/kill mid-stream/pipeline all clean; buffer bounded by fetch size; pipeline writes chunked.
S2.2c partial: cancel on own socket; TLS timeout ok; verify-full hostname ok. Missing: client certs (sslcert/sslkey rejected config.cr:43), timeout on normal query path, verify-ca/allow rejected.
S2.3 mostly done; zero-alloc wrong goal. find by id 1440B/64us.
S3.1 partial: savepoints ok; isolation only on AsyncEngine.transaction (async_engine.cr:75) not Schema#transaction (schema.cr:363,393); no retry helper; typed SerializationFailure/DeadlockDetected only in native driver (errors.cr:181).
S3.2 partial: dead conns discarded; no liveness check on lend; no breaker/backoff.
S3.3 partial: MySQL concern wrong (version always changes).
Confirmed gaps:
1 Stale delete! with optimistic locking silently deletes changed row (deleteable.cr:125). Fix: AND version = ? + raise on 0 rows.
2 No timeout on normal query path (statement.cr:26 session.query no timeout); blackhole -> blocked >15s, pool slot held. Fix: query_timeout URL key in Config -> Statement#run timeout:.
3 After pg_terminate_backend each idle pooled conn fails one caller with ServerError 57P01 (not ConnectionLost); ping only after 30s (pool.cr:22,199). Fix: non-blocking peek on lend + map FATAL 57P0x/08xxx to ConnectionLost.
4 Session state (set_config, SET ROLE) leaks to next borrower by default; reset: only programmatic. Fix: pool_reset URL key into Pool::Options (pool.cr:25).
5 checkout_timeout does not cover connect (6s with checkout_timeout=1); message lacks address. Fix: cap connect by remaining checkout time.
6 OptimisticLockError has no context (update.cr:94).
7 Schema#transaction has no isolation:/read_only:; no 40001/40P01 retry helper.
8 Optimistic lock added at commit by mutating builder (update.cr:319-370); double commit duplicates SET version.
9 TLS no client certs.
10 MT cache stats lost updates (cache.cr:75,123).
Suspected: lazy singletons double-init under MT; mid-pipeline kill ConnectionLost empty message; sslmode=prefer no plaintext retry after failed handshake (transport.cr:86-87); lock_version Int32 only (update.cr:65); Schema#exec multi-statement on EngineSource raises 42601.
