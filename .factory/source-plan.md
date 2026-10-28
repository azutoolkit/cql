# Source plan (verbatim intent, user-supplied, ids added)

Goal: audit, harden, optimize and elevate CQL to a production-ready v1.0.0 enterprise-grade release.

## S1 Pillar 1: Compile-Time Safety & Macro Robustness
- S1.1 Macro error messaging: compile-time macro errors (schema mismatches, invalid association bindings, FK/PK mismatches) give clear, actionable messages with file/line and remediation.
- S1.2 Strict schema validation: harden CQL::Schema boot-time checks; optional strict mode catches drift between model getter types and DB column types at startup.
- S1.3 Complex query DSL completeness: validate macro expansion/type checking for
  - S1.3a CTEs (incl. recursive), window functions, set operations (UNION/INTERSECT/EXCEPT)
  - S1.3b upsert clauses, JSON/JSONB operators, spatial/geo predicates, safe bound raw SQL fragments
  - S1.3c polymorphic associations and complex has_many :through

## S2 Pillar 2: High-Performance Concurrency & Native Engine Hardening
- S2.1 Fiber & concurrency safety: audit shared state, pools, checkouts under heavy concurrency.
- S2.2 CQL::Postgres::AsyncEngine hardening
  - S2.2a protocol v3.2/v3.0 negotiation, fallback, connection retry/backoff
  - S2.2b streaming (engine.stream) and pipelining (engine.pipeline) vs slow consumers, backpressure, dropped sockets
  - S2.2c TLS (sslmode), out-of-band cancel requests, timeout enforcement without connection leaks
- S2.3 Zero-allocation optimization in hot paths (query building, serialization, row mapping).

## S3 Pillar 3: Enterprise Resilience & Transaction Integrity
- S3.1 Nested transactions via savepoints, deadlock detection/retry, isolation levels (:serializable, :repeatable_read, :read_committed).
- S3.2 Pool recovery on DB restart / transient network partitions (circuit breaking).
- S3.3 Optimistic locking (lock_version) across dialects; descriptive concurrency exceptions.

## S4 Pillar 4: Observability, Diagnostics & Telemetry
- S4.1 Pluggable metrics hooks (Prometheus, StatsD): query latency histograms, active connections, checkout wait, pool exhaustion.
- S4.2 N+1 detection with stack traces in dev/test, no production penalty.
- S4.3 Structured logging: query logs, slow-query warnings (configurable threshold), connection lifecycle events as JSON.

## S5 Pillar 5: Cross-Database Dialect Parity & Edge Cases
- S5.1 Dialect parity across PostgreSQL, MySQL, SQLite, CockroachDB.
- S5.2 Migration engine: forward/rollback, schema dumps, idempotent execution, zero-downtime patterns (expand-and-contract).

## S6 Pillar 6: Testing, Fuzzing & Documentation
- S6.1 Edge specs: network partitions, slow queries, malformed protocol responses, concurrency stress.
- S6.2 Fuzz tests for query DSL and raw SQL sanitizer.
- S6.3 Runbooks: pool tuning (PgBouncer, max conns, timeouts), production deployment checklist (TLS, env vars), migration guides from ActiveRecord/Eloquent.

## Execution plan
- E1 Gap analysis; E2 implementation plan per pillar; E3 code + tests.
