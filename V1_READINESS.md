# CQL v1 release review

This work continues PR #65 at `d393ce94595bedf012a58c363128dd46863a5a62`, on its existing
`claude/sharp-galileo-ygjvv3` branch. The PR changes 139 files relative to master, adding roughly 5,433 lines and
removing 577. Its native driver, most advanced SQL constructs, relation macros and telemetry infrastructure
already existed; the PR primarily hardens their failure and transaction behavior. Master through
`8cd475f7ae8f3d0bb1cb0976f310dcb8993c5a1b` is merged in `1356dae`, preserving the newer per-request
fiber cache isolation used by Azu; the source manifest now matches master at 0.0.925.

## Audit and changes

| Area | PR #65 foundation | Gap and response |
| --- | --- | --- |
| Connect/TLS/protocol | One checkout deadline across queue/health/connect, query cancellation, protocol 3.2/3.0 fallback, client certificates, `verify-full` | Pool shutdown could admit a connection completing after close: two failing regressions now covered. COPY format vectors and trailing backend bytes were insufficiently validated: strict parsing and a seeded 2,000-input corpus added. |
| Pool recovery | Dead idle connections are detected; sent statements are never blindly replayed; reset hooks support `DISCARD ALL` | Added opt-in connection circuit breaking, stale-attempt generation guards and one half-open probe. Disabled by default; no SQL replay. Application admission control is still necessary. |
| Streaming/pipelines | Session locking, fiber-owned streams, portal cleanup, bounded fetch batches, bounded request batches | Added four-thread stress with 64 workers sharing four connections, pipeline errors between successful results, early stream termination and lease accounting. Pipeline results remain materialized: use streaming for large results. |
| Telemetry/integration | Query and transaction events, pool wait, context, async bounded queue, tracer, plan analysis and EngineSource | Repeated tracer invocation could duplicate a write. Added a guard and regression. No automatic EXPLAIN ANALYZE is added: it executes SQL and must remain an explicit application policy. |
| Migrations/schema | PostgreSQL advisory locking, lock timeout, duplicate-version rejection, rollback state, safe schema dump, post-commit file sync | Existing migration concurrency and transaction tests are release checks. MySQL/CockroachDB DDL is not transactional; concurrent deploy migrators there require external serialization. Schema-file sync failure after commit is reported and cannot undo committed DDL. |
| DSL/macros/relations | Literal string predicates, typed columns, relationship diagnostics; existing CTE/recursive/window/JSON/geo SQL | Added a reproducible seeded compiler corpus for PR #65 predicates and malformed relation declarations, alongside advanced SQL and compile-time guardrail suites. Four stale pending QueryBuilder cases now execute HAVING and inner/left/right joins against real data, including unmatched rows. This is bounded testing, not an exhaustive proof for arbitrary generated programs. |
| Locking/isolation | Stale-update/delete rejection, rollback hooks, explicit isolation, savepoints and serialization retry helper | Added a live four-dialect contract. SQLite rejects read committed; CockroachDB can strengthen it. Retries must include the whole safe transaction and cannot encompass external side effects. |
| Diagnostics/allocations | Bounded N+1 patterns, opt-in monitor, zero-allocation instrumentation budgets | Added optional first-detection backtraces. Default capture stays off; synchronous monitoring is needed for the caller's stack. Existing allocation tests are gates; whole query builders and row arrays are not claimed allocation-free. |

## Reproduce validation

Use Crystal 1.22.1 and install the declared shards. CI also checks the supported floor, Crystal 1.19.1.
Start disposable databases only; the dialect contract creates and removes `cql_v1_records` in the supplied database.

```sh
crystal spec
DATABASE_URL=postgres://postgres@127.0.0.1/cql_test CRYSTAL_WORKERS=4 \
  crystal spec -Dpreview_mt validation/native_stress_spec.cr spec/postgres/pool_shutdown_spec.cr spec/postgres/circuit_breaker_spec.cr
CQL_ENTERPRISE_DIALECT=sqlite CQL_ENTERPRISE_URL=sqlite3:///tmp/cql-v1.db \
  crystal spec validation/dialect_spec.cr
python3 script/macro-fuzz.py --seed 65 --cases 64
```

For the other dialects, set `CQL_ENTERPRISE_DIALECT` to `postgres`, `mysql` or `cockroach` and
`CQL_ENTERPRISE_URL` to the disposable database URI. Missing servers fail the contract; they do not become pending.
The reusable `.github/workflows/enterprise.yml` defines the services, TLS probes and complete release selections.
The main release job requires it and the crystal-db compatibility workflow.

## Validation record

- Original PR baseline on Crystal 1.22.1 with PostgreSQL 17: **3,454 examples, zero failures/errors, 19 pending**.
  Four were stale QueryBuilder tests; the others needed pooler, server-version, TLS or dialect-specific fixtures.
- Original pool shutdown regressions: **2 failures**; patched pool shutdown/circuit/stress selection: **9 passed**
  under four threads on each of PostgreSQL 14, 17 and 18. The stress case runs 64 workers × 5 pipeline/stream cycles.
- PostgreSQL 14 and 18 expanded selections: **133 passed each**, zero pending, covering real queries, cancellation,
  failover and migration locking as well as protocol checks. Disk-exhaustion failures during the initial matrix
  attempt were resolved by removing unused fixtures and moving build caches; these counts are the completed reruns.
- Seed 65 compiler corpus: **64 valid predicate expansions and 5 negative macro cases passed**.
- Live SQLite, PostgreSQL 17, MySQL 8.0 and CockroachDB 24.3 contracts: **4 passed each**, zero pending.
  MySQL uses the native-password server default and performance_schema transaction instrumentation to verify the
  active isolation level (the session default variable does not report one-transaction overrides).
- PostgreSQL TLS probes: all passed, including trusted CA, wrong hostname, missing CA, required TLS refusal and
  non-retryable TLS errors. The full suite also enabled encrypted-blackhole checks against the TLS fixture.
- Focused N+1, allocation and driver selection: **56 passed**. Tracer/protocol selection: **86 passed**.
- QueryBuilder selection after replacing the four pending cases: **138 passed**, zero pending.
- Final merged-branch full suite with PostgreSQL 17 and TLS: **3,478 examples, zero failures/errors, 12 pending**
  in 2 minutes 41 seconds. The pending cases require optional PgBouncer (10), version-matrix (1) or CockroachDB
  binary-parameter (1) fixtures; the separate live dialect and PostgreSQL matrix selections above passed.
- Ameba: **389 files, zero failures**; Crystal formatting and diff checks passed. Documentation checks covered
  **107 Markdown files** and **90 GitBook pages** without errors; both changed executable documentation programs compiled.

Logs are retained in the prepared environment under `/workspace/setup/logs/cql-*`. The hosted compiler and release
matrix still need to pass on the reviewed commit.

## Release and deployment gates

### Follow-up blocking review and corrections

The review of `184714e` reproduced four runtime/release gaps, in addition to the hosted CI fixture failure
corrected by `cf7bcb8`. The following changes address those findings; the original failure evidence remains under
`/workspace/setup/logs/cql-review-*`, and corrective validation is under `/workspace/setup/logs/cql-fix-*`.

| Finding | Correction and regression coverage |
| --- | --- |
| PostgreSQL fixture opened before its integration guard | The insert fixture is constructed after `require_postgres!` and closed in `ensure`. The corrected compiler-floor run passed 3,478 examples with zero failures/errors and 135 unavailable-fixture cases pending; the live insert selection passed 11/11. Deprecation warnings were unrelated to the CI failure. |
| Per-commit versioning could publish 1.0.1 or 2.0.0 instead of 1.0.0 | Versioning now applies the highest bump once per release. `script/check-release-version` requires exactly 1.0.0 while the manifest is pre-v1, and a strictly increasing stable version thereafter. Both the workflow and `script/release` enforce it before mutations; existing tags are rejected before editing files. Five release-contract tests run the pinned action through branch, normal merge, major-marked merge and major-marked squash cases, reject an unmarked squash, and verify dry-run publication behavior. This CI job gates release. |
| Setup SQL and callbacks bypassed the checkout deadline | New-connection setup shares the remaining checkout budget; warm-up gets a budget per connection. Check-in rollback/reset/setup share a fresh budget. Timed hooks run in a worker fiber; expiry hard-closes the private connection and releases the pool slot, with no late admission or SQL replay. Tests cover stalled SQL, callbacks blocked outside SQL, circuit recovery and reset-hook timeout. Hooks must bound their own external work: arbitrary callback fibers cannot be forcibly terminated and CPU-bound code must yield. |
| A scope in another fiber accessed a returned connection | Transaction scopes and savepoints record their owner. Queries, streams and savepoints reject foreign fibers with `WrongFiber` before yielding a connection. Owner operations still work, and completed scopes remain closed. The ownership test also verifies that the next borrower works normally. |
| A partial schema-file write destroyed the old file | Schema dumps write and fsync a sibling temporary file, then atomically rename it. Existing regular-file permissions are retained and new files use 0600. Partial-write and rename-failure tests require the original destination to remain intact and temporary files to be removed. This is atomic replacement, not a claim of crash durability for directory metadata. |

Corrective validation completed on the patched source:

- Crystal 1.22.1 with PostgreSQL 17 and TLS: **3,485 examples, zero failures/errors, 12 pending** optional fixtures.
- Crystal 1.19.1 without PostgreSQL: **3,485 examples, zero failures/errors, 135 pending** server/optional fixtures.
- Four-thread native stress, pool recovery, setup/reset deadlines and scope ownership: **13 passed**, zero pending.
- Release contract: **5 tests passed**; the pinned action computed **1.0.0** for branch, ordinary merge,
  major-marked merge and major-marked squash. An unmarked squash computed 0.0.926 and was rejected by the gate.
- The original live PostgreSQL setup probe now raises at **50 ms** for its 50 ms budget, leaving **zero leases**.
- The original 1 KiB file-size-limit fault raises a write error while preserving the previous schema unchanged.
- All TLS probes passed; lint inspected **394 files with zero failures**; formatting and documentation checks passed.

These results resolve the four reproduced blockers. Hosted CI still must pass on the final pushed commit.
The earlier crystal-db compatibility check passed for 0.13.1, 0.14.0, 0.15.0 and latest; it is a compilation check,
not a live dialect test.

### MySQL 8.4 and optional PgBouncer follow-up

The optional `require "cql/mysql"` entry point now adds modern authentication and TLS to the tested
`crystal-mysql` 0.16 transport/query implementation. It supports `caching_sha2_password` cold/full and cached
exchanges, a bounded plugin switch, and legacy native-password authentication. TLS verifies the CA and hostname
by default; full-password authentication is refused on plaintext. Handshake packets have length/sequence checks,
a total authentication deadline closes stalled sockets, and authentication errors omit server-provided text.
The integration is opt-in; requiring only `mysql` retains upstream behavior. RSA key retrieval, other plugins,
mutual TLS and newer crystal-mysql versions are outside this validated configuration.

`script/mysql84-fixture` provisions MySQL 8.4 with secure transport required, a disposable CA and the default
plugin. It clears the server auth cache before testing. Release CI runs this fixture plus the legacy MySQL 8.0
contract. The existing TLS job now also provisions four PgBouncer modes and requires all ten pooler tests;
missing services fail instead of silently becoming pending. Readiness probes fail on startup timeout.

Follow-up evidence (Crystal 1.22.1 unless stated otherwise):

- MySQL **8.4.13**: **10 passed**, no pending: cold/warm authentication, verified encryption, wrong password,
  untrusted CA, wrong hostname, plaintext refusal, 16 concurrent clients × 10 bound queries on a three-connection
  pool, optimistic locking, nested savepoints and explicit isolation. Native-password authentication remains
  disabled on this server.
- MySQL **8.0.46** legacy native-password contract through the new integration: **4 passed**, no pending.
- Authentication packet/deadline regression tests: **10 passed** on both Crystal **1.22.1** and **1.19.1**.
- PgBouncer **1.24.1**, PostgreSQL **17**: **10 passed**, no pending, both normally and with four worker threads.
  Modes: session pooling; transaction pooling with 100 prepared statements; transaction pooling with prepared
  statements disabled and either one or three backend connections. These are SCRAM loopback fixtures, not a
  validation of a deployed TLS-terminating proxy. CI uses the Ubuntu 24.04 PgBouncer package.
- Full suite with PostgreSQL 17, TLS and all four PgBouncer fixtures: **3,494 examples, zero failures/errors,
  2 pending** (optional version-matrix and CockroachDB binary-parameter fixtures). This run included the initial
  nine MySQL unit cases; the final ten-case authentication suite above also covers stalled TLS handshakes.
- PostgreSQL 17 version-matrix contract: **7 passed**, no pending, before restarting the four poolers.
- PostgreSQL direct-driver TLS probes passed. CI lint: **398 files, zero failures**; formatting passed.
  Documentation checks passed for **107 Markdown files**, **90 GitBook pages**, and **4 compiled programs**.

The PgBouncer results do not extend to untested RDS Proxy, Supavisor or other pgpool-II configurations. Existing
pgcat and pgpool-II streaming limitations remain documented. Hosted CI still must pass on this follow-up commit.

### Remaining publication and application checks

- Review the final PR commit and pass hosted CI, including every new required job. GitHub API access is currently
  denied in this environment; native Git access works. The supplied hosted log confirms the fixture failure above;
  no subsequent hosted pass, approval or release is asserted here.
- The existing release workflow owns `shard.yml`, changelog, version commit, tag and GitHub release. Normal merges
  retain the branch's major-bump commit; squash merges must include `(MAJOR)` in the squash message. The pinned
  version action and publication gate require the initial stable release to be exactly `1.0.0`. A squash without
  the marker is rejected. This replaces the earlier unsafe per-commit merge guidance. Do not bypass review or CI.
- Validate the actual application's TLS/proxy topology, database privileges, migration serialization, failover,
  backups/PITR, workload/SLO and telemetry export. Single-node transactional tests cannot establish distributed
  durability, cross-region recovery or a production capacity limit.
- Use the documented optional MySQL integration for default MySQL 8.4 authentication and verified TLS; other
  plugins and TLS topologies need their own validation. PostgreSQL geo operators require PostGIS; SQL generation
  tests do not prove that extension is deployed.
