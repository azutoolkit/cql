# Audit P4/P6 (summary of agent report)
S4.1 partial: Telemetry.subscribe/Tracer/subscribe_transactions/alert_on_slow exist; QueryEvent has duration/operation/pool_wait/error/rows_affected/context; pool exhaustion visible both paths. Missing: table on QueryEvent, select row count, pool waiters/timeout counters, connection open/close/discard hooks; pool_wait includes connect time; tx checkout wait not separate.
S4.2 partial: N+1 on only with CRYSTAL_ENV=development; production preset enables it; no call site; disabled cost ~0. Global window -> false positives across fibers/requests (confirmed).
S4.3 partial: no Log metadata anywhere; lifecycle barely logged.
S6.1 mostly exists (blackhole, FakePG, timeouts, pool concurrency) for native driver.
S6.2 missing fuzz; 44 adversarial inputs found nothing injectable.
S6.3 partial: PgBouncer documented; missing production checklist, AR/Eloquent migration guide, pooler cross-link in connection-pooling.md.
Confirmed gaps:
1 PII: Insert#commit/#get log raw driver message at ERROR (src/insert.cr:90,:144) -> delete rescue/log.
2 PII: db log source logs bound args at Debug; native Statement inherits emit_log (statement.cr:8) -> override.
3 Restart/failover: engine fails once per pooled conn after pg_terminate_backend (health ping only after 30s idle, pool.cr:22).
4 N+1 false positives: global window ignores context; no caller.
5 Log source env-named (configure.cr:354) -> Log.for("cql").
6 No structured log fields.
7 engine.transaction no tx events; copy_out no query event; no table on QueryEvent; no waiters/timeouts in engine pool stats.
8 LIKE wildcard: no escape helper; tutorial does like("%#{term}%").
9 Raw fragment tokenizer miscounts E'..\'..', nested /* */, -- with \r (fail closed).
10 Docs pages.
Suspected: MySQL insert log; no -Dpreview_mt CI; production preset keeps 1000 slow QueryData with params (query_profiler.cr:61); schema_dump unquoted names in PRAGMA/DESCRIBE (schema_dump.cr:117,137,255); Schema#transaction logs DB::Rollback at WARN (schema.cr:382).
